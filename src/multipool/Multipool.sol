// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little DeFi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {
    MpMath,
    packMpFees1,
    packMpFees2,
    unpackMpFees1,
    unpackMpFees2,
    unpackMpAsset,
    packMpAsset
} from "../lib/MpContext.sol";
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
    bytes32 internal mpFees1;
    // Slot 355
    bytes32 internal mpFees2;

    address public managerFeeReceiver;
    address public lpFeeReceiver;

    mapping(address => bytes32) internal assets;
    mapping(address => bytes32) internal prices;
    address[] internal usedAssets;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol
    )
        public
        initializer
    {
        __ERC20_init(name, symbol);
        __Ownable_init();
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
                (,uint quantity,,) = unpackMpAsset(assets[assetAddress]);
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
    function getAsset(address assetAddress) public view override returns (bool isUsed, uint quantity, uint cashback, uint targetShare) {
        return unpackMpAsset(assets[assetAddress]);
    }

    function getConfig() public view returns (
        bytes32 _mpFees1,
        bytes32 _mpFees2,
        address _manageFeeReceiver,
        address _lpFeeReceiver,
        uint _totalSupply

    ) {
        return (mpFees1, mpFees2, managerFeeReceiver, lpFeeReceiver, totalSupply());
    }

    function getSharePrice(OraclePrice calldata oraclePrice, uint _totalSupply)
        public
        view
        returns (uint price)
    {
        if (oraclePrice.contractAddress == address(this)) {
            price = oraclePrice.sharePrice;
        } else {
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
    /// @param assetAddress Address of asset to check and refund
    /// @param requiredAmount Value that is checked to present unused on contract
    /// @param refundAddress Address to receive asset refund
    /// @dev Handles multipool share with no contract calls
    function receiveAsset(
        address assetAddress,
        uint requiredAmount,
        address refundAddress
    )
        internal
    {
        if (assetAddress != address(this)) {
            uint balance = IERC20(assetAddress).balanceOf(address(this));
            if (balance < requiredAmount) revert InsufficientBalance(assetAddress);
            uint left = balance - requiredAmount;
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

    function checkSwap(
        OraclePrice calldata oraclePrice,
        address assetInAddress,
        address assetOutAddress,
        uint swapAmount,
        bool isExactInput
    )
        external
        view
        returns (
            uint amountIn,
            uint amountOut,
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund
        )
    {
        (
            ,,,,,,
            uint _managerEarnedFee,
            uint _oracleEarnedFee,
            uint _lpEarnedFee,
            uint _cashbacksRefund,
            uint _amountIn,
            uint _amountOut,
            ,,,,,,,
        ) = estimateSwap(oraclePrice, assetInAddress, assetOutAddress, swapAmount, isExactInput);
        managerEarnedFee = _managerEarnedFee;
        oracleEarnedFee = _oracleEarnedFee;
        lpEarnedFee = _lpEarnedFee;
        cashbacksRefund = _cashbacksRefund;
        amountIn = _amountIn;
        amountOut = _amountOut;
    }

    /// @inheritdoc IMultipoolMethods
    function swap(
        OraclePrice calldata oraclePrice,
        address assetInAddress,
        address assetOutAddress,
        uint swapAmount,
        bool isExactInput,
        address receiverAddress,
        address refundAddress,
        bool refundEthToReceiver
    )
        external
        payable
        override
        returns (uint amountIn, uint amountOut)
    {
        (
            uint _totalSupply,
            uint totalTargetShares,
            uint deviationLimit,
            uint collectedManagerFee,
            uint collectedLpFee,

            address oracleAddress,

            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,

            uint _amountIn,
            uint _amountOut,

            uint quantityIn,
            uint targetShareIn,
            uint collectedCashbacksIn,
            uint priceIn,

            uint quantityOut,
            uint targetShareOut,
            uint collectedCashbacksOut,
            uint priceOut
        ) = estimateSwap(oraclePrice, assetInAddress, assetOutAddress, swapAmount, isExactInput);

        amountIn = _amountIn;
        amountOut = _amountOut;

        if (assetInAddress == address(this)) {
            assets[assetOutAddress] = packMpAsset(true, quantityOut, collectedCashbacksOut, targetShareOut);
            emit AssetChange(assetOutAddress, uint128(quantityOut), uint112(collectedCashbacksOut));
            emit AssetChange(assetInAddress, uint128(_totalSupply - amountOut), 0);
        } else if (assetOutAddress == address(this)) {
            assets[assetInAddress] = packMpAsset(true, quantityIn, collectedCashbacksIn, targetShareIn);
            emit AssetChange(assetInAddress, uint128(quantityIn), uint112(collectedCashbacksIn));
            emit AssetChange(assetOutAddress, uint128(_totalSupply + amountOut), 0);
        } else {
            assets[assetOutAddress] = packMpAsset(true, quantityOut, collectedCashbacksOut, targetShareOut);
            assets[assetInAddress] = packMpAsset(true, quantityIn, collectedCashbacksIn, targetShareIn);
            emit AssetChange(assetInAddress, uint128(quantityIn), uint112(collectedCashbacksIn));
            emit AssetChange(assetOutAddress, uint128(quantityOut), uint112(collectedCashbacksOut));
        }

        receiveAsset(assetInAddress, quantityIn, refundAddress);
        transferAsset(assetOutAddress, amountOut, receiverAddress);

        if (msg.value + cashbacksRefund < (lpEarnedFee + collectedLpFee + oracleEarnedFee)) revert FeeExceeded();

        //if (msg.value > (r.lpEarnedFee + ctx.collectedLpFee + r.oracleEarnedFee))
        //TODO: переписать нахуй чтоб лишний раз не отправлялось а уменьшало необходимое велью
        // точно есть несостыковки как минимум с рефандом эфира в целом
        if (cashbacksRefund > 0) {
            payable(refundEthToReceiver ? receiverAddress : msg.sender).transfer(
                cashbacksRefund
            );
        }

        if (oraclePrice.contractAddress == address(this))  {
            collectedLpFee += lpEarnedFee;
            IArcanumOracle(oracleAddress).commitPrice{value: oracleEarnedFee}(oraclePrice);
        } else if (oracleAddress != address(0)) {
            collectedLpFee += lpEarnedFee;
            payable(oracleAddress).transfer(oracleEarnedFee);
        } else {
            collectedLpFee += lpEarnedFee + oracleEarnedFee;
        }
        collectedManagerFee += managerEarnedFee;

        mpFees2 = packMpFees2(collectedLpFee, collectedManagerFee, totalTargetShares, deviationLimit);

        emit Swap(
            msg.sender,
            assetInAddress,
            assetOutAddress,
            uint112(amountIn),
            uint112(amountOut),
            priceIn,
            priceOut,
            uint112(managerEarnedFee),
            uint112(lpEarnedFee),
            uint112(oracleEarnedFee)
        );
    }

    /// @inheritdoc IMultipoolMethods
    function increaseCashback(address assetAddress) external payable override {
        uint128 amount = uint128(msg.value);
        (bool isUsed, uint quantity, uint collectedCashback, uint s) = unpackMpAsset(assets[assetAddress]);
        collectedCashback += amount;
        emit AssetChange(assetAddress, uint128(quantity), uint112(collectedCashback));
        assets[assetAddress] = packMpAsset(isUsed, quantity, collectedCashback, s);
    }

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
        if (len != 0) {
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
        if (len != 0) {
            bytes32 fees = mpFees2;
            (uint c1, uint c2, uint s, uint d) = unpackMpFees2(fees);
            uint16 totalTargetShares = uint16(s);
            for (uint a; a < len;) {
                address assetAddress = targetShareAssetAddresses[a];
                uint targetShare = targetShares[a];
                bytes32 asset = assets[assetAddress];
                (bool isUsed, uint q, uint c, uint assetTargetShare) = unpackMpAsset(asset);
                totalTargetShares = totalTargetShares - uint16(assetTargetShare) + uint16(targetShare);
                assetTargetShare = uint16(targetShare);
                if (!isUsed) {
                    usedAssets.push(assetAddress);
                }
                assets[assetAddress] = packMpAsset(isUsed, q, c, assetTargetShare);
                emit TargetShareChange(assetAddress, uint16(targetShare), totalTargetShares);
                unchecked {
                    ++a;
                }
            }
            mpFees2 = packMpFees2(c1, c2, totalTargetShares, d);
        }
    }

    function setFeeParams(
        uint24 deviationIncreaseFee,
        uint16 deviationLimit,
        uint24 feeToCashbackRatio,
        uint24 baseFee,
        uint24 managerFee,
        uint24 lpFee,

        address _managerFeeReceiver,
        address _lpFeeReceiver,
        address oracleAddress
    )
        external
        onlyOwner
    {
        bytes32 fees2 = mpFees2;
        (uint c1, uint c2, uint t,) = unpackMpFees2(fees2);
        mpFees2 = packMpFees2(c1, c2, t, deviationLimit);

        mpFees1 = packMpFees1(
            oracleAddress,
            deviationIncreaseFee,
            feeToCashbackRatio,
            baseFee,
            lpFee,
            managerFee
        );

        managerFeeReceiver = _managerFeeReceiver;
        lpFeeReceiver = _lpFeeReceiver;

        emit FeesChange(
          deviationIncreaseFee,
          deviationLimit,
          feeToCashbackRatio,
          baseFee,
          managerFee,
          lpFee,

          managerFeeReceiver,
          lpFeeReceiver,
          oracleAddress
        );
    }

    function claimLpFees(address to) external returns (uint fee) {
        bytes32 fees = mpFees2;
        (
            uint collectedLpFee,
            uint collectedManagerFee,
            uint totalTargetShares,
            uint deviationLimit
        ) = unpackMpFees2(fees);
        if (msg.sender != lpFeeReceiver) revert NotLpFeeReceiver();
        fee = collectedLpFee;
        fees = packMpFees2(0, collectedManagerFee, totalTargetShares, deviationLimit);
        payable(to).transfer(fee);
    }

    function claimManagerFees(address to) external returns (uint fee) {
        bytes32 fees = mpFees2;
        (
            uint collectedLpFee,
            uint collectedManagerFee,
            uint totalTargetShares,
            uint deviationLimit
        ) = unpackMpFees2(fees);

        if (msg.sender != managerFeeReceiver) revert NotManagerFeeReceiver();
        fee = collectedManagerFee;
        fees = packMpFees2(collectedLpFee, 0, totalTargetShares, deviationLimit);
        payable(to).transfer(fee);


    }

    function estimateSwap(
        OraclePrice calldata oraclePrice,
        address assetInAddress,
        address assetOutAddress,
        uint swapAmount,
        bool isExactInput
    )
        internal
        view
        returns (
            uint _totalSupply,
            uint totalTargetShares,
            uint deviationLimit,
            uint collectedManagerFee,
            uint collectedLpFee,

            address oracleAddress,

            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,

            uint amountIn,
            uint amountOut,

            uint quantityIn,
            uint targetShareIn,
            uint collectedCashbacksIn,
            uint priceIn,

            uint quantityOut,
            uint targetShareOut,
            uint collectedCashbacksOut,
            uint priceOut
        )
    {
        if (swapAmount == 0) revert ZeroAmountSupplied();
        if (assetOutAddress == assetInAddress) revert AssetsAreSame();

        _totalSupply = totalSupply();
        uint sharePrice = getSharePrice(oraclePrice, _totalSupply);

        (
           address _oracleAddress,
           uint deviationIncreaseFee,
           uint feeToCashbackRatio,
           uint baseFee,
           uint lpFee,
           uint managerFee
        ) = unpackMpFees1(mpFees1);

        (
            uint _collectedLpFee,
            uint _collectedManagementFee,
            uint _totalTargetShares,
            uint _deviationLimit
        ) = unpackMpFees2(mpFees2);

        if (assetOutAddress != address(this)) {
            (,quantityOut, collectedCashbacksOut, targetShareOut) = unpackMpAsset(assets[assetOutAddress]);
            priceOut = prices[assetOutAddress].getPrice();
        }

        if (assetInAddress != address(this)) {
            (,quantityIn, collectedCashbacksIn, targetShareIn) = unpackMpAsset(assets[assetInAddress]);
            priceIn = prices[assetInAddress].getPrice();
        }

        (
            uint _managerEarnedFee,
            uint _oracleEarnedFee,
            uint _lpEarnedFee,
            uint _cashbacksRefund,

            uint _amountIn,
            uint _amountOut,

            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        ) = MpMath.calculateSwap(
            _totalSupply,
            totalTargetShares,
            deviationIncreaseFee,
            deviationLimit,
            feeToCashbackRatio,
            baseFee,
            lpFee,
            managerFee,

            quantityIn,
            collectedCashbacksIn,
            targetShareIn,

            quantityOut,
            collectedCashbacksOut,
            targetShareOut,

            assetInAddress == address(this),
            assetOutAddress == address(this),

            swapAmount,
            isExactInput,
            priceIn,
            priceOut,
            sharePrice
        );

        totalTargetShares = _totalTargetShares;
        deviationLimit = _deviationLimit;
        collectedManagerFee = _collectedManagementFee;
        collectedLpFee = _collectedLpFee;

        oracleAddress = _oracleAddress;

        managerEarnedFee = _managerEarnedFee;
        oracleEarnedFee = _oracleEarnedFee;
        lpEarnedFee = _lpEarnedFee;
        cashbacksRefund = _cashbacksRefund;

        amountIn = _amountIn;
        amountOut = _amountOut;

        quantityIn = newQuantityIn;
        collectedCashbacksIn = newCollectedCashbacksIn;

        quantityOut = newQuantityOut;
        collectedCashbacksOut = newCollectedCashbacksOut;
    }

}
