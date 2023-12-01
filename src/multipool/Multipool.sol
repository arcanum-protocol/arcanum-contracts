// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only your heart

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MpAsset, MpContext} from "../lib/MpContext.sol";
import {FeedInfo, FeedType} from "../lib/Price.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";
import {FixedPoint96} from "../lib/FixedPoint96.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Multipool is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;

    function initialize(string memory mpName, string memory mpSymbol, uint sharePrice)
        public
        initializer
    {
        __ERC20_init(mpName, mpSymbol);
        __ERC20Permit_init(mpName);
        __ReentrancyGuard_init();
        __Ownable_init();
        initialSharePrice = sharePrice;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //------------- Errors ------------

    error InvalidForcePushAuthoritySignature();
    error InvalidTargetShareSetterAuthority();
    error ForcePushedPriceExpired(uint blockTimestamp, uint priceTimestestamp);
    error ZeroAmountSupplied();
    error InsuficcientBalance();
    error SleepageExceeded();
    error AssetsNotSortedOrNotUnique();
    error IsPaused();

    //------------- Events ------------

    event AssetChange(address indexed token, uint quantity, uint128 collectedCashbacks);
    event FeesChange(uint64 deviationParam, uint64 deviationLimit, uint64 depegBaseFee, uint64 baseFee);
    event TargetShareChange(address indexed token, uint share, uint totalTargetShares);
    event FeedChange(address indexed token, FeedInfo feed);
    event SharePriceTTLChange(uint sharePriceTTL);
    event PriceSetterToggled(address indexed account, bool isSetter);
    event TargetShareSetterToggled(address indexed account, bool isSetter);
    event PauseChange(bool isPaused);
    event CollectedFeesChange(uint fees);

    //------------- Variables ------------

    mapping(address => MpAsset) internal assets;
    mapping(address => FeedInfo) internal prices;

    uint64 internal deviationParam;
    uint64 internal deviationLimit;
    uint64 internal depegBaseFee;
    uint64 internal baseFee;

    uint public totalTargetShares;
    uint public totalCollectedCashbacks;
    uint public collectedFees;

    uint public initialSharePrice;
    uint public sharePriceTTL;

    mapping(address => bool) public isPriceSetter;
    mapping(address => bool) public isTargetShareSetter;

    bool public isPaused;

    // ---------------- Methods ------------------

    modifier notPaused() {
        if (isPaused) revert IsPaused();
        _;
    }

    function getPriceFeed(address asset) public view returns (FeedInfo memory f) {
        f = prices[asset];
    }

    function getPrice(address asset) public view returns (uint price) {
        price = prices[asset].getPrice();
    }

    function getFees()
        public
        view
        returns (uint64 _deviationParam, uint64 _deviationLimit, uint64 _depegBaseFee, uint64 _baseFee)
    {
        _deviationParam = deviationParam;
        _deviationLimit = deviationLimit;
        _depegBaseFee = depegBaseFee;
        _baseFee = baseFee;
    }

    function getAsset(address assetAddress) public view returns (MpAsset memory asset) {
        asset = assets[assetAddress];
    }

    function getContext(FPSharePriceArg calldata fpSharePrice) internal view returns (MpContext memory ctx) {
        uint totSup = totalSupply();
        uint price;
        if (fpSharePrice.thisAddress == address(this)) {
            bytes memory data = abi.encodePacked(address(fpSharePrice.thisAddress), uint(fpSharePrice.timestamp), uint(fpSharePrice.value));
            if (!isPriceSetter[keccak256(data).toEthSignedMessageHash().recover(fpSharePrice.signature)]) {
                revert InvalidForcePushAuthoritySignature();
            }
            if (fpSharePrice.timestamp - block.timestamp >= sharePriceTTL) {
                revert ForcePushedPriceExpired(block.timestamp, fpSharePrice.timestamp);
            }
            price = fpSharePrice.value;
        } else {
            price = totSup == 0 ? initialSharePrice : prices[address(this)].getPrice();
        }
        (uint64 _deviationParam, uint64 _deviationLimit, uint64 _depegBaseFee, uint64 _baseFee) = getFees();
        ctx.sharePrice = price;
        ctx.oldTotalSupply = totSup;
        ctx.totalTargetShares = totalTargetShares;
        ctx.deviationParam = _deviationParam;
        ctx.deviationLimit = _deviationLimit;
        ctx.depegBaseFee = _depegBaseFee;
        ctx.baseFee = _baseFee;
        ctx.totalCollectedCashbacks = totalCollectedCashbacks;
        ctx.collectedFees = collectedFees;
        ctx.unusedEthBalance = int(address(this).balance - ctx.totalCollectedCashbacks - ctx.collectedFees);
    }

    function getPricesAndSumQuotes(MpContext memory ctx, AssetArg[] memory selectedAssets)
        internal
        view
        returns (uint[] memory pr)
    {
        uint arrayLen = selectedAssets.length;
        address prevAddress = address(0);
        pr = new uint[](arrayLen);
        for (uint i; i < arrayLen; ++i) {
            address currentAddress = selectedAssets[i].addr;
            int amount = selectedAssets[i].amount;

            if (prevAddress >= currentAddress) revert AssetsNotSortedOrNotUnique();
            prevAddress = currentAddress;

            uint price;
            if (currentAddress == address(this)) {
                price = ctx.sharePrice;
                ctx.totalSupplyDelta = -amount;
            } else {
                price = prices[currentAddress].getPrice();
            }
            pr[i] = price;
            if (amount == 0) revert ZeroAmountSupplied();
            if (amount > 0) {
                ctx.cummulativeInAmount += price * uint(amount) >> FixedPoint96.RESOLUTION;
            } else {
                ctx.cummulativeOutAmount += price * uint(-amount) >> FixedPoint96.RESOLUTION;
            }
        }
    }

    function transferAsset(address asset, uint quantity, address to) internal {
        if (asset != address(this)) {
            IERC20(asset).transfer(to, quantity);
        } else {
            _mint(to, quantity);
        }
    }

    function receiveAsset(MpAsset memory asset, address assetAddress, uint requiredAmount, address refundAddress)
        internal
    {
        uint unusedAmount;
        if (assetAddress != address(this)) {
            unusedAmount = IERC20(assetAddress).balanceOf(address(this)) - asset.quantity;
            if (unusedAmount < requiredAmount) revert InsuficcientBalance();

            uint left = unusedAmount - requiredAmount;
            if (refundAddress != address(0) && left > 0) {
                IERC20(assetAddress).transfer(refundAddress, left);
            }
        } else {
            _burn(address(this), requiredAmount);

            uint left = balanceOf(address(this));
            if (refundAddress != address(0) && left > 0) {
                transfer(refundAddress, left);
            }
        }
    }

    struct AssetArg {
        address addr;
        int amount;
    }

    struct FPSharePriceArg {
        address thisAddress;
        uint128 timestamp;
        uint128 value;
        bytes signature;
    }

    function swap(
        FPSharePriceArg calldata fpSharePrice,
        AssetArg[] calldata selectedAssets,
        bool isExactInput,
        address to,
        address refundTo
    ) external payable notPaused nonReentrant {
        MpContext memory ctx = getContext(fpSharePrice);
        uint[] memory currentPrices = getPricesAndSumQuotes(ctx, selectedAssets);
        ctx.calculateTotalSupplyDelta(isExactInput);

        for (uint i; i < selectedAssets.length; ++i) {
            address tokenAddress = selectedAssets[i].addr;
            int suppliedAmount = selectedAssets[i].amount;
            uint price = currentPrices[i];

            MpAsset memory asset;
            if (selectedAssets[i].addr != address(this)) {
                asset = assets[selectedAssets[i].addr];
            }

            if (isExactInput && suppliedAmount < 0) {
                int amount = int(ctx.cummulativeInAmount) * suppliedAmount / int(ctx.cummulativeOutAmount);
                if (amount > suppliedAmount) revert SleepageExceeded();
                suppliedAmount = amount;
            } else if (!isExactInput && suppliedAmount > 0) {
                int amount = int(ctx.cummulativeOutAmount) * suppliedAmount / int(ctx.cummulativeInAmount);
                if (amount > suppliedAmount) revert SleepageExceeded();
                suppliedAmount = amount;
            }

            if (suppliedAmount > 0) receiveAsset(asset, tokenAddress, uint(suppliedAmount), refundTo);
            else transferAsset(tokenAddress, uint(-suppliedAmount), to);

            if (tokenAddress != address(this)) {
                ctx.calculateDeviationFee(asset, suppliedAmount, price);
                emit AssetChange(tokenAddress, asset.quantity, asset.collectedCashbacks);
                assets[tokenAddress] = asset;
            } else {
                emit AssetChange(address(this), totalSupply(), 0);
            }
        }
        ctx.calculateBaseFee(isExactInput);
        ctx.applyCollected(payable(refundTo));
        totalCollectedCashbacks = ctx.totalCollectedCashbacks;
        collectedFees = ctx.collectedFees;
        emit CollectedFeesChange(ctx.collectedFees);
    }

    function checkSwap(FPSharePriceArg calldata fpSharePrice, AssetArg[] calldata selectedAssets, bool isExactInput)
        external
        view
        returns (int fee, int[] memory amounts)
    {
        MpContext memory ctx = getContext(fpSharePrice);
        uint[] memory currentPrices = getPricesAndSumQuotes(ctx, selectedAssets);
        amounts = new int[](selectedAssets.length);
        ctx.calculateTotalSupplyDelta(isExactInput);

        for (uint i; i < selectedAssets.length; ++i) {
            address tokenAddress = selectedAssets[i].addr;
            int suppliedAmount = selectedAssets[i].amount;
            uint price = currentPrices[i];

            MpAsset memory asset;
            if (selectedAssets[i].addr != address(this)) {
                asset = assets[selectedAssets[i].addr];
            }

            if (isExactInput && suppliedAmount < 0) {
                int amount = int(ctx.cummulativeInAmount) * suppliedAmount / int(ctx.cummulativeOutAmount);
                suppliedAmount = amount;
            } else if (!isExactInput && suppliedAmount > 0) {
                int amount = int(ctx.cummulativeOutAmount) * suppliedAmount / int(ctx.cummulativeInAmount);
                suppliedAmount = amount;
            }

            if (tokenAddress != address(this)) {
                ctx.calculateDeviationFee(asset, suppliedAmount, price);
            }
            amounts[i] = suppliedAmount;
        }
        ctx.calculateBaseFee(isExactInput);
        fee = -ctx.unusedEthBalance;
    }

    function increaseCashback(address assetAddress) external payable notPaused nonReentrant returns (uint128 amount) {
        uint totalCollectedCashbacksCached = totalCollectedCashbacks;
        amount = uint128(address(this).balance - totalCollectedCashbacksCached - collectedFees);
        MpAsset memory asset = assets[assetAddress];
        asset.collectedCashbacks += uint128(amount);
        emit AssetChange(assetAddress, asset.quantity, amount);
        assets[assetAddress] = asset;
        totalCollectedCashbacks = totalCollectedCashbacksCached + amount;
    }

    // ---------------- Owned ------------------

    function updatePrice(address assetAddress, FeedType kind, bytes calldata feedData) external onlyOwner notPaused {
        FeedInfo memory feed = FeedInfo({kind: kind, data: feedData});
        prices[assetAddress] = feed;
        emit FeedChange(assetAddress, feed);
    }

    function updateTargetShares(address[] calldata assetAddresses, uint[] calldata shares) external notPaused {
        if (!isTargetShareSetter[msg.sender]) revert InvalidTargetShareSetterAuthority();

        uint len = assetAddresses.length;
        uint totalTargetSharesCached = totalTargetShares;
        for (uint a; a < len; ++a) {
            address assetAddress = assetAddresses[a];
            uint share = shares[a];
            MpAsset memory asset = assets[assetAddress];
            totalTargetSharesCached = totalTargetSharesCached - asset.share + share;
            asset.share = uint128(share);
            assets[assetAddress] = asset;
            emit TargetShareChange(assetAddress, share, totalTargetSharesCached);
        }
        totalTargetShares = totalTargetSharesCached;
    }

    function withdrawFees(address to) external onlyOwner notPaused returns (uint fees) {
        fees = collectedFees;
        collectedFees = 0;
        payable(to).transfer(fees);
    }

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
        emit PauseChange(isPaused);
    }

    function setCurveParams(
        uint64 newDeviationLimit,
        uint64 newHalfDeviationFee,
        uint64 newDepegBaseFee,
        uint64 newBaseFee
    ) external onlyOwner {
        uint64 newDeviationParam = (newHalfDeviationFee << 32) / newDeviationLimit;
        deviationLimit = newDeviationLimit;
        deviationParam = newDeviationParam;
        depegBaseFee = newDepegBaseFee;
        baseFee = newBaseFee;
        emit FeesChange(newDeviationParam, newDeviationLimit, newDepegBaseFee, newBaseFee);
    }

    function setSharePriceTTL(uint newSharePriceTTL) external onlyOwner {
        sharePriceTTL = newSharePriceTTL;
        emit SharePriceTTLChange(sharePriceTTL);
    }

    function toggleForcePushAuthority(address authority) external onlyOwner {
        isPriceSetter[authority] = !isPriceSetter[authority];
        emit PriceSetterToggled(authority, isPriceSetter[authority]);
    }

    function toggleTargetShareAuthority(address authority) external onlyOwner {
        isTargetShareSetter[authority] = !isTargetShareSetter[authority];
        emit TargetShareSetterToggled(authority, isTargetShareSetter[authority]);
    }
}
