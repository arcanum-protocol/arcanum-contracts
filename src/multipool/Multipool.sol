// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only heart

import "forge-std/Test.sol";
import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MpAsset, MpContext} from "../lib/MpContext.sol";
import {FeedInfo, FeedType} from "../lib/Price.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/utils/ReentrancyGuardUpgradeable.sol";
import {FixedPoint96} from "../lib/FixedPoint96.sol";

import { ECDSA } from "openzeppelin/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "openzeppelin/utils/cryptography/MessageHashUtils.sol";

error InvalidForcePushAuthoritySignature();
error ForcePushedPriceExpired();
error DeviationExceedsLimit();
error FeeExceeded();
error ZeroAmountSupplied();
error InsuficcientBalance();
error SleepageExceeded();

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
    using MessageHashUtils for bytes32;

    function initialize(string memory mpName, string memory mpSymbol, address owner, uint sharePrice)
        public
        initializer
    {
        __ERC20_init(mpName, mpSymbol);
        __ERC20Permit_init(mpName);
        __ReentrancyGuard_init();
        __Ownable_init(owner);
        initialSharePrice = sharePrice;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * ---------------- Variables ------------------
     */

    mapping(address => MpAsset) internal assets;
    mapping(address => FeedInfo) internal prices;

    uint public totalTargetShares;

    uint64 internal deviationParam;
    uint64 internal deviationLimit;
    uint64 internal depegBaseFee;
    uint64 internal baseFee;

    bool public isPaused;

    uint public totalCollectedCashbacks;
    uint public collectedFees;

    uint internal initialSharePrice;
    uint internal sharePriceTTL;

    mapping(address => bool) internal isPriceSetter;

    modifier notPaused() {
        _;
    }

    // ---------------- Methods ------------------

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
            bytes memory data = abi.encodePacked(fpSharePrice.thisAddress, fpSharePrice.timestamp, fpSharePrice.value);
            if (!isPriceSetter[keccak256(data).toEthSignedMessageHash().recover(fpSharePrice.signature)]) 
                revert InvalidForcePushAuthoritySignature();
            if (block.timestamp - fpSharePrice.timestamp >= sharePriceTTL)
                revert ForcePushedPriceExpired();
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

    function getTransferredAmount(MpAsset memory asset, address assetAddress) internal view returns (uint amount) {
        amount = IERC20(assetAddress).balanceOf(address(this)) - asset.quantity;
    }

    function getPricesAndSumQuotes(MpContext memory ctx, AssetArg[] memory selectedAssets)
        internal
        view
        returns (uint[] memory pr)
    {
        uint arrayLen = selectedAssets.length;
        pr = new uint[](arrayLen);
        for (uint i; i < arrayLen;) {
            uint price;
            if (selectedAssets[i].addr == address(this)) {
                price = ctx.sharePrice;
                ctx.totalSupplyDelta -= selectedAssets[i].amount;
            } else {
                price = prices[selectedAssets[i].addr].getPrice();
            }
            pr[i] = price;
            if (selectedAssets[i].amount == 0) revert ZeroAmountSupplied();
            if (selectedAssets[i].amount > 0) {
                ctx.cummulativeInAmount += price * uint(selectedAssets[i].amount) >> FixedPoint96.RESOLUTION;
            } else {
                ctx.cummulativeOutAmount += price * uint(-selectedAssets[i].amount) >> FixedPoint96.RESOLUTION;
            }
            unchecked {
                ++i;
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
        bool isSleepageReverse,
        address to,
        bool refundDust,
        address refundTo
    ) public payable notPaused nonReentrant {
        MpContext memory ctx = getContext(fpSharePrice);
        uint[] memory currentPrices = getPricesAndSumQuotes(ctx, selectedAssets);

        for (uint i; i < selectedAssets.length;) {
            address tokenAddress = selectedAssets[i].addr;
            int suppliedAmount = selectedAssets[i].amount;
            MpAsset memory asset;
            if (selectedAssets[i].addr != address(this)) {
                asset = assets[selectedAssets[i].addr];
            }
            uint price = currentPrices[i];
            if (!isSleepageReverse) {
                if (suppliedAmount > 0) {
                    uint transferred = getTransferredAmount(asset, tokenAddress);
                    if (!(transferred >= uint(suppliedAmount))) revert InsuficcientBalance();
                    if (refundDust && (transferred - uint(suppliedAmount)) > 0) {
                        IERC20(tokenAddress).transfer(refundTo, transferred - uint(suppliedAmount));
                    }
                } else {
                    uint amount = ctx.cummulativeInAmount * uint(-suppliedAmount) / ctx.cummulativeOutAmount;

                    if (!(int(amount) >= suppliedAmount)) revert SleepageExceeded();
                    if (tokenAddress != address(this)) {
                        IERC20(tokenAddress).transfer(to, amount);
                    }

                    suppliedAmount = -int(amount);
                }
            } else {
                if (suppliedAmount > 0) {
                    uint amount = ctx.cummulativeOutAmount * uint(suppliedAmount) / ctx.cummulativeInAmount;

                    uint transferred = getTransferredAmount(asset, tokenAddress);
                    if (!(amount <= uint(suppliedAmount))) revert SleepageExceeded();
                    if (!(transferred >= amount)) revert InsuficcientBalance();
                    if (refundDust && (transferred - amount) > 0) {
                        IERC20(tokenAddress).transfer(refundTo, transferred - amount);
                    }

                    suppliedAmount = int(amount);
                } else {
                    if (tokenAddress != address(this)) {
                        IERC20(tokenAddress).transfer(to, uint(-suppliedAmount));
                    }
                }
            }
            if (tokenAddress != address(this)) {
                ctx.calculateFees(asset, suppliedAmount, price);
                assets[tokenAddress] = asset;
            } else {
                ctx.calculateFeesShareToken(suppliedAmount);
            }
            unchecked {
                ++i;
            }
        }
        ctx.applyCollected(payable(refundTo));
        if (ctx.totalSupplyDelta > 0) {
            _mint(to, uint(ctx.totalSupplyDelta));
        } else if (ctx.totalSupplyDelta < 0) {
            _burn(address(this), uint(-ctx.totalSupplyDelta));
        }

        totalCollectedCashbacks = ctx.totalCollectedCashbacks;
        collectedFees = ctx.collectedFees;
    }

    function increaseCashback(address assetAddress) public notPaused nonReentrant returns (uint amount) {
        MpAsset storage asset = assets[assetAddress];
        amount = getTransferredAmount(asset, assetAddress);
        asset.collectedCashbacks += uint128(amount);
    }

    // ---------------- Owner ------------------

    function updatePrice(address assetAddress, FeedType kind, bytes calldata feedData) public onlyOwner notPaused {
        prices[assetAddress] = FeedInfo({kind: kind, data: feedData});
    }

    function updateTargetShares(address[] calldata assetAddresses, uint[] calldata shares) public onlyOwner notPaused {
        uint len = assetAddresses.length;
        for (uint a; a < len;) {
            MpAsset storage asset = assets[assetAddresses[a]];
            totalTargetShares = totalTargetShares - asset.share + shares[a];
            asset.share = uint128(shares[a]); 
            unchecked { ++a; }
        }
    }

    function withdrawFees(address to) public onlyOwner notPaused returns (uint fees) {
        fees = collectedFees;
        collectedFees = 0;
        payable(to).transfer(fees);
    }


    function togglePause() external onlyOwner {
        isPaused = !isPaused;
    }

    function setCurveParams(
        uint64 newDeviationLimit,
        uint64 newHalfDeviationFee,
        uint64 newDepegBaseFee,
        uint64 newBaseFee
    ) external onlyOwner {
        deviationLimit = newDeviationLimit;
        deviationParam = (newHalfDeviationFee << 32) / newDeviationLimit;
        depegBaseFee = newDepegBaseFee;
        baseFee = newBaseFee;
    }

    function setSharePriceTTL(uint newSharePriceTTL) external onlyOwner {
        sharePriceTTL = newSharePriceTTL;
    }

    function toggleForcePushAuthority(address authority) external onlyOwner {
         isPriceSetter[authority] = !isPriceSetter[authority];
    }
}
