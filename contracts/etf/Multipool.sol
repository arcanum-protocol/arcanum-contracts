// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

struct MpAsset {
    uint quantity;
    uint price;
    uint collectedFees;
    uint collectedCashbacks;
    uint percent;
}

struct MpContext {
    uint totalCurrentUsdAmount;
    uint totalAssetPercents;
    uint halfDeviationFeeRatio;
    uint deviationPercentLimit;
    uint operationBaseFee;
    uint userCashbackBalance;
    uint depegBaseFeeRatio;
}

contract Multipool is ERC20, Ownable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        priceSource = msg.sender;
        percentsSource = msg.sender;
    }

    event AssetPercentsChange(address indexed asset, uint percent);
    event AssetQuantityChange(address indexed asset, uint quantity);
    event AssetPriceChange(address indexed asset, uint price);
    event WithdrawCollectedFees(address indexed asset, uint value);

    event HalfDeviationFeeRatioChange(uint value);
    event DeviationPercentLimitChange(uint value);
    event PercentsSourceChange(address percentsSource);
    event PriceSourceChange(address priceSource);
    event BaseMintFeeChange(uint value);
    event BaseBurnFeeChange(uint value);
    event BaseTradeFeeChange(uint value);
    event DepegBaseFeeRatioChange(uint value);

    /** ---------------- Variables ------------------ */

    mapping(address => MpAsset) public assets;
    uint public totalCurrentUsdAmount;
    uint public totalAssetPercents;

    uint public halfDeviationFeeRatio;
    uint public deviationPercentLimit;
    uint public depegBaseFeeRatio;

    uint public baseMintFee;
    uint public baseBurnFee;
    uint public baseTradeFee;
    uint public constant DENOMINATOR = 1e18;

    address public feeReceiver;
    address public priceSource;
    address public percentsSource;

    function getAssets(
        address _asset
    ) public view returns (MpAsset memory asset) {
        asset = assets[_asset];
    }

    function getMintContext() public view returns (MpContext memory context) {
        context = getContext(baseMintFee);
    }

    function getBurnContext() public view returns (MpContext memory context) {
        context = getContext(baseBurnFee);
    }

    function getTradeContext() public view returns (MpContext memory context) {
        context = getContext(baseTradeFee);
    }

    function getContext(
        uint baseFee
    ) public view returns (MpContext memory context) {
        context = MpContext({
            totalCurrentUsdAmount: totalCurrentUsdAmount,
            totalAssetPercents: totalAssetPercents,
            halfDeviationFeeRatio: halfDeviationFeeRatio,
            deviationPercentLimit: deviationPercentLimit,
            operationBaseFee: baseFee,
            userCashbackBalance: 0e18,
            depegBaseFeeRatio: depegBaseFeeRatio
        });
    }

    function getTransferredAmount(
        MpAsset memory assetIn,
        address _assetIn
    ) public view returns (uint amount) {
        amount =
            IERC20(_assetIn).balanceOf(address(this)) -
            assetIn.quantity -
            assetIn.collectedFees -
            assetIn.collectedCashbacks;
    }

    function shareToAmount(
        uint _share,
        MpContext memory context,
        MpAsset memory asset,
        uint virtualShare
    ) public view returns (uint _amount) {
        _amount =
            (_share * context.totalCurrentUsdAmount * DENOMINATOR) /
            (totalSupply() + virtualShare) /
            asset.price;
    }

    function evalMint(
        MpContext memory context,
        MpAsset memory asset,
        uint utilisableQuantity
    ) internal pure returns (uint suppliedQuantity) {
        if (context.totalCurrentUsdAmount == 0) {
            context.totalCurrentUsdAmount =
                (utilisableQuantity * asset.price) /
                DENOMINATOR;
            asset.quantity += utilisableQuantity;
            return utilisableQuantity;
        }

        uint shareOld = (asset.quantity * asset.price) /
            context.totalCurrentUsdAmount;
        uint shareNew = ((asset.quantity + utilisableQuantity) * asset.price) /
            (context.totalCurrentUsdAmount +
                (utilisableQuantity * asset.price) /
                DENOMINATOR);
        uint idealShare = (asset.percent * DENOMINATOR) /
            context.totalAssetPercents;
        uint deviationNew = shareNew > idealShare
            ? shareNew - idealShare
            : idealShare - shareNew;
        uint deviationOld = shareOld > idealShare
            ? shareOld - idealShare
            : idealShare - shareOld;

        if (deviationNew <= deviationOld) {
            if (deviationOld != 0) {
                uint cashback = (asset.collectedCashbacks *
                    (deviationOld - deviationNew)) / deviationOld;
                asset.collectedCashbacks -= cashback;
                context.userCashbackBalance += cashback;
            }
            suppliedQuantity =
                (utilisableQuantity * (1e18 + context.operationBaseFee)) /
                DENOMINATOR;
        } else {
            require(
                deviationNew < context.deviationPercentLimit,
                "MULTIPOOL: deviation overflow"
            );
            uint depegFee = (context.halfDeviationFeeRatio *
                deviationNew *
                utilisableQuantity) /
                context.deviationPercentLimit /
                (context.deviationPercentLimit - deviationNew);
            uint deviationBaseFee = (context.depegBaseFeeRatio * depegFee) /
                DENOMINATOR;
            asset.collectedCashbacks += depegFee - deviationBaseFee;
            asset.collectedFees += deviationBaseFee;
            suppliedQuantity = ((utilisableQuantity *
                (1e18 + context.operationBaseFee)) /
                DENOMINATOR +
                depegFee);
        }

        asset.quantity += utilisableQuantity;
        context.totalCurrentUsdAmount +=
            (utilisableQuantity * asset.price) /
            DENOMINATOR;
        asset.collectedFees +=
            (utilisableQuantity * context.operationBaseFee) /
            DENOMINATOR;
    }

    function evalBurn(
        MpContext memory context,
        MpAsset memory asset,
        uint suppliedQuantity
    ) internal pure returns (uint utilisableQuantity) {
        require(
            suppliedQuantity <= asset.quantity,
            "MULTIPOOL: asset quantity exceeded"
        );

        if (
            context.totalCurrentUsdAmount -
                (suppliedQuantity * asset.price) /
                DENOMINATOR !=
            0
        ) {
            uint shareOld = (asset.quantity * asset.price) /
                context.totalCurrentUsdAmount;
            uint shareNew = ((asset.quantity - suppliedQuantity) *
                asset.price) /
                (context.totalCurrentUsdAmount -
                    (suppliedQuantity * asset.price) /
                    DENOMINATOR);
            uint idealShare = (asset.percent * DENOMINATOR) /
                context.totalAssetPercents;
            uint deviationNew = shareNew > idealShare
                ? shareNew - idealShare
                : idealShare - shareNew;
            uint deviationOld = shareOld > idealShare
                ? shareOld - idealShare
                : idealShare - shareOld;

            if (deviationNew <= deviationOld) {
                if (deviationOld != 0) {
                    uint cashback = (asset.collectedCashbacks *
                        (deviationOld - deviationNew)) / deviationOld;
                    asset.collectedCashbacks -= cashback;
                    context.userCashbackBalance += cashback;
                }
                utilisableQuantity =
                    (suppliedQuantity * DENOMINATOR) /
                    (1e18 + context.operationBaseFee);
            } else {
                require(
                    deviationNew < context.deviationPercentLimit,
                    "MULTIPOOL: deviation overflow"
                );
                uint feeRatio = (context.halfDeviationFeeRatio *
                    deviationNew *
                    DENOMINATOR) /
                    context.deviationPercentLimit /
                    (context.deviationPercentLimit - deviationNew);
                utilisableQuantity =
                    (suppliedQuantity * DENOMINATOR) /
                    (1e18 + feeRatio + context.operationBaseFee);

                uint depegFee = suppliedQuantity -
                    (utilisableQuantity * (1e18 + context.operationBaseFee)) /
                    DENOMINATOR;
                uint deviationBaseFee = (context.depegBaseFeeRatio * depegFee) /
                    DENOMINATOR;
                asset.collectedCashbacks += depegFee - deviationBaseFee;
                asset.collectedFees += deviationBaseFee;
            }
        } else {
            utilisableQuantity =
                (suppliedQuantity * DENOMINATOR) /
                (1e18 + context.operationBaseFee);
        }

        asset.quantity -= suppliedQuantity;
        context.totalCurrentUsdAmount -=
            (suppliedQuantity * asset.price) /
            DENOMINATOR;
        asset.collectedFees +=
            (utilisableQuantity * context.operationBaseFee) /
            DENOMINATOR;
    }

    function mint(
        address _asset,
        uint _share,
        address _to
    ) public returns (uint _amountIn, uint refund) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseMintFee);

        uint transferredAmount = getTransferredAmount(asset, _asset);
        uint amountOut = totalSupply() != 0
            ? shareToAmount(_share, context, asset, 0)
            : transferredAmount;

        _amountIn = evalMint(context, asset, amountOut);
        require(
            _amountIn <= transferredAmount,
            "MULTIPOOL: mint amount in exeeded"
        );

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        // add unused quantity to refund
        refund = context.userCashbackBalance;
        uint returnAmount = (transferredAmount - _amountIn) + refund;

        _mint(_to, _share);
        assets[_asset] = asset;
        if (returnAmount > 0) {
            IERC20(_asset).transfer(_to, returnAmount);
        }
        emit AssetQuantityChange(_asset, asset.quantity);
    }

    // share here needs to be specified and can't be taken by balance of because
    // if there is too much share you will be frozen by deviaiton limit overflow
    function burn(
        address _asset,
        uint _share,
        address _to
    ) public returns (uint _amountOut, uint refund) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseBurnFee);

        uint amountIn = shareToAmount(_share, context, asset, 0);
        _amountOut = evalBurn(context, asset, amountIn);

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        refund = context.userCashbackBalance;

        _burn(address(this), _share);
        assets[_asset] = asset;
        IERC20(_asset).transfer(_to, _amountOut + refund);
        _transfer(address(this), _to, balanceOf(address(this)));
        emit AssetQuantityChange(_asset, asset.quantity);
    }

    function swap(
        address _assetIn,
        address _assetOut,
        uint _share,
        address _to
    )
        public
        returns (uint _amountIn, uint _amountOut, uint refundIn, uint refundOut)
    {
        require(_assetIn != _assetOut, "MULTIPOOL: same assets");
        MpAsset memory assetIn = assets[_assetIn];
        MpAsset memory assetOut = assets[_assetOut];
        MpContext memory context = getContext(baseTradeFee);

        uint transferredAmount = getTransferredAmount(assetIn, _assetIn);
        {
            {
                uint amountOut = shareToAmount(_share, context, assetIn, 0);
                _amountIn = evalMint(context, assetIn, amountOut);
                require(
                    _amountIn <= transferredAmount,
                    "MULTIPOOL: amount in exeeded"
                );

                refundIn = context.userCashbackBalance;
                context.userCashbackBalance = 0;
            }
        }

        {
            {
                uint amountIn = shareToAmount(
                    _share,
                    context,
                    assetOut,
                    _share
                );
                _amountOut = evalBurn(context, assetOut, amountIn);

                refundOut = context.userCashbackBalance;
                totalCurrentUsdAmount = context.totalCurrentUsdAmount;
            }
        }

        assets[_assetIn] = assetIn;
        assets[_assetOut] = assetOut;

        if (_amountOut + refundOut > 0) {
            IERC20(_assetOut).transfer(_to, (_amountOut + refundOut));
        }
        if (refundIn + (transferredAmount - _amountIn) > 0) {
            IERC20(_assetIn).transfer(
                _to,
                refundIn + (transferredAmount - _amountIn)
            );
        }
        emit AssetQuantityChange(_assetIn, assetIn.quantity);
        emit AssetQuantityChange(_assetOut, assetOut.quantity);
    }

    /** ---------------- Owner ------------------ */

    function updatePrice(address _asset, uint _price) public {
        require(priceSource == msg.sender, "MULTIPOOL: only price setter");
        MpAsset memory asset = assets[_asset];
        totalCurrentUsdAmount =
            totalCurrentUsdAmount -
            (asset.quantity * asset.price) /
            DENOMINATOR +
            (asset.quantity * _price) /
            DENOMINATOR;
        asset.price = _price;
        assets[_asset] = asset;
        emit AssetPriceChange(_asset, _price);
    }

    function updateAssetPercents(address _asset, uint _percent) public {
        require(
            percentsSource == msg.sender,
            "MULTIPOOL: only percents setter"
        );
        MpAsset memory asset = assets[_asset];
        totalAssetPercents = totalAssetPercents - asset.percent + _percent;
        asset.percent = _percent;
        assets[_asset] = asset;
        emit AssetPercentsChange(_asset, _percent);
    }

    function setDeviationPercentLimit(
        uint _deviationPercentLimit
    ) external onlyOwner {
        deviationPercentLimit = _deviationPercentLimit;
        emit DeviationPercentLimitChange(_deviationPercentLimit);
    }

    function setHalfDeviationFeeRatio(
        uint _halfDeviationFeeRatio
    ) external onlyOwner {
        halfDeviationFeeRatio = _halfDeviationFeeRatio;
        emit HalfDeviationFeeRatioChange(_halfDeviationFeeRatio);
    }

    function setBaseTradeFee(uint _baseTradeFee) external onlyOwner {
        baseTradeFee = _baseTradeFee;
        emit BaseTradeFeeChange(_baseTradeFee);
    }

    function setBaseMintFee(uint _baseMintFee) external onlyOwner {
        baseMintFee = _baseMintFee;
        emit BaseMintFeeChange(_baseMintFee);
    }

    function setDepegBaseFeeRatio(uint _depegBaseFeeRatio) external onlyOwner {
        depegBaseFeeRatio = _depegBaseFeeRatio;
        emit DepegBaseFeeRatioChange(_depegBaseFeeRatio);
    }

    function setBaseBurnFee(uint _baseBurnFee) external onlyOwner {
        baseBurnFee = _baseBurnFee;
        emit BaseBurnFeeChange(_baseBurnFee);
    }

    function setPriceSource(address _priceSource) external onlyOwner {
        priceSource = _priceSource;
        emit PriceSourceChange(_priceSource);
    }

    function setPercentsSource(address _percentsSource) external onlyOwner {
        percentsSource = _percentsSource;
        emit PercentsSourceChange(_percentsSource);
    }

    function withdrawCollectedFees(
        address _assetAddress,
        address _to
    ) external onlyOwner {
        MpAsset storage asset = assets[_assetAddress];
        uint fees = asset.collectedFees;
        asset.collectedFees = 0;
        IERC20(_assetAddress).transfer(_to, fees);
        emit WithdrawCollectedFees(_assetAddress, fees);
    }
}
