// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { MpAsset, MpContext } from "../lib/multipool/MultipoolMath.sol";

import "hardhat/console.sol";

contract Multipool is ERC20, Ownable {

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        feeReceiver = msg.sender;
    }

    event AssetPercentsChange(address indexed asset, UD60x18 percent);
    event AssetQuantityChange(address indexed asset, UD60x18 quantity);
    event AssetPriceChange(address indexed asset, UD60x18 price);

    /** ---------------- Variables ------------------ */

    mapping(address => MpAsset) public assets;
    UD60x18 public totalCurrentUsdAmount;
    UD60x18 public totalAssetPercents;

    UD60x18 public curveCoef;
    UD60x18 public deviationPercentLimit;

    UD60x18 public baseMintFee = ud(0.0001e18);
    UD60x18 public baseBurnFee = ud(0.0001e18); 
    UD60x18 public baseTradeFee = ud(0.00005e18); 
    uint public denominator = 1e18;

    mapping(address => uint) public transferFees;
    address public feeReceiver;

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount); // Call parent hook
        uint transferFee = transferFees[to];
        if (transferFee != 0) {
            _transfer(to, feeReceiver, (amount * transferFee) / denominator);
        }
    }

    function getAssets(address _asset) public view returns (MpAsset memory asset) {
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

    function getContext(UD60x18  baseFee) public view returns (MpContext memory context) {
        context = MpContext({
            totalCurrentUsdAmount:  totalCurrentUsdAmount,
            totalAssetPercents:     totalAssetPercents,
            curveCoef:              curveCoef,
            deviationPercentLimit:  deviationPercentLimit,
            operationBaseFee:       baseMintFee,
            userCashbackBalance:    ud(0e18)
        });
    }

    function getTransferredAmount(
       MpAsset memory assetIn, 
       address _assetIn
    ) public view returns (UD60x18 amount) {
        amount = ud(IERC20(_assetIn).balanceOf(address(this))) -
            assetIn.quantity -
            assetIn.collectedFees -
            assetIn.collectedCashbacks;
    }

    function shareToAmount(
        UD60x18 _share, 
        MpContext memory context, 
        MpAsset memory asset
    ) public view returns (UD60x18 _amount) {
        _amount = _share * context.totalCurrentUsdAmount 
            / ud(totalSupply()) / asset.price;
    }

    function mint(
        address _asset, 
        UD60x18 _share, 
        address _to
    ) public returns (UD60x18 _amountIn) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseMintFee);

        UD60x18 transferredAmount = getTransferredAmount(asset, _asset);

        UD60x18 amountOut;
        if (totalSupply() != 0) {
            amountOut = shareToAmount(_share, context, asset);
        } else {
            amountOut = transferredAmount;
        }

        _amountIn = context.mintRev(asset, amountOut);
        require(_amountIn <= transferredAmount, "MULTIPOOL: mint amount in exeeded");

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        // add unused quantity to refund
        UD60x18 refund = context.userCashbackBalance + (transferredAmount - _amountIn);

        _mint(_to, _share.unwrap());
        assets[_asset] = asset;
        if (refund > ud(0)) {
            IERC20(_asset).transfer(_to, refund.unwrap());
        }

        emit AssetQuantityChange(_asset, asset.quantity);
    }

    function burn(
        address _asset,
        UD60x18 _share,
        address _to
    ) public returns (UD60x18 _amountOut) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseBurnFee);

        UD60x18 amountIn = shareToAmount(_share, context, asset);
        _amountOut = context.burn(asset, amountIn);

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        UD60x18 refund = context.userCashbackBalance;

       _burn(address(this), _share.unwrap());
       assets[_asset] = asset;
       IERC20(_asset).transfer(_to, (_amountOut + refund).unwrap());
       // return unused amount
       _transfer(address(this), msg.sender, balanceOf(address(this)));
       emit AssetQuantityChange(_asset, asset.quantity);
   }


   function swap(
       address _assetIn,
       address _assetOut,
       UD60x18 _share,
       address _to
   ) public returns (UD60x18 _amountIn, UD60x18 _amountOut) {
        MpAsset memory assetIn = assets[_assetIn];
        MpAsset memory assetOut = assets[_assetOut];
        MpContext memory context = getContext(baseTradeFee);


        UD60x18 transferredAmount = getTransferredAmount(assetIn, _assetIn);
        UD60x18 refundAssetIn;
        UD60x18 refundAssetOut;

        {{
            UD60x18 amountOut = shareToAmount(_share, context, assetIn);
            _amountIn = context.mintRev(assetIn, amountOut);
            require(_amountIn <= transferredAmount, "MULTIPOOL: swap amount in exeeded");

            refundAssetIn = context.userCashbackBalance + (transferredAmount - _amountIn);
            context.userCashbackBalance = ud(0);
        }}

        {{
            UD60x18 amountIn = shareToAmount(_share, context, assetOut);
            _amountOut = context.burn(assetOut, amountIn);

            refundAssetOut = context.userCashbackBalance;
            totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        }}


       assets[_assetIn] = assetIn;
       assets[_assetOut] = assetOut;

       if (_amountOut + refundAssetOut > ud(0)) {
            IERC20(_assetOut).transfer(_to, (_amountOut + refundAssetOut).unwrap());
       }
       if (refundAssetIn > ud(0)) {
            IERC20(_assetIn).transfer(_to, refundAssetIn.unwrap());
       }
       emit AssetQuantityChange(_assetIn, assetIn.quantity);
       emit AssetQuantityChange(_assetOut, assetOut.quantity);
   }

    /** ---------------- Owner ------------------ */

    function updatePrice(address _asset, UD60x18 _price) public onlyOwner {
        MpAsset memory asset = assets[_asset];
        totalCurrentUsdAmount = totalCurrentUsdAmount - asset.quantity * asset.price + asset.quantity * _price;
        asset.price = _price;
        assets[_asset] = asset;
        emit AssetPriceChange(_asset, _price);
    }

    function updateAssetPercents(
        address _asset,
        UD60x18 _percent
    ) public onlyOwner {
        MpAsset memory asset = assets[_asset];
        totalAssetPercents = totalAssetPercents - asset.percent + _percent;
        asset.percent = _percent;
        assets[_asset] = asset;
        emit AssetPercentsChange(_asset, _percent);
    }

    function setDeviationPercentLimit(UD60x18 _deviationPercentLimit) external onlyOwner {
        deviationPercentLimit = _deviationPercentLimit;
    }

    function setCurveCoef(UD60x18 _curveCoef) external onlyOwner {
        curveCoef = _curveCoef;
    }

    function setBaseTradeFee(UD60x18 _baseTradeFee) external onlyOwner {
        baseTradeFee = _baseTradeFee;
    }

    function setBaseMintFee(UD60x18 _baseMintFee) external onlyOwner {
        baseMintFee = _baseMintFee;
    }

    function setBaseBurnFee(UD60x18 _baseBurnFee) external onlyOwner {
        baseBurnFee = _baseBurnFee;
    }
}
