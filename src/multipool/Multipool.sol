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

    // slot 1
    uint16 internal halfDeviationFee;
    uint16 internal deviationLimit;
    uint16 internal depegBaseFee;
    uint16 internal baseFee;
    address internal managementFeeRecepientAddress;
    uint16 internal managementFee;
    uint16 internal totalTargetShares;

    // slot 2
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

    function slot1()
        public
        view
        override
        returns (
            uint16 _halfDeviationFee,
            uint16 _deviationLimit,
            uint16 _depegBaseFee,
            uint16 _baseFee,
            address _managementFeeRecepientAddress,
            uint16 _managementFee,
            uint16 _totalTargetShares
        )
    {
        _halfDeviationFee = halfDeviationFee;
        _deviationLimit = deviationLimit;
        _depegBaseFee = depegBaseFee;
        _baseFee = baseFee;
        _managementFeeRecepientAddress = managementFeeRecepientAddress;
        _managementFee = managementFee;
        _totalTargetShares = totalTargetShares;
    }

    function slot2()
        public
        view
        override
        returns (
            address _priceVerifierAddress,
            uint96 _initialSharePrice
        )
    {
        _priceVerifierAddress = priceVerifierAddress;
        _initialSharePrice = initialSharePrice;
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

        (
            uint16 _halfDeviationFee,
            uint16 _deviationLimit,
            uint16 _depegBaseFee,
            uint16 _baseFee,
            address _managementFeeRecepientAddress,
            uint16 _managementFee,
            uint16 _totalTargetShares
        ) = slot1();

        (
            address _priceVerifierAddress,
            uint96 _initialSharePrice
        ) = slot2();

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
        ctx.deviationParam = _deviationLimit != 0 ? ((uint(_halfDeviationFee) * (5 << 32) / 1e5) << 32) / (uint(_deviationLimit) * (5 << 32) / 1e5) : 0;
        ctx.deviationLimit = uint(_deviationLimit) * (5 << 32) / 1e5;
        ctx.depegBaseFee = uint(_depegBaseFee) * (5 << 32) / 1e5;
        ctx.baseFee = uint(_baseFee) * (5 << 32) / 1e5;
        ctx.managementBaseFee = uint(_managementFee) * (5 << 32) / 1e5;
        ctx.unusedEthBalance = int(msg.value);

        ctx.managementFeeRecepient = _managementFeeRecepientAddress;
        ctx.oracleAddress = _priceVerifierAddress;
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
                _transfer(address(this), refundAddress, left);
            }
        }
    }

    //TODO: emit swap prices
    /// @inheritdoc IMultipoolMethods
    function swap(
        ForcePushArgs calldata forcePushArgs,
        AssetArgs[] calldata assetsToSwap,
        bool isExactInput,
        address receiverAddress,
        bool refundEthToReceiver,
        address refundAddress
    )
        external
        payable
        override
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
                receiveAsset(asset, assetAddress, uint(suppliedAmount), refundAddress);
            } else {
                transferAsset(assetAddress, uint(-suppliedAmount), receiverAddress);
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
        ctx.applyCollected(refundEthToReceiver ? payable(receiverAddress) : payable(refundAddress));

        payable(ctx.managementFeeRecepient).transfer(ctx.collectedManagementFees);
        IStaker(ctx.oracleAddress).commitPrice{value: ctx.collectedOracleFees}(forcePushArgs);
        emit Swapped(ctx.collectedManagementFees, ctx.collectedOracleFees);
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
        for (uint i; i < len; ++i) {
            address assetAddress = assetAddresses[i];
            bytes32 _priceData = priceData[i];
            prices[assetAddress] = _priceData;
            emit PriceFeedChange(assetAddress, _priceData);
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
        for (uint a; a < len; ++a) {
            address assetAddress = assetAddresses[a];
            uint16 targetShare = targetShares[a];
            MpAsset memory asset = assets[assetAddress];
            totalTargetSharesCached = totalTargetSharesCached - asset.targetShare + targetShare;
            asset.targetShare = uint16(targetShare);
            assets[assetAddress] = asset;
            emit TargetShareChange(assetAddress, targetShare, totalTargetSharesCached);
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
