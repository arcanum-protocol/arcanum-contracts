// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little DeFi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {MpAsset, MpContext, Fees} from "../lib/MpContext.sol";
import {FeedType, PriceMath} from "../lib/Price.sol";
import {FixedPoint96} from "../lib/FixedPoint.sol";

import {IMultipoolMethods} from "../interfaces/multipool/IMultipoolMethods.sol";
import {IMultipoolManagerMethods} from "../interfaces/multipool/IMultipoolManagerMethods.sol";

import {IMultipool} from "../interfaces/IMultipool.sol";

import {IArcanumOracle} from "../interfaces/IArcanumOracle.sol";
import {OraclePrice} from "../types/OraclePrice.sol";
import {ReceiverData} from "../types/ReceiverData.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";

struct Prices {
    uint priceIn;
    uint priceOut;
}

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

    // Slot 354
    uint16 internal deviationIncreaseFee;
    uint16 internal deviationLimit;
    uint16 internal feeToCashbackRatio;
    uint16 internal baseFee;
    address internal managementFeeRecepient;
    uint16 internal managementFee;
    uint16 internal totalTargetShares;

    // Slot 355
    address internal oracleAddress;
    uint96 internal initialSharePrice;

    // Slot 356
    address public strategyManager;

    mapping(address => MpAsset) internal assets;
    mapping(address => bytes32) internal prices;
    address[] public usedAssets;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address _oracleAddress,
        uint96 _sharePrice
    )
        public
        initializer
    {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __Ownable_init();
        oracleAddress = _oracleAddress;
        initialSharePrice = _sharePrice;
        emit PriceOracleUpdated(address(0), _oracleAddress);
        emit PoolCreated(_sharePrice);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function usedAssetsLegnth() external view returns (uint) {
        return usedAssets.length;
    }
    /// @inheritdoc IMultipoolMethods

    function getPriceFeed(address asset) external view override returns (bytes32 priceFeed) {
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
    /// @param oraclePrice signed multipool price related data
    /// @return ctx state memory context used across swapping
    /// @dev tries to apply signed share price if provided address matches otherwhise ignores
    /// struct
    function getContext(OraclePrice calldata oraclePrice)
        public
        view
        returns (MpContext memory ctx)
    {
        uint _totalSupply = totalSupply();

        uint16 _deviationIncreaseFee = deviationIncreaseFee;
        uint16 _deviationLimit = deviationLimit;
        uint16 _feeToCashbackRatio = feeToCashbackRatio;
        uint16 _baseFee = baseFee;
        address _managementFeeRecepient = managementFeeRecepient;
        uint16 _managementFee = managementFee;
        uint16 _totalTargetShares = totalTargetShares;

        address _oracleAddress = oracleAddress;
        uint96 _initialSharePrice = initialSharePrice;

        uint price;
        if (oraclePrice.contractAddress == address(this)) {
            price = oraclePrice.sharePrice;
        } else {
            // We move initial share price by 64 as it's x32 and prices should be x96
            price = _totalSupply == 0
                ? uint(_initialSharePrice) << 64
                : prices[address(this)].getPrice();
        }

        ctx.totalTargetShares = _totalTargetShares;
        ctx.sharePrice = price;
        ctx.oldTotalSupply = _totalSupply;
        ctx.deviationIncreaseFee = expandToX64(_deviationIncreaseFee);
        ctx.deviationLimit = expandToX64(_deviationLimit);
        ctx.feeToCashbackRatio = expandToX64(_feeToCashbackRatio);
        ctx.baseFee = expandToX64(_baseFee);
        ctx.managementBaseFee = expandToX64(_managementFee);

        ctx.managementFeeRecepient = _managementFeeRecepient;
        ctx.oracleAddress = _oracleAddress;
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

    /// @inheritdoc IMultipoolMethods
    function swap(
        OraclePrice calldata oraclePrice,
        address assetInAddress,
        address assetOutAddress,
        uint swapAmount,
        bool isExactInput,
        ReceiverData calldata data
    )
        external
        payable
        override
        returns (uint amountIn, uint amountOut)
    {
        if (swapAmount == 0) revert ZeroAmountSupplied();
        if (assetOutAddress == assetInAddress) revert AssetsAreSame();

        MpContext memory ctx = getContext(oraclePrice);
        MpAsset memory assetIn;
        MpAsset memory assetOut;
        Prices memory price;

        price.priceIn =
            assetInAddress == address(this) ? ctx.sharePrice : prices[assetInAddress].getPrice();
        price.priceOut =
            assetOutAddress == address(this) ? ctx.sharePrice : prices[assetOutAddress].getPrice();

        Fees memory fees;

        {
            {
                if (assetInAddress == address(this)) {
                    assetOut = assets[assetOutAddress];
                } else if (assetOutAddress == address(this)) {
                    assetIn = assets[assetInAddress];
                } else {
                    assetIn = assets[assetInAddress];
                    assetOut = assets[assetOutAddress];
                }

                (amountIn, amountOut) = isExactInput
                    ? (swapAmount, swapAmount * price.priceIn / price.priceOut)
                    : (swapAmount * price.priceOut / price.priceIn, swapAmount);

                if (assetInAddress == address(this)) {
                    ctx.totalSupplyDelta = -int(amountIn);
                } else if (assetOutAddress == address(this)) {
                    ctx.totalSupplyDelta = int(amountOut);
                }

                receiveAsset(assetIn, assetInAddress, amountIn, data.refundAddress);
                transferAsset(assetOutAddress, amountOut, data.receiverAddress);

                if (assetInAddress != address(this)) {
                    ctx.calculateDeviationFee(assetIn, int(amountIn), price.priceIn);
                }
                if (assetOutAddress != address(this)) {
                    ctx.calculateDeviationFee(assetOut, -int(amountOut), price.priceOut);
                }

                if (assetInAddress == address(this)) {
                    assets[assetOutAddress] = assetOut;
                    emit AssetChange(assetInAddress, uint128(totalSupply()), 0);
                    emit AssetChange(
                        assetOutAddress, assetOut.quantity, assetOut.collectedCashbacks
                    );
                } else if (assetOutAddress == address(this)) {
                    assets[assetInAddress] = assetIn;
                    emit AssetChange(assetInAddress, assetIn.quantity, assetIn.collectedCashbacks);
                    emit AssetChange(assetOutAddress, uint128(totalSupply()), 0);
                } else {
                    assets[assetInAddress] = assetIn;
                    assets[assetOutAddress] = assetOut;
                    emit AssetChange(assetInAddress, assetIn.quantity, assetIn.collectedCashbacks);
                    emit AssetChange(
                        assetOutAddress, assetOut.quantity, assetOut.collectedCashbacks
                    );
                }
                fees = ctx.applyCollected(
                    swapAmount * (isExactInput ? price.priceIn : price.priceOut)
                        >> FixedPoint96.RESOLUTION,
                    msg.value
                );
            }
        }

        if (fees.refund > 0) {
            payable(data.refundEthToReceiver ? data.receiverAddress : msg.sender).transfer(
                fees.refund
            );
        }
        if (oraclePrice.contractAddress == address(this)) {
            payable(ctx.managementFeeRecepient).transfer(fees.managerEarnedFee);
            IArcanumOracle(ctx.oracleAddress).commitPrice{value: fees.oracleEarnedFee}(oraclePrice);
        } else {
            payable(ctx.managementFeeRecepient).transfer(
                fees.managerEarnedFee + fees.oracleEarnedFee
            );
        }
        emit Swap(
            msg.sender,
            assetInAddress,
            assetOutAddress,
            amountIn,
            amountOut,
            price.priceIn,
            price.priceOut,
            fees.managerEarnedFee,
            fees.oracleEarnedFee
        );
    }

    /// @inheritdoc IMultipoolMethods
    function increaseCashback(address assetAddress) external payable override {
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
            unchecked {
                ++i;
            }
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
        if (strategyManager != msg.sender && owner() != msg.sender) {
            revert InvalidTargetShareAuthority();
        }

        uint len = assetAddresses.length;
        uint16 totalTargetSharesCached = totalTargetShares;
        for (uint a; a < len;) {
            address assetAddress = assetAddresses[a];
            uint16 targetShare = targetShares[a];
            MpAsset memory asset = assets[assetAddress];
            totalTargetSharesCached = totalTargetSharesCached - asset.targetShare + targetShare;
            asset.targetShare = uint16(targetShare);
            if (!asset.isUsed) {
                usedAssets.push(assetAddress);
                asset.isUsed = true;
            }
            assets[assetAddress] = asset;
            emit TargetShareChange(assetAddress, targetShare, totalTargetSharesCached);
            unchecked {
                ++a;
            }
        }
        totalTargetShares = totalTargetSharesCached;
    }

    /// @inheritdoc IMultipoolManagerMethods
    function setFeeParams(
        uint16 newDeviationIncreaseFee,
        uint16 newDeviationLimit,
        uint16 newFeeToCashbackRatio,
        uint16 newBaseFee,
        address newManagementFeeRecepient,
        uint16 newManagementFee
    )
        external
        override
        onlyOwner
    {
        deviationIncreaseFee = newDeviationIncreaseFee;
        deviationLimit = newDeviationLimit;
        feeToCashbackRatio = newFeeToCashbackRatio;
        baseFee = newBaseFee;
        managementFeeRecepient = newManagementFeeRecepient;
        managementFee = newManagementFee;

        emit FeesChange(
            newDeviationIncreaseFee,
            newDeviationLimit,
            newFeeToCashbackRatio,
            newBaseFee,
            newManagementFee,
            newManagementFeeRecepient
        );
    }

    /// @inheritdoc IMultipoolManagerMethods
    function updateStrategyManager(address newStrategyManager) external override onlyOwner {
        emit StrategyManagerChange(strategyManager, newStrategyManager);
        strategyManager = newStrategyManager;
    }

    /// @inheritdoc IMultipoolManagerMethods
    function updateOracleAddress(address _oracleAddress) external override onlyOwner {
        emit PriceOracleUpdated(oracleAddress, _oracleAddress);
        oracleAddress = _oracleAddress;
    }
}
