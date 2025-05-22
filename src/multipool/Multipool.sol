// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little DeFi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {MpAsset, unpackMpAsset, packMpAsset, MpContext, Fees} from "../lib/MpContext.sol";
import {getBits, setBits} from "../lib/Binary.sol";
import {FeedType, PriceMath} from "../lib/Price.sol";
import {FixedPoint96} from "../lib/FixedPoint.sol";

import {IMultipoolMethods} from "../interfaces/multipool/IMultipoolMethods.sol";
import {IMultipoolManagerMethods} from "../interfaces/multipool/IMultipoolManagerMethods.sol";

import {IMultipool} from "../interfaces/IMultipool.sol";

import {IArcanumOracle} from "../interfaces/IArcanumOracle.sol";
import {OraclePrice} from "../types/OraclePrice.sol";
import {ReceiverData} from "../types/ReceiverData.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
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
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using {PriceMath.getPrice} for bytes32;

    // Slot 354
    //address internal oracleAddress;
    //uint19 internal deviationIncreaseFee;
    //uint19 internal feeToCashbackRatio;
    //uint20 internal baseFee;
    //uint19 internal lpFee;
    //uint19 internal managementFee;
    bytes32 internal slot1;


    // Slot 355
    uint112 internal collectedLpFee;
    uint112 internal collectedManagementFee;
    uint16 internal totalTargetShares;
    uint16 internal deviationLimit;


    // Slot 356
    address public managementFeeReceiver;
    address public lpFeeReceiver;

    mapping(address => bytes32) internal assets;
    mapping(address => bytes32) internal prices;
    address[] internal usedAssets;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address _oracleAddress
    )
        public
        initializer
    {
        __ERC20_init(name, symbol);
        __Ownable_init();
        // Set oracle address
        slot1 = setBits(slot1, bytes32(uint(_oracleAddress)), 0, 160);
        emit PriceOracleChange(address(0), _oracleAddress);
        emit PoolCreated();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        super._afterTokenTransfer(from, to, amount);
        emit ShareTransfer(from, to, amount);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        _transferOwnership(newOwner);
        emit MultipoolOwnerChange(newOwner);
    }

    /// @inheritdoc IMultipoolMethods
    function getUsedAssets(
        uint limit,
        uint offset
    )
        external
        view
        override
        returns (address[] memory, uint)
    {
        uint size = (limit > usedAssets.length ? usedAssets.length : limit);
        address[] memory assetsRes = new address[](size);
        for (uint i = 0; i < size; i++) {
            assetsRes[i] = usedAssets[i + offset];
        }
        uint length = usedAssets.length;
        return (assetsRes, length);
    }

    /// @inheritdoc IMultipoolMethods
    function getSharePricePart(
        uint limit,
        uint offset
    )
        public
        view
        override
        returns (uint pricePart)
    {
        unchecked {
            for (
                uint i = offset;
                i < (limit == type(uint).max ? usedAssets.length : limit + offset);
                i++
            ) {
                address assetAddress = usedAssets[i];
                uint quantity = getBits(assets[assetAddress], 1, 127);
                if (quantity != 0) pricePart += quantity * prices[assetAddress].getPrice();
            }
            pricePart /= totalSupply();
        }
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
        asset = unpackMpAsset(assets[assetAddress]);
    }

    function expandFrom20(uint val) internal pure returns (uint res) {
        res = val * (1 << 32) / 1e6;
    }

    function expandFrom19(uint val) internal pure returns (uint res) {
        res = val * (2 << 32) / 1e6;
    }

    function expandFrom16(uint val) internal pure returns (uint res) {
        res = val * (5 << 32) / 1e5;
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

        bytes32 _slot = slot1;

        uint112 _collectedLpFee = collectedLpFee;
        uint112 _collectedManagementFee = collectedManagementFee;
        uint16 _totalTargetShares = totalTargetShares;
        uint16 _deviationLimit = deviationLimit;

        uint price;
        if (oraclePrice.contractAddress == address(this)) {
            price = oraclePrice.sharePrice;
        } else {
            // We move initial share price by 64 as it's x32 and prices should be x96
            if (_totalSupply == 0) {
                // initial share price is 1 native token
                price = uint(1 << 96);
            } else {
                // TODO: check if this method's unchecked actually is legit
                bytes32 sharePriceSlot = prices[address(this)];
                price = sharePriceSlot == 0
                    ? getSharePricePart(type(uint).max, 0)
                    : sharePriceSlot.getPrice();
            }
        }

        ctx.totalTargetShares = _totalTargetShares;
        ctx.sharePrice = price;
        ctx.oldTotalSupply = _totalSupply;
        ctx.deviationLimit = expandFrom16(_deviationLimit);

        ctx.oracleAddress = address(uint160(getBits(_slot, 0, 160)));
        ctx.deviationIncreaseFee = expandFrom19(getBits(_slot, 160, 19));
        ctx.feeToCashbackRatio = expandFrom19(getBits(_slot, 179, 19));
        ctx.baseFee = expandFrom20(getBits(_slot, 198, 20));
        ctx.lpBaseFee = expandFrom19(getBits(_slot, 218, 19));
        ctx.managementBaseFee = expandFrom19(getBits(_slot, 237, 19));

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
    function estimate_swap(
        OraclePrice calldata oraclePrice,
        address assetInAddress,
        address assetOutAddress,
        uint swapAmount,
        bool isExactInput
    )
        external
        view
        returns (uint amountIn, uint amountOut, uint fees, uint cashbacks)
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

        {
            {
                if (assetInAddress == address(this)) {
                    assetOut = unpackMpAsset(assets[assetOutAddress]);
                } else if (assetOutAddress == address(this)) {
                    assetIn = unpackMpAsset(assets[assetInAddress]);
                } else {
                    assetIn = unpackMpAsset(assets[assetInAddress]);
                    assetOut = unpackMpAsset(assets[assetOutAddress]);
                }

                (amountIn, amountOut) = isExactInput
                    ? (swapAmount, swapAmount * price.priceIn / price.priceOut)
                    : (swapAmount * price.priceOut / price.priceIn, swapAmount);

                if (assetInAddress == address(this)) {
                    ctx.totalSupplyDelta = -int(amountIn);
                } else if (assetOutAddress == address(this)) {
                    ctx.totalSupplyDelta = int(amountOut);
                }

                if (assetInAddress != address(this)) {
                    ctx.calculateDeviationFee(assetIn, int(amountIn), price.priceIn);
                }
                if (assetOutAddress != address(this)) {
                    ctx.calculateDeviationFee(assetOut, -int(amountOut), price.priceOut);
                }

                (fees, cashbacks) = ctx.estimateFees(
                    swapAmount * (isExactInput ? price.priceIn : price.priceOut)
                        >> FixedPoint96.RESOLUTION
                );
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
                    assetOut = unpackMpAsset(assets[assetOutAddress]);
                } else if (assetOutAddress == address(this)) {
                    assetIn = unpackMpAsset(assets[assetInAddress]);
                } else {
                    assetIn = unpackMpAsset(assets[assetInAddress]);
                    assetOut = unpackMpAsset(assets[assetOutAddress]);
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
                    assets[assetOutAddress] = packMpAsset(assetOut);
                    emit AssetChange(assetInAddress, uint128(totalSupply()), 0);
                    emit AssetChange(
                        assetOutAddress, assetOut.quantity, assetOut.collectedCashbacks
                    );
                } else if (assetOutAddress == address(this)) {
                    assets[assetInAddress] = packMpAsset(assetIn);
                    emit AssetChange(assetInAddress, assetIn.quantity, assetIn.collectedCashbacks);
                    emit AssetChange(assetOutAddress, uint128(totalSupply()), 0);
                } else {
                    assets[assetInAddress] = packMpAsset(assetIn);
                    assets[assetOutAddress] = packMpAsset(assetOut);
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
        if (oraclePrice.contractAddress == address(this))  {
            payable(ctx.managementFeeRecepient).transfer(fees.managerEarnedFee);
            IArcanumOracle(ctx.oracleAddress).commitPrice{value: fees.oracleEarnedFee}(oraclePrice);
        } else if (ctx.oracleAddress != address(0)) {
            payable(ctx.managementFeeRecepient).transfer(fees.managerEarnedFee);
            payable(ctx.oracleAddress).transfer(fees.oracleEarnedFee);
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
        MpAsset memory asset = unpackMpAsset(assets[assetAddress]);
        asset.collectedCashbacks += uint112(amount);
        emit AssetChange(assetAddress, asset.quantity, amount);
        assets[assetAddress] = packMpAsset(asset);
    }

    /// @inheritdoc IMultipoolManagerMethods
    function updateAssets(
        address[] calldata priceAssetAddresses,
        bytes32[] calldata priceData,
        address[] calldata targetShareAssetAddresses,
        uint16[] calldata targetShares
    )
        external
        onlyOwner
    {
        uint len = priceAssetAddresses.length;
        if (len) {
            for (uint i; i < len;) {
                address assetAddress = priceAssetAddresses[i];
                bytes32 _priceData = priceData[i];
                prices[assetAddress] = _priceData;
                emit PriceFeedChange(assetAddress, _priceData);
                unchecked {
                    ++i;
                }
            }
        }

        len = targetShareAssetAddresses.length;
        if (len) {
            uint16 totalTargetSharesCached = totalTargetShares;
            for (uint a; a < len;) {
                address assetAddress = targetShareAssetAddresses[a];
                uint16 targetShare = targetShares[a];
                MpAsset memory asset = unpackMpAsset(assets[assetAddress]);
                totalTargetSharesCached =
                    totalTargetSharesCached - uint16(asset.targetShare) + targetShare;
                asset.targetShare = uint16(targetShare);
                if (!asset.isUsed) {
                    usedAssets.push(assetAddress);
                    asset.isUsed = true;
                }
                assets[assetAddress] = packMpAsset(asset);
                emit TargetShareChange(assetAddress, targetShare, totalTargetSharesCached);
                unchecked {
                    ++a;
                }
            }
            totalTargetShares = totalTargetSharesCached;
        }
    }

    struct FeeParams {
        uint24 deviationIncreaseFee;
        uint24 deviationLimit;
        uint24 feeToCashbackRatio;
        uint24 baseFee;
        uint24 managementFee;
        uint24 lpFee;

        address managementFeeReceiver;
        address lpFeeReceiver;
        address oracleAddress;
    }

    function setFeeParams(
        FeeParams calldata params
    )
        external
        onlyOwner
    {
        deviationLimit = params.deviationLimit;

        bytes32 _slot;
        _slot = setBits(_slot, bytes32(uint(uint160(params.oracleAddress))), 0, 160);
        _slot = setBits(_slot, bytes32(uint(params.deviationIncreaseFee)), 160, 19);
        _slot = setBits(_slot, bytes32(uint(params.feeToCashbackRatio)), 179, 19);
        _slot = setBits(_slot, bytes32(uint(params.baseFee)), 198, 20);
        _slot = setBits(_slot, bytes32(uint(params.lpFee)), 218, 19);
        _slot = setBits(_slot, bytes32(uint(params.managementFee)), 237, 19);

        managementFeeReceiver = params.managementFeeReceiver;
        lpFeeReceiver = params.lpFeeReceiver;

        // TODO
        emit FeesChange();
    }
}
