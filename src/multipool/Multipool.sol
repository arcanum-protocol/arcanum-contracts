// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little defi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {MpAsset, MpContext} from "../lib/MpContext.sol";
import {FeedInfo, FeedType} from "../lib/Price.sol";
import {FixedPoint96} from "../lib/FixedPoint96.sol";

import {
    IMultipool, IMultipoolManagerMethods, IMultipoolMethods
} from "../interfaces/IMultipool.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Multipool is
    IMultipool,
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    function initialize(
        string memory name,
        string memory symbol,
        uint128 startSharePrice
    )
        public
        initializer
    {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __ReentrancyGuard_init();
        __Ownable_init();
        initialSharePrice = startSharePrice;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Asset args that are provided to swap methods
    struct AssetArgs {
        // Multipool asset address
        address assetAddress;
        // Negative for token out, positive for token in
        int amount;
    }

    // Struct that provides overriding of price called force push
    struct ForcePushArgs {
        // Address of this contract
        address contractAddress;
        // Signing timestamp
        uint128 timestamp;
        // Share price of this contract
        uint128 sharePrice;
        // Force push authoirty's sign
        bytes signature;
    }

    mapping(address => MpAsset) internal assets;
    mapping(address => FeedInfo) internal prices;

    uint64 internal deviationParam;
    uint64 internal deviationLimit;
    uint64 internal depegBaseFee;
    uint64 internal baseFee;

    uint public totalTargetShares;
    uint public totalCollectedCashbacks;
    uint public collectedFees;

    uint128 internal initialSharePrice;
    uint128 internal sharePriceValidityDuration;

    mapping(address => bool) public isPriceSetter;
    mapping(address => bool) public isTargetShareSetter;

    address internal developerAddress;
    uint64 internal developerBaseFee;
    uint public collectedDeveloperFees;

    bool public isPaused;

    modifier notPaused() {
        if (isPaused) revert IsPaused();
        _;
    }

    /// @inheritdoc IMultipoolMethods
    function getSharePriceParams()
        external
        view
        override
        returns (uint128 _sharePriceValidityDuration, uint128 _initialSharePrice)
    {
        _sharePriceValidityDuration = sharePriceValidityDuration;
        _initialSharePrice = initialSharePrice;
    }

    /// @inheritdoc IMultipoolMethods
    function getPriceFeed(address asset)
        external
        view
        override
        returns (FeedInfo memory priceFeed)
    {
        priceFeed = prices[asset];
    }

    /// @inheritdoc IMultipoolMethods
    function getPrice(address asset) public view override returns (uint price) {
        price = prices[asset].getPrice();
    }

    function getFeeParams()
        public
        view
        override
        returns (
            uint64 _deviationParam,
            uint64 _deviationLimit,
            uint64 _depegBaseFee,
            uint64 _baseFee,
            uint64 _developerBaseFee,
            address _developerAddress
        )
    {
        _deviationParam = deviationParam;
        _deviationLimit = deviationLimit;
        _depegBaseFee = depegBaseFee;
        _baseFee = baseFee;
        _developerBaseFee = developerBaseFee;
        _developerAddress = developerAddress;
    }

    /// @inheritdoc IMultipoolMethods
    function getAsset(address assetAddress) public view override returns (MpAsset memory asset) {
        asset = assets[assetAddress];
    }

    /// @notice Assembles context for swappping
    /// @param forcePushArgs price force push related data
    /// @return ctx state memory context used across swapping
    /// @dev tries to apply force pushed share price if provided address matches otherwhise ignores
    /// struct
    function getContext(ForcePushArgs calldata forcePushArgs)
        internal
        view
        returns (MpContext memory ctx)
    {
        uint _totalSupply = totalSupply();
        uint price;
        if (forcePushArgs.contractAddress == address(this)) {
            bytes memory data = abi.encodePacked(
                address(forcePushArgs.contractAddress),
                uint(forcePushArgs.timestamp),
                uint(forcePushArgs.sharePrice)
            );
            if (
                !isPriceSetter[keccak256(data).toEthSignedMessageHash().recover(
                    forcePushArgs.signature
                )]
            ) {
                revert InvalidForcePushAuthority();
            }
            if (forcePushArgs.timestamp + sharePriceValidityDuration < block.timestamp) {
                revert ForcePushPriceExpired(block.timestamp, forcePushArgs.timestamp);
            }
            price = forcePushArgs.sharePrice;
        } else {
            price = _totalSupply == 0 ? initialSharePrice : prices[address(this)].getPrice();
        }

        uint64 _deviationParam = deviationParam;
        uint64 _deviationLimit = deviationLimit;
        uint64 _depegBaseFee = depegBaseFee;
        uint64 _baseFee = baseFee;

        ctx.sharePrice = price;
        ctx.oldTotalSupply = _totalSupply;
        ctx.totalTargetShares = totalTargetShares;
        ctx.deviationParam = _deviationParam;
        ctx.deviationLimit = _deviationLimit;
        ctx.depegBaseFee = _depegBaseFee;
        ctx.baseFee = _baseFee;
        ctx.collectedDeveloperFees = collectedDeveloperFees;
        ctx.developerBaseFee = developerBaseFee;
        ctx.totalCollectedCashbacks = totalCollectedCashbacks;
        ctx.collectedFees = collectedFees;
        ctx.unusedEthBalance = int(
            address(this).balance - ctx.totalCollectedCashbacks - ctx.collectedFees
                - ctx.collectedDeveloperFees
        );
    }

    /// @notice Assembles context for swappping
    /// @param ctx Multipool calculation context
    /// @return fetchedPrices Array of prices per each supplied asset
    /// @dev Also checks that assets are unique via asserting that they are sorted and each element
    /// address is stricly bigger
    function getPricesAndSumQuotes(
        MpContext memory ctx,
        AssetArgs[] memory selectedAssets
    )
        internal
        view
        returns (uint[] memory fetchedPrices)
    {
        uint arrayLen = selectedAssets.length;
        address prevAddress = address(0);
        fetchedPrices = new uint[](arrayLen);
        for (uint i; i < arrayLen; ++i) {
            address assetAddress = selectedAssets[i].assetAddress;
            int amount = selectedAssets[i].amount;

            if (prevAddress >= assetAddress) revert AssetsNotSortedOrNotUnique();
            prevAddress = assetAddress;

            uint price;
            if (assetAddress == address(this)) {
                price = ctx.sharePrice;
                ctx.totalSupplyDelta = -amount;
            } else {
                price = prices[assetAddress].getPrice();
            }
            fetchedPrices[i] = price;
            if (amount == 0) revert ZeroAmountSupplied();
            if (amount > 0) {
                ctx.cummulativeInAmount += price * uint(amount) >> FixedPoint96.RESOLUTION;
            } else {
                ctx.cummulativeOutAmount += price * uint(-amount) >> FixedPoint96.RESOLUTION;
            }
        }
    }

    /// @notice Proceeses asset transfer
    /// @param asset Address of asset to send
    /// @param quantity Address value to send
    /// @param to Recepient address
    /// @dev Handles multipool share with no contract calls
    function transferAsset(address asset, uint quantity, address to) internal {
        if (asset != address(this)) {
            IERC20(asset).safeTransfer(to, quantity);
        } else {
            _mint(to, quantity);
        }
    }

    /// @notice Asserts there is enough token balance and makes left value refund
    /// @param asset Asset data structure storing asset relative data
    /// @param assetAddress Address of asset to check and refund
    /// @param requiredAmount Value that is checked to present unused on contract
    /// @param refundAddress Address to receive asset refund
    /// @dev Handles multipool share with no contract calls
    function receiveAsset(
        MpAsset memory asset,
        address assetAddress,
        uint requiredAmount,
        address refundAddress
    )
        internal
    {
        if (assetAddress != address(this)) {
            uint unusedAmount = IERC20(assetAddress).balanceOf(address(this)) - asset.quantity;
            if (unusedAmount < requiredAmount) revert InsufficientBalance(assetAddress);

            uint left = unusedAmount - requiredAmount;
            if (refundAddress != address(0) && left > 0) {
                IERC20(assetAddress).safeTransfer(refundAddress, left);
            }
        } else {
            _burn(address(this), requiredAmount);

            uint left = balanceOf(address(this));
            if (refundAddress != address(0) && left > 0) {
                transferFrom(address(this), refundAddress, left);
            }
        }
    }

    /// @inheritdoc IMultipoolMethods
    function swap(
        ForcePushArgs calldata forcePushArgs,
        AssetArgs[] calldata assetsToSwap,
        bool isExactInput,
        address sendTo,
        address refundTo
    )
        external
        payable
        override
        notPaused
        nonReentrant
    {
        MpContext memory ctx = getContext(forcePushArgs);
        uint[] memory currentPrices = getPricesAndSumQuotes(ctx, assetsToSwap);

        ctx.calculateTotalSupplyDelta(isExactInput);

        for (uint i; i < assetsToSwap.length; ++i) {
            address assetAddress = assetsToSwap[i].assetAddress;
            int suppliedAmount = assetsToSwap[i].amount;
            uint price = currentPrices[i];

            MpAsset memory asset;
            if (assetAddress != address(this)) {
                asset = assets[assetAddress];
            }

            if (isExactInput && suppliedAmount < 0) {
                int amount =
                    int(ctx.cummulativeInAmount) * suppliedAmount / int(ctx.cummulativeOutAmount);
                if (amount > suppliedAmount) revert SleepageExceeded();
                suppliedAmount = amount;
            } else if (!isExactInput && suppliedAmount > 0) {
                int amount =
                    int(ctx.cummulativeOutAmount) * suppliedAmount / int(ctx.cummulativeInAmount);
                if (amount > suppliedAmount) revert SleepageExceeded();
                suppliedAmount = amount;
            }

            if (suppliedAmount > 0) {
                receiveAsset(asset, assetAddress, uint(suppliedAmount), refundTo);
            } else {
                transferAsset(assetAddress, uint(-suppliedAmount), sendTo);
            }

            if (assetAddress != address(this)) {
                ctx.calculateDeviationFee(asset, suppliedAmount, price);
                assets[assetAddress] = asset;
                emit AssetChange(assetAddress, asset.quantity, asset.collectedCashbacks);
            } else {
                emit AssetChange(address(this), totalSupply(), 0);
            }
        }
        ctx.calculateBaseFee(isExactInput);
        ctx.applyCollected(payable(refundTo));

        totalCollectedCashbacks = ctx.totalCollectedCashbacks;
        collectedFees = ctx.collectedFees;
        collectedDeveloperFees = ctx.collectedDeveloperFees;

        emit CollectedFeesChange(address(this).balance, ctx.totalCollectedCashbacks);
    }

    /// @inheritdoc IMultipoolMethods
    function checkSwap(
        ForcePushArgs calldata forcePushArgs,
        AssetArgs[] calldata assetsToSwap,
        bool isExactInput
    )
        external
        view
        override
        returns (int fee, int[] memory amounts)
    {
        MpContext memory ctx = getContext(forcePushArgs);
        uint[] memory currentPrices = getPricesAndSumQuotes(ctx, assetsToSwap);

        amounts = new int[](assetsToSwap.length);
        ctx.calculateTotalSupplyDelta(isExactInput);

        for (uint i; i < assetsToSwap.length; ++i) {
            address assetAddress = assetsToSwap[i].assetAddress;
            int suppliedAmount = assetsToSwap[i].amount;
            uint price = currentPrices[i];

            MpAsset memory asset;
            if (assetAddress != address(this)) {
                asset = assets[assetAddress];
            }

            if (isExactInput && suppliedAmount < 0) {
                int amount =
                    int(ctx.cummulativeInAmount) * suppliedAmount / int(ctx.cummulativeOutAmount);
                suppliedAmount = amount;
            } else if (!isExactInput && suppliedAmount > 0) {
                int amount =
                    int(ctx.cummulativeOutAmount) * suppliedAmount / int(ctx.cummulativeInAmount);
                suppliedAmount = amount;
            }

            if (assetAddress != address(this)) {
                ctx.calculateDeviationFee(asset, suppliedAmount, price);
            }
            amounts[i] = suppliedAmount;
        }
        ctx.calculateBaseFee(isExactInput);
        fee = -ctx.unusedEthBalance;
    }

    /// @inheritdoc IMultipoolMethods
    function increaseCashback(address assetAddress)
        external
        payable
        override
        notPaused
        nonReentrant
        returns (uint128 amount)
    {
        uint totalCollectedCashbacksCached = totalCollectedCashbacks;
        amount = uint128(
            address(this).balance - totalCollectedCashbacksCached - collectedFees
                - collectedDeveloperFees
        );
        MpAsset memory asset = assets[assetAddress];
        asset.collectedCashbacks += uint128(amount);
        emit AssetChange(assetAddress, asset.quantity, amount);
        assets[assetAddress] = asset;
        totalCollectedCashbacks = totalCollectedCashbacksCached + amount;
        emit CollectedFeesChange(address(this).balance, totalCollectedCashbacksCached);
    }

    /// @inheritdoc IMultipoolManagerMethods
    function updatePrices(
        address[] calldata assetAddresses,
        FeedType[] calldata kinds,
        bytes[] calldata feedData
    )
        external
        onlyOwner
        notPaused
    {
        uint len = assetAddresses.length;
        for (uint i; i < len; ++i) {
            address assetAddress = assetAddresses[i];
            FeedInfo memory feed = FeedInfo({kind: kinds[i], data: feedData[i]});
            prices[assetAddress] = feed;
            emit PriceFeedChange(assetAddress, feed);
        }
    }

    /// @inheritdoc IMultipoolManagerMethods
    function updateTargetShares(
        address[] calldata assetAddresses,
        uint[] calldata targetShares
    )
        external
        override
        notPaused
    {
        if (!isTargetShareSetter[msg.sender]) revert InvalidTargetShareAuthority();

        uint len = assetAddresses.length;
        uint totalTargetSharesCached = totalTargetShares;
        for (uint a; a < len; ++a) {
            address assetAddress = assetAddresses[a];
            uint targetShare = targetShares[a];
            MpAsset memory asset = assets[assetAddress];
            totalTargetSharesCached = totalTargetSharesCached - asset.targetShare + targetShare;
            asset.targetShare = uint128(targetShare);
            assets[assetAddress] = asset;
            emit TargetShareChange(assetAddress, targetShare, totalTargetSharesCached);
        }
        totalTargetShares = totalTargetSharesCached;
    }

    /// @inheritdoc IMultipoolManagerMethods
    function withdrawFees(address to) external override onlyOwner returns (uint fees) {
        fees = collectedFees;
        collectedFees = 0;
        payable(to).transfer(fees);
        emit CollectedFeesChange(address(this).balance, totalCollectedCashbacks);
    }

    /// @inheritdoc IMultipoolManagerMethods
    function withdrawDeveloperFees() external override notPaused returns (uint fees) {
        fees = collectedDeveloperFees;
        collectedDeveloperFees = 0;
        payable(developerAddress).transfer(fees);
        emit CollectedFeesChange(address(this).balance, totalCollectedCashbacks);
    }

    /// @inheritdoc IMultipoolManagerMethods
    function togglePause() external override onlyOwner {
        isPaused = !isPaused;
        emit PauseChange(isPaused);
    }

    /// @inheritdoc IMultipoolManagerMethods
    function setFeeParams(
        uint64 newDeviationLimit,
        uint64 newHalfDeviationFee,
        uint64 newDepegBaseFee,
        uint64 newBaseFee,
        address newDeveloperAddress,
        uint64 newDeveloperBaseFee
    )
        external
        override
        onlyOwner
    {
        uint64 newDeviationParam = (newHalfDeviationFee << 32) / newDeviationLimit;
        deviationLimit = newDeviationLimit;
        deviationParam = newDeviationParam;
        depegBaseFee = newDepegBaseFee;
        baseFee = newBaseFee;
        developerAddress = newDeveloperAddress;
        developerBaseFee = newDeveloperBaseFee;
        emit FeesChange(
            newDeveloperAddress,
            newDeviationParam,
            newDeviationLimit,
            newDepegBaseFee,
            newBaseFee,
            newDeveloperBaseFee
        );
    }

    /// @inheritdoc IMultipoolManagerMethods
    function setSharePriceValidityDuration(uint128 newValidityDuration)
        external
        override
        onlyOwner
    {
        sharePriceValidityDuration = newValidityDuration;
        emit SharePriceExpirationChange(newValidityDuration);
    }

    /// @inheritdoc IMultipoolManagerMethods
    function setAuthorityRights(
        address authority,
        bool forcePushSettlement,
        bool targetShareSettlement
    )
        external
        override
        onlyOwner
    {
        isPriceSetter[authority] = forcePushSettlement;
        isTargetShareSetter[authority] = targetShareSettlement;
        emit AuthorityRightsChange(authority, forcePushSettlement, targetShareSettlement);
    }
}
