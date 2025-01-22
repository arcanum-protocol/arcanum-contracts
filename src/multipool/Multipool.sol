// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little defi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {MpAsset, MpContext} from "../lib/MpContext.sol";
import {FeedType, PriceMath} from "../lib/Price.sol";
import {FixedPoint96} from "../lib/FixedPoint96.sol";

import {IMultipoolManagerMethods} from "../interfaces/multipool/IMultipoolManagerMethods.sol";
import {IMultipoolMethods} from "../interfaces/multipool/IMultipoolMethods.sol";
import {IMultipool} from "../interfaces/IMultipool.sol";

import {IStaker} from "../interfaces/IStaker.sol";

import {ForcePushArgs, AssetArgs} from "../types/SwapArgs.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Multipool is
    IMultipool,
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using {PriceMath.getPrice} for bytes32;

    // slot 354
    uint16 internal halfDeviationFee;
    uint16 internal deviationLimit;
    uint16 internal depegBaseFee;
    uint16 internal baseFee;
    address internal managementFeeRecepientAddress;
    uint16 internal managementFee;
    uint16 internal totalTargetShares;

    // slot 355
    address internal priceVerifierAddress;
    uint96 internal initialSharePrice;

    mapping(address => MpAsset) internal assets;
    mapping(address => bytes32) internal prices;

    mapping(address => bool) public isTargetShareSetter;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address _priceVerifierAddress,
        uint96 _sharePrice
    )
        public
        initializer
    {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Ownable_init();
        priceVerifierAddress = _priceVerifierAddress;
        initialSharePrice = _sharePrice;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @inheritdoc IMultipoolMethods
    function getPriceFeed(address asset)
        external
        view
        override
        returns (bytes32 priceFeed)
    {
        priceFeed = bytes32(prices[asset]);
    }

    /// @inheritdoc IMultipoolMethods
    function getPrice(address asset) public view override returns (uint price) {
        price = prices[asset].getPrice();
    }

    /// @inheritdoc IMultipoolMethods
    function getAsset(address assetAddress) public view override returns (MpAsset memory asset) {
        asset = assets[assetAddress];
    }

    function expandToX64(uint16 val) internal pure returns (uint res) {
        res = uint(val) * (5 << 32) / 1e5;
    }

    /// @notice Assembles context for swappping
    /// @param forcePushArgs price force push related data
    /// @return ctx state memory context used across swapping
    /// @dev tries to apply force pushed share price if provided address matches otherwhise ignores
    /// struct
    function getContext(ForcePushArgs calldata forcePushArgs)
        public
        view
        returns (MpContext memory ctx)
    {
        uint _totalSupply = totalSupply();

        uint16 _halfDeviationFee = halfDeviationFee;
        uint16 _deviationLimit = deviationLimit;
        uint16 _depegBaseFee = depegBaseFee;
        uint16 _baseFee = baseFee;
        address _managementFeeRecepientAddress = managementFeeRecepientAddress;
        uint16 _managementFee = managementFee;
        uint16 _totalTargetShares = totalTargetShares;

        address _priceVerifierAddress = priceVerifierAddress;
        uint96 _initialSharePrice = initialSharePrice;

        uint price;
        if (forcePushArgs.contractAddress == address(this)) {
            price = forcePushArgs.sharePrice;
        } else {
            // we move initial share price by 64 as it's x32 and prices should be x96
            price = _totalSupply == 0 ? uint(_initialSharePrice) << 64 : prices[address(this)].getPrice();
        }

        ctx.totalTargetShares = _totalTargetShares;
        ctx.sharePrice = price;
        ctx.oldTotalSupply = _totalSupply;
        ctx.deviationIncreaseFee = _deviationLimit != 0 ? expandToX64(_halfDeviationFee) / expandToX64(_deviationLimit) : 0;
        ctx.deviationLimit = expandToX64(_deviationLimit);
        ctx.cashbackFeeShare = expandToX64(_depegBaseFee);
        ctx.baseFee = expandToX64(_baseFee);
        ctx.managementBaseFee = expandToX64(_managementFee);

        ctx.managementFeeRecepient = _managementFeeRecepientAddress;
        ctx.oracleAddress = _priceVerifierAddress;
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
                _transfer(address(this), refundAddress, left);
            }
        }
    }

    function transferFees(
        MpContext memory ctx,
        ForcePushArgs calldata forcePushArgs,
        uint quoteAmount,
        address receiverAddress,
        bool refundEthToReceiver
    ) internal {
        (uint refund, uint managerEarnedFee, uint oracleEarnedFee) = ctx.applyCollected(quoteAmount, msg.value);
        if (refund > 0) {
            payable(refundEthToReceiver ? receiverAddress : msg.sender).transfer(refund);
        }
        if (forcePushArgs.contractAddress == address(this)) {
            payable(ctx.managementFeeRecepient).transfer(managerEarnedFee);
            IStaker(ctx.oracleAddress).commitPrice{value: oracleEarnedFee}(forcePushArgs);
        } else {
            payable(ctx.managementFeeRecepient).transfer(managerEarnedFee + oracleEarnedFee);
        }
        emit Trade(msg.sender, uint128(quoteAmount), uint128(managerEarnedFee), uint128(oracleEarnedFee));
    }

    function swap(
        ForcePushArgs calldata forcePushArgs,
        address assetInAddress,
        address assetOutAddress,
        uint swapAmount,
        bool isExactInput,
        address receiverAddress,
        bool refundEthToReceiver
    )
        external
        payable
        returns (uint amountIn, uint amountOut)
    {
        if (assetOutAddress == assetInAddress) revert AssetsAreSame();

        MpContext memory ctx; 
        MpAsset memory assetIn; 
        MpAsset memory assetOut; 

        uint quoteAmount;

        {{
            if (assetInAddress == address(this)) {
                ctx = getContext(forcePushArgs);
                assetOut = assets[assetOutAddress];
            } else if (assetOutAddress == address(this)) {
                ctx = getContext(forcePushArgs);
                assetIn = assets[assetInAddress];
            } else {
                assetIn = assets[assetInAddress];
                assetOut = assets[assetOutAddress];
                ctx = getContext(forcePushArgs);
            }

            uint priceIn = assetInAddress == address(this) ? ctx.sharePrice : prices[assetInAddress].getPrice();
            uint priceOut = assetOutAddress == address(this) ? ctx.sharePrice : prices[assetOutAddress].getPrice();

            quoteAmount = swapAmount * (isExactInput ? priceIn : priceOut) >> FixedPoint96.RESOLUTION;
            (amountIn, amountOut) = isExactInput ? 
                (swapAmount, swapAmount * priceIn / priceOut) :
                (swapAmount * priceOut / priceIn, swapAmount);

            if (assetInAddress == address(this)) {
                ctx.totalSupplyDelta = -int(amountIn);
            } else if (assetOutAddress == address(this)) {
                ctx.totalSupplyDelta = int(amountOut);
            }

            receiveAsset(assetIn, assetInAddress, amountIn, address(0));
            transferAsset(assetOutAddress, amountOut, receiverAddress);

            if (assetInAddress != address(this)) ctx.calculateDeviationFee(assetIn, int(amountIn), priceIn);
            if (assetOutAddress != address(this)) ctx.calculateDeviationFee(assetOut, -int(amountOut), priceOut);
        }}

        if (assetInAddress == address(this)) {
            assets[assetOutAddress] = assetOut;
            emit AssetChange(assetInAddress, uint128(totalSupply()), 0);
            emit AssetChange(assetOutAddress, assetOut.quantity, assetOut.collectedCashbacks);
        } else if (assetOutAddress == address(this)) {
            assets[assetInAddress] = assetIn;
            emit AssetChange(assetInAddress, assetIn.quantity, assetIn.collectedCashbacks);
            emit AssetChange(assetOutAddress, uint128(totalSupply()), 0);
        } else {
            assets[assetInAddress] = assetIn;
            assets[assetOutAddress] = assetOut;
            emit AssetChange(assetInAddress, assetIn.quantity, assetIn.collectedCashbacks);
            emit AssetChange(assetOutAddress, assetOut.quantity, assetOut.collectedCashbacks);
        }

        transferFees(ctx, forcePushArgs, quoteAmount, receiverAddress, refundEthToReceiver);
    }

    /// @inheritdoc IMultipoolMethods
    function increaseCashback(address assetAddress)
        external
        payable
        override
    {
        uint128 amount = uint128(msg.value);
        MpAsset memory asset = assets[assetAddress];
        asset.collectedCashbacks += uint112(amount);
        emit AssetChange(assetAddress, asset.quantity, amount);
        assets[assetAddress] = asset;
    }

    /// @inheritdoc IMultipoolManagerMethods
    function updatePrices(
        address[] calldata assetAddresses,
        bytes32[] calldata priceData
    )
        external
        override
        onlyOwner
    {
        uint len = assetAddresses.length;
        for (uint i; i < len;) {
            address assetAddress = assetAddresses[i];
            bytes32 _priceData = priceData[i];
            prices[assetAddress] = _priceData;
            emit PriceFeedChange(assetAddress, _priceData);
            unchecked { ++i; }
        }
    }

    /// @inheritdoc IMultipoolManagerMethods
    function updateTargetShares(
        address[] calldata assetAddresses,
        uint16[] calldata targetShares
    )
        external
        override
    {
        if (!isTargetShareSetter[msg.sender]) revert InvalidTargetShareAuthority();

        uint len = assetAddresses.length;
        uint16 totalTargetSharesCached = totalTargetShares;
        for (uint a; a < len;) {
            address assetAddress = assetAddresses[a];
            uint16 targetShare = targetShares[a];
            MpAsset memory asset = assets[assetAddress];
            totalTargetSharesCached = totalTargetSharesCached - asset.targetShare + targetShare;
            asset.targetShare = uint16(targetShare);
            assets[assetAddress] = asset;
            emit TargetShareChange(assetAddress, targetShare, totalTargetSharesCached);
            unchecked { ++a; }
        }
        totalTargetShares = totalTargetSharesCached;
    }

    /// @inheritdoc IMultipoolManagerMethods
    function setFeeParams(
        uint16 newDeviationLimit,
        uint16 newHalfDeviationFee,
        uint16 newDepegBaseFee,
        uint16 newBaseFee,
        uint16 newManagementFee,
        address newManagementFeeRecepientAddress
    )
        external
        override
        onlyOwner
    {
        halfDeviationFee = newHalfDeviationFee;
        deviationLimit = newDeviationLimit;
        depegBaseFee = newDepegBaseFee;
        baseFee = newBaseFee;
        managementFeeRecepientAddress = newManagementFeeRecepientAddress;
        managementFee = newManagementFee;

        emit FeesChange(
            newHalfDeviationFee,
            newDeviationLimit,
            newDepegBaseFee,
            newBaseFee,
            newManagementFee,
            newManagementFeeRecepientAddress
        );
    }

    /// @inheritdoc IMultipoolManagerMethods
    function toggleStrategyManager(
        address authority
    )
        external
        override
        onlyOwner
    {
        bool value = isTargetShareSetter[authority];
        isTargetShareSetter[authority] = !value;
        emit StrategyManagerToggled(authority, !value);
    }

    function updatePriceVerifierAddress(
        address _priceVerifierAddress
    )
        external
        override
        onlyOwner
    {
        emit PriceVerifierUpdated(priceVerifierAddress, _priceVerifierAddress);
        priceVerifierAddress = _priceVerifierAddress;
    }
}
