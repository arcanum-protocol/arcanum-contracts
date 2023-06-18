// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import { MpAsset, MpContext } from "../lib/multipool/MultipoolMath.sol";

import "hardhat/console.sol";

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
    SD59x18 public totalCurrentUsdAmount;
    SD59x18 public totalAssetPercents;

    SD59x18 public curveCoef;
    SD59x18 public deviationPercentLimit;

    SD59x18 public baseMintFee = sd(0.0001e18);
    SD59x18 public baseBurnFee = sd(0.0001e18); 
    SD59x18 public baseTradeFee = sd(0.00005e18); 
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

    function getContext(SD59x18  baseFee) public view returns (MpContext memory context) {
        context = MpContext({
            totalCurrentUsdAmount:  totalCurrentUsdAmount,
            totalAssetPercents:     totalAssetPercents,
            curveCoef:              curveCoef,
            deviationPercentLimit:  deviationPercentLimit,
            operationBaseFee:       baseMintFee,
            userCashbackBalance:    sd(0e18)
        });
    }

    function getTransferredAmount(
       MpAsset memory assetIn, 
       address _assetIn
    ) public view returns (uint amount) {
        amount = IERC20(_assetIn).balanceOf(address(this)) -
            uint(assetIn.quantity.unwrap()) -
            uint(assetIn.collectedFees.unwrap()) -
            uint(assetIn.collectedCashbacks.unwrap());
    }

    function shareToAmount(
        SD59x18 _share, 
        MpContext memory context, 
        MpAsset memory asset
    ) public view returns (SD59x18 _amount) {
        _amount = _share * context.totalCurrentUsdAmount 
            / sd(int(totalSupply())) / asset.price;
    }

    function mint(
        address _asset, 
        uint _share, 
        address _to
    ) public returns (uint) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseMintFee);

        uint transferredAmount = getTransferredAmount(asset, _asset);

        SD59x18 requiredShareBalance;
        if (totalSupply() != 0) {
            requiredShareBalance = shareToAmount(sd(int(_share)), context, asset);
        } else {
            requiredShareBalance = sd(int(transferredAmount));
        }

        uint requiredSuppliableQuantity = uint(context.mintRev(asset, requiredShareBalance).unwrap());
            //uint(MultipoolMath.reversedEvalMintContext(requiredShareBalance, context, asset).unwrap());

        require(requiredSuppliableQuantity <= transferredAmount, "provided amount exeeded");

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        uint refund = uint(SD59x18.unwrap(context.userCashbackBalance));

        // add unused quantity to refund
        refund += (transferredAmount - requiredSuppliableQuantity);

        _mint(_to, _share);
        assets[_asset] = asset;
        if (refund > 0) {
            IERC20(_asset).transfer(_to, refund);
        }

        emit AssetQuantityChange(_asset, uint(asset.quantity.unwrap()));
        return requiredSuppliableQuantity;
    }

    function burn(
        address _asset,
        uint _share,
        address _to
    ) public returns (uint) {
        MpAsset memory asset = assets[_asset];
        MpContext memory context = getContext(baseBurnFee);

        SD59x18 burnQuantity = shareToAmount(sd(int(_share)), context, asset);
        uint quantityOut = uint(context.burn(asset, burnQuantity).unwrap());

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        uint refund = uint(SD59x18.unwrap(context.userCashbackBalance));

       _burn(address(this), _share);
       assets[_asset] = asset;
       IERC20(_asset).transfer(_to, quantityOut + refund);
       // return unused amount
       _transfer(address(this), msg.sender, balanceOf(address(this)));

       emit AssetQuantityChange(_asset, uint(asset.quantity.unwrap()));
       return quantityOut;
   }


   function swap(
       address _assetIn,
       address _assetOut,
       uint _share,
       address _to
   ) public returns (uint _amountIn, uint _amountOut) {
        MpAsset memory assetIn = assets[_assetIn];
        MpAsset memory assetOut = assets[_assetOut];
        MpContext memory context = getContext(baseTradeFee);


        uint transferredAmount = getTransferredAmount(assetIn, _assetIn);
        uint refundAssetIn;
        uint refundAssetOut;

        {{
            SD59x18 assetInFromShares = shareToAmount(sd(int(_share)), context, assetIn);
            _amountIn = uint(context.mintRev(assetIn, assetInFromShares).unwrap());

            require(_amountIn <= transferredAmount, "MULTIPOOL: swap amount in exeeded");

            refundAssetIn = uint(SD59x18.unwrap(context.userCashbackBalance));
            refundAssetIn += (transferredAmount - _amountIn);
            context.userCashbackBalance = sd(0);
        }}

        {{
            SD59x18 assetOutFromShares = shareToAmount(sd(int(_share)), context, assetOut);
            _amountOut = uint(context.burn(assetOut, assetOutFromShares).unwrap());

            refundAssetOut = uint(SD59x18.unwrap(context.userCashbackBalance));
            totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        }}


       assets[_assetIn] = assetIn;
       assets[_assetOut] = assetOut;

       if (_amountOut + refundAssetOut > 0) {
            IERC20(_assetOut).transfer(_to, _amountOut + refundAssetOut);
       }
       if (refundAssetIn > 0) {
            IERC20(_assetIn).transfer(_to, refundAssetIn);
       }
       emit AssetQuantityChange(_assetIn, uint(assetIn.quantity.unwrap()));
       emit AssetQuantityChange(_assetOut, uint(assetOut.quantity.unwrap()));
   }

    /** ---------------- Owner ------------------ */

    function updatePrice(address _asset, uint _price) public onlyOwner {
        MpAsset memory asset = assets[_asset];
        SD59x18 price = sd(int(_price));
        totalCurrentUsdAmount = totalCurrentUsdAmount - asset.quantity * asset.price + asset.quantity * price;
        asset.price = price;
        assets[_asset] = asset;
        emit AssetPriceChange(_asset, _price);
    }

    function updateAssetPercents(
        address _asset,
        uint _percent
    ) public onlyOwner {
        MpAsset memory asset = assets[_asset];
        SD59x18 percent = sd(int(_percent));
        totalAssetPercents = totalAssetPercents - asset.percent + percent;
        asset.percent = percent;
        assets[_asset] = asset;
        emit AssetPercentsChange(_asset, _percent);
    }

    function setDeviationPercentLimit(uint _deviationPercentLimit) external onlyOwner {
        deviationPercentLimit = sd(int(_deviationPercentLimit));
    }

    function setCurveCoef(uint _curveCoef) external onlyOwner {
        curveCoef = sd(int(_curveCoef));
    }

    function setBaseTradeFee(uint _baseTradeFee) external onlyOwner {
        baseTradeFee = sd(int(_baseTradeFee));
    }

    function setBaseMintFee(uint _baseMintFee) external onlyOwner {
        baseMintFee = sd(int(_baseMintFee));
    }

    function setBaseBurnFee(uint _baseBurnFee) external onlyOwner {
        baseBurnFee = sd(int(_baseBurnFee));
    }
}
