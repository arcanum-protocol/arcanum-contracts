// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
    uint curveCoef;
    uint deviationPercentLimit;
    uint operationBaseFee;
    uint userCashbackBalance;
}

contract Multipool is ERC20, Ownable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        feeReceiver = msg.sender;
    }

    event AssetPercentsChange(address indexed asset, uint percent);
    event AssetQuantityChange(address indexed asset, uint quantity);
    event AssetPriceChange(address indexed asset, uint price);

    /** ---------------- Variables ------------------ */

    mapping(address => MpAsset) public assets;
    uint public totalCurrentUsdAmount;
    uint public totalAssetPercents;

    uint public curveCoef = 0.0003e18;
    uint public deviationPercentLimit = 0.1e18;

    uint public baseMintFee = 0.0001e18;
    uint public baseBurnFee = 0.0001e18;
    uint public baseTradeFee = 0.00005e18;
    uint public constant DENOMINATOR = 1e18;

    mapping(address => uint) public transferFees;
    address public feeReceiver;

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
            curveCoef: curveCoef,
            deviationPercentLimit: deviationPercentLimit,
            operationBaseFee: baseFee,
            userCashbackBalance: 0e18
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
        MpAsset memory asset
    ) public view returns (uint _amount) {
        _amount =
            (_share * context.totalCurrentUsdAmount * DENOMINATOR) /
            totalSupply() /
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

        uint shareOld = (asset.quantity * asset.price * DENOMINATOR) /
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
            uint depegFee = (context.curveCoef *
                deviationNew *
                utilisableQuantity) /
                context.deviationPercentLimit /
                (context.deviationPercentLimit - deviationNew);
            asset.collectedCashbacks += depegFee;
            suppliedQuantity =
                (utilisableQuantity *
                    (1e18 + context.operationBaseFee) +
                    depegFee) /
                DENOMINATOR;
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

        uint shareOld = (asset.quantity * asset.price * DENOMINATOR) /
            context.totalCurrentUsdAmount;
        uint shareNew = ((asset.quantity - suppliedQuantity) * asset.price) /
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
            uint feeRatio = (context.curveCoef * deviationNew * DENOMINATOR) /
                context.deviationPercentLimit /
                (context.deviationPercentLimit - deviationNew);
            utilisableQuantity =
                (suppliedQuantity * DENOMINATOR) /
                (1e18 + feeRatio + context.operationBaseFee);
            asset.collectedCashbacks +=
                suppliedQuantity -
                (utilisableQuantity * (1e18 + context.operationBaseFee)) /
                DENOMINATOR;
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
    ) public returns (uint _amountIn) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseMintFee);

        uint transferredAmount = getTransferredAmount(asset, _asset);
        uint amountOut = totalSupply() != 0
            ? shareToAmount(_share, context, asset)
            : transferredAmount;

        _amountIn = evalMint(context, asset, amountOut);
        require(
            _amountIn <= transferredAmount,
            "MULTIPOOL: mint amount in exeeded"
        );

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        // add unused quantity to refund
        uint refund = context.userCashbackBalance +
            (transferredAmount - _amountIn);

        _mint(_to, _share);
        assets[_asset] = asset;
        if (refund > 0) {
            IERC20(_asset).transfer(_to, refund);
        }
        emit AssetQuantityChange(_asset, asset.quantity);
    }

    function burn(
        address _asset,
        uint _share,
        address _to
    ) public returns (uint _amountOut) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseBurnFee);

        uint amountIn = shareToAmount(_share, context, asset);
        _amountOut = evalBurn(context, asset, amountIn);

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        uint refund = context.userCashbackBalance;

        _burn(address(this), _share);
        assets[_asset] = asset;
        IERC20(_asset).transfer(_to, _amountOut + refund);
        // return unused amount
        _transfer(address(this), msg.sender, balanceOf(address(this)));
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
        MpAsset memory assetIn = assets[_assetIn];
        MpAsset memory assetOut = assets[_assetOut];
        MpContext memory context = getContext(baseTradeFee);

        uint transferredAmount = getTransferredAmount(assetIn, _assetIn);
        {
            {
                uint amountOut = shareToAmount(_share, context, assetIn);
                _amountIn = evalMint(context, assetIn, amountOut);
                require(
                    _amountIn <= transferredAmount,
                    "MULTIPOOL: amount in exeeded"
                );

                refundIn =
                    context.userCashbackBalance +
                    (transferredAmount - _amountIn);
                context.userCashbackBalance = 0;
            }
        }

        {
            {
                uint amountIn = shareToAmount(_share, context, assetOut);
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
        if (refundIn > 0) {
            IERC20(_assetIn).transfer(_to, refundIn);
        }
        emit AssetQuantityChange(_assetIn, assetIn.quantity);
        emit AssetQuantityChange(_assetOut, assetOut.quantity);
    }

    /** ---------------- Owner ------------------ */

    function updatePrice(address _asset, uint _price) public onlyOwner {
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

    function updateAssetPercents(
        address _asset,
        uint _percent
    ) public onlyOwner {
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
    }

    function setCurveCoef(uint _curveCoef) external onlyOwner {
        curveCoef = _curveCoef;
    }

    function setBaseTradeFee(uint _baseTradeFee) external onlyOwner {
        baseTradeFee = _baseTradeFee;
    }

    function setBaseMintFee(uint _baseMintFee) external onlyOwner {
        baseMintFee = _baseMintFee;
    }

    function setBaseBurnFee(uint _baseBurnFee) external onlyOwner {
        baseBurnFee = _baseBurnFee;
    }
}
