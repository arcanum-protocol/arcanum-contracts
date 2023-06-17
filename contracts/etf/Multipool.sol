// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "../lib/multipool/MultipoolMath.sol";

import "hardhat/console.sol";

contract Multipool is ERC20, Ownable {

    using MultipoolMath for *;

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

    mapping(address => MultipoolMath.Asset) public assets;
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

    function getAssets(address _asset) public view returns (MultipoolMath.Asset memory asset) {
        asset = assets[_asset];
    }

    function getMintContext() public view returns (MultipoolMath.Context memory context) {
        context = getContext(baseMintFee);
    }

    function getBurnContext() public view returns (MultipoolMath.Context memory context) {
        context = getContext(baseBurnFee);
    }

    function getTradeContext() public view returns (MultipoolMath.Context memory context) {
        context = getContext(baseTradeFee);
    }

    function getContext(SD59x18  baseFee) public view returns (MultipoolMath.Context memory context) {
        context = MultipoolMath.Context({
            totalCurrentUsdAmount:  totalCurrentUsdAmount,
            totalAssetPercents:     totalAssetPercents,
            curveCoef:              curveCoef,
            deviationPercentLimit:  deviationPercentLimit,
            operationBaseFee:       baseMintFee,
            userCashbackBalance:    sd(0e18)
        });
    }

    //TODO: return unused supplied amount with refund
    function mint(address _asset, uint _share, address _to) public returns (uint) {
        MultipoolMath.Asset memory asset = assets[_asset];
        MultipoolMath.Context memory context = getContext(baseMintFee);

        SD59x18 suppliableBalance = sd(int(IERC20(_asset).balanceOf(address(this)))) -
            asset.quantity -
            asset.collectedFees -
            asset.collectedCashbacks;

        SD59x18 requiredShareBalance;
        if (totalSupply() != 0) {
            requiredShareBalance = sd(int(_share)) * totalCurrentUsdAmount
                / sd(int(totalSupply())) / asset.price;
        } else {
            requiredShareBalance = suppliableBalance;
        }

        uint requiredSuppliableQuantity = 
            uint(MultipoolMath.reversedEvalMintContext(requiredShareBalance, context, asset).unwrap());

        console.log("req ", requiredSuppliableQuantity);
        console.log("sup ", uint(suppliableBalance.unwrap()));
        require(requiredSuppliableQuantity <= uint(suppliableBalance.unwrap()), "provided amount exeeded");

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        uint refund = uint(SD59x18.unwrap(context.userCashbackBalance));

        _mint(_to, _share);
        assets[_asset] = asset;
        IERC20(_asset).transfer(_to, refund);

        emit AssetQuantityChange(_asset, uint(asset.quantity.unwrap()));
        return requiredSuppliableQuantity;
    }

    function burn(
        address _asset,
        uint _share,
        address _to
    ) public returns (uint) {
        MultipoolMath.Asset memory asset = assets[_asset];
        MultipoolMath.Context memory context = getContext(baseBurnFee);

        SD59x18 burnQuantity = sd(int(_share)) * totalCurrentUsdAmount 
            / sd(int(totalSupply())) / asset.price;
        uint quantityOut = uint(MultipoolMath.evalBurnContext(burnQuantity, context, asset).unwrap());

        totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        uint refund = uint(SD59x18.unwrap(context.userCashbackBalance));

       _burn(address(this), _share);
       assets[_asset] = asset;
       IERC20(_asset).transfer(_to, quantityOut + refund);

       emit AssetQuantityChange(_asset, uint(asset.quantity.unwrap()));
       return quantityOut;
   }

   function getTransferredAmount(
       MultipoolMath.Asset memory assetIn, 
       address _assetIn
   ) public view returns (uint amount) {
        amount = IERC20(_assetIn).balanceOf(address(this)) -
            uint(assetIn.quantity.unwrap()) -
            uint(assetIn.collectedFees.unwrap()) -
            uint(assetIn.collectedCashbacks.unwrap());
   }

   function swap(
       address _assetIn,
       address _assetOut,
       uint _shareInTheMiddle,
       address _to
   ) public returns (uint) {
        MultipoolMath.Asset memory assetIn = assets[_assetIn];
        MultipoolMath.Asset memory assetOut = assets[_assetOut];
        MultipoolMath.Context memory context = getContext(baseTradeFee);


        uint transferredAmount = getTransferredAmount(assetIn, _assetIn);
        uint refundAssetIn;
        uint refundAssetOut;
        uint burnQuantityOut;

        {{
            SD59x18 assetInFromShares = sd(int(_shareInTheMiddle)) * totalCurrentUsdAmount
                / sd(int(totalSupply())) / assetIn.price;
            SD59x18 mintQuantityIn = 
                MultipoolMath.reversedEvalMintContext(assetInFromShares, context, assetIn);

            require(mintQuantityIn <= sd(int(transferredAmount)), 
                    "MULTIPOOL: swap amount in exeeded");

            refundAssetIn = uint(SD59x18.unwrap(context.userCashbackBalance));
            context.userCashbackBalance = sd(0);
        }}

        {{
            SD59x18 assetOutFromShares = sd(int(_shareInTheMiddle)) * totalCurrentUsdAmount
                / sd(int(totalSupply())) / assetIn.price;

            burnQuantityOut = 
                uint(MultipoolMath.evalBurnContext(assetOutFromShares , context, assetOut).unwrap());

            refundAssetOut = uint(SD59x18.unwrap(context.userCashbackBalance));
            totalCurrentUsdAmount = context.totalCurrentUsdAmount;
        }}

       assets[_assetIn] = assetIn;
       assets[_assetOut] = assetOut;
       if (burnQuantityOut + refundAssetOut > 0) {
            IERC20(_assetOut).transfer(_to, burnQuantityOut + refundAssetOut);
       }
       if (refundAssetIn > 0) {
            IERC20(_assetIn).transfer(_to, refundAssetIn);
       }
       emit AssetQuantityChange(_assetIn, uint(assetIn.quantity.unwrap()));
       emit AssetQuantityChange(_assetOut, uint(assetOut.quantity.unwrap()));
       return burnQuantityOut;
   }

    /** ---------------- Owner ------------------ */

    function updatePrice(address _asset, uint _price) public onlyOwner {
        MultipoolMath.Asset memory asset = assets[_asset];
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
        MultipoolMath.Asset memory asset = assets[_asset];
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
