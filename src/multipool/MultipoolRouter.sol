// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Multipool, MpAsset as UintMpAsset, MpContext as UintMpContext} from "./Multipool.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import {MpAsset, MpContext} from "./MpCommonMath.sol";
import {MpComplexMath} from "./MpComplexMath.sol";

uint constant DENOMINATOR = 1e18;

contract MultipoolRouter {
    using {
        MpComplexMath.mintRev,
        MpComplexMath.burnRev,
        MpComplexMath.mint,
        MpComplexMath.burn,
        MpComplexMath.burnTrace
    } for MpContext;

    modifier ensure(uint deadline) {
        require(deadline == 0 || deadline >= block.timestamp, "MULTIPOOL_ROUTER: DE");
        _;
    }

    constructor() {}

    function mintWithSharesOut(
        address poolAddress,
        address assetAddress,
        uint sharesOut,
        uint amountInMax,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amount, uint refund) {
        // Transfer all amount in in case the last part will return via multipool
        IERC20(assetAddress).transferFrom(msg.sender, poolAddress, amountInMax);
        // No need to check sleepage because contract will fail if there is no
        // enough funst been transfered
        return Multipool(poolAddress).mint(assetAddress, sharesOut, to);
    }

    function burnWithSharesIn(
        address poolAddress,
        address assetAddress,
        uint sharesIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amount, uint refund) {
        IERC20(poolAddress).transferFrom(msg.sender, poolAddress, sharesIn);
        (uint amountOut, uint _refund) = Multipool(poolAddress).burn(assetAddress, sharesIn, to);
        amount = amountOut;
        refund = _refund;

        require(amountOut >= amountOutMin, "MULTIPOOL_ROUTER: SE");
    }

    function swap(
        address poolAddress,
        address assetInAddress,
        address assetOutAddress,
        uint amountInMax,
        uint amountOutMin,
        uint shares,
        address to,
        uint deadline
    ) public ensure(deadline) {
        // Transfer all amount in in case the last part will return via multipool
        IERC20(poolAddress).transferFrom(msg.sender, poolAddress, amountInMax);
        // No need to check sleepage because contract will fail if there is no
        // enough funst been transfered
        (uint amountIn, uint amountOut,,) = Multipool(poolAddress).swap(assetInAddress, assetOutAddress, shares, to);
        require(amountOut >= amountOutMin, "MULTIPOOL_ROUTER: SE");
        require(amountIn <= amountInMax, "MULTIPOOL_ROUTER: SE");
    }

    function mintWithAmountIn(
        address poolAddress,
        address assetAddress,
        uint amountIn,
        uint sharesOutMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint shares, uint refund) {
        {
            {
                (MpContext memory context, MpAsset memory asset, uint totalSupply) =
                    Multipool(poolAddress).getMintData(assetAddress);
                uint oldUsdCap = context.usdCap;

                uint amountOut = context.mint(asset, amountIn);

                shares = (amountOut * asset.price * totalSupply) / DENOMINATOR / oldUsdCap;
                require(shares >= sharesOutMin, "MULTIPOOL_ROUTER: SE");
            }
        }

        IERC20(assetAddress).transferFrom(msg.sender, poolAddress, amountIn);
        (, uint _refund) = Multipool(poolAddress).mint(assetAddress, shares, to);
        refund = _refund;
    }

    function burnWithAmountOut(
        address poolAddress,
        address assetAddress,
        uint amountOut,
        uint sharesInMax,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint shares, uint refund) {
        {
            {
                (MpContext memory context, MpAsset memory asset, uint totalSupply) =
                    Multipool(poolAddress).getBurnData(assetAddress);
                uint oldUsdCap = context.usdCap;

                uint requiredAmountIn = context.burnRev(asset, amountOut);
                shares = requiredAmountIn * asset.price * totalSupply / DENOMINATOR / oldUsdCap;
                require(shares <= sharesInMax, "MULTIPOOL_ROUTER: SE");
            }
        }

        IERC20(poolAddress).transferFrom(msg.sender, poolAddress, shares);
        (, uint _refund) = Multipool(poolAddress).burn(assetAddress, shares, to);
        refund = _refund;
    }

    function swapWithAmountIn(
        address poolAddress,
        address assetInAddress,
        address assetOutAddress,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountOut, uint refundIn, uint refundOut) {
        uint shares;
        {
            {
                (MpContext memory context, MpAsset memory assetIn,, uint totalSupply) =
                    Multipool(poolAddress).getTradeData(assetInAddress, assetOutAddress);
                uint oldUsdCap = context.usdCap;

                uint mintAmountOut = context.mint(assetIn, amountIn);
                shares = mintAmountOut * assetIn.price * totalSupply / DENOMINATOR / oldUsdCap;
            }
        }

        IERC20(assetInAddress).transferFrom(msg.sender, poolAddress, amountIn);
        (, uint _amountOut, uint _refundIn, uint _refundOut) =
            Multipool(poolAddress).swap(assetInAddress, assetOutAddress, shares, to);

        require(_amountOut >= amountOutMin, "MULTIPOOL_ROUTER: SE");
        return (_amountOut, _refundIn, _refundOut);
    }

    function swapWithAmountOut(
        address poolAddress,
        address assetInAddress,
        address assetOutAddress,
        uint amountOut,
        uint amountInMax,
        address to,
        uint deadline
    ) public ensure(deadline) returns (uint amountIn, uint refundIn, uint refundOut) {
        uint shares;
        {
            {
                address assetInAddr = assetInAddress;
                address assetOutAddr = assetOutAddress;
                address poolAddr = poolAddress;
                uint _amountOut = amountOut;
                (MpContext memory context, MpAsset memory assetIn, MpAsset memory assetOut, uint totalSupply) =
                    Multipool(poolAddr).getTradeData(assetInAddr, assetOutAddr);
                uint oldUsdCap = context.usdCap;

                (uint burnAmountIn,,) = context.burnTrace(assetOut, assetIn.price, _amountOut);
                shares = (burnAmountIn * assetOut.price * totalSupply) / DENOMINATOR / oldUsdCap;
            }
        }

        IERC20(assetInAddress).transferFrom(msg.sender, poolAddress, amountInMax);
        (uint _amountIn,, uint _refundIn, uint _refundOut) =
            Multipool(poolAddress).swap(assetInAddress, assetOutAddress, shares, to);
        return (_amountIn, _refundIn, _refundOut);
    }

    function estimateMintSharesOut(address poolAddress, address assetAddress, uint amountIn)
        public
        view
        returns (uint sharesOut, uint fee, uint cashbackIn)
    {
        (MpContext memory context, MpAsset memory asset, uint totalSupply) =
            Multipool(poolAddress).getMintData(assetAddress);
        uint oldUsdCap = context.usdCap;

        uint amountOut = context.mint(asset, amountIn);

        require(oldUsdCap != 0, "MULTIPOOL_ROUTER: NS");
        sharesOut = (amountOut * asset.price * totalSupply) / DENOMINATOR / oldUsdCap;

        cashbackIn = context.userCashbackBalance;

        uint noFeeShareOut = (amountIn * asset.price * (totalSupply)) / DENOMINATOR / oldUsdCap;
        fee = noFeeShareOut * DENOMINATOR / sharesOut - 1e18;
    }

    function estimateMintAmountIn(address poolAddress, address assetAddress, uint sharesOut)
        public
        view
        returns (uint amountIn, uint fee, uint cashbackIn)
    {
        (MpContext memory context, MpAsset memory asset, uint totalSupply) =
            Multipool(poolAddress).getMintData(assetAddress);
        uint oldUsdCap = context.usdCap;

        require(totalSupply != 0, "MULTIPOOL_ROUTER: NS");
        uint _amountIn = (sharesOut * oldUsdCap) * DENOMINATOR / asset.price / totalSupply;

        amountIn = context.mintRev(asset, _amountIn);
        cashbackIn = context.userCashbackBalance;

        uint noFeeAmountIn = sharesOut * oldUsdCap * DENOMINATOR / asset.price / totalSupply;
        fee = noFeeAmountIn * DENOMINATOR / amountIn - 1e18;
    }

    function estimateBurnAmountOut(address poolAddress, address assetAddress, uint sharesIn)
        public
        view
        returns (uint amountOut, uint fee, uint cashbackOut)
    {
        (MpContext memory context, MpAsset memory asset, uint totalSupply) =
            Multipool(poolAddress).getBurnData(assetAddress);
        uint oldUsdCap = context.usdCap;

        uint amountIn = (sharesIn * oldUsdCap * DENOMINATOR) / asset.price / totalSupply;

        amountOut = context.burn(asset, amountIn);

        cashbackOut = context.userCashbackBalance;
        uint noFeeSharesIn = (amountOut * asset.price * (totalSupply)) / oldUsdCap / DENOMINATOR;
        fee = sharesIn * DENOMINATOR / noFeeSharesIn - 1e18;
    }

    function estimateBurnSharesIn(address poolAddress, address assetAddress, uint amountOut)
        public
        view
        returns (uint sharesIn, uint fee, uint cashbackOut)
    {
        (MpContext memory context, MpAsset memory asset, uint totalSupply) =
            Multipool(poolAddress).getBurnData(assetAddress);
        uint oldUsdCap = context.usdCap;

        uint amountIn = context.burnRev(asset, amountOut);

        sharesIn = (amountIn * asset.price * totalSupply) / DENOMINATOR / oldUsdCap;

        cashbackOut = context.userCashbackBalance;
        uint noFeeSharesIn = (amountOut * asset.price * (totalSupply)) / oldUsdCap / DENOMINATOR;
        fee = sharesIn * DENOMINATOR / noFeeSharesIn - 1e18;
    }

    function estimateSwapAmountOut(address poolAddress, address assetInAddress, address assetOutAddress, uint amountIn)
        public
        view
        returns (uint shares, uint amountOut, uint fee, uint cashbackIn, uint cashbackOut)
    {
        (MpContext memory context, MpAsset memory assetIn, MpAsset memory assetOut, uint totalSupply) =
            Multipool(poolAddress).getTradeData(assetInAddress, assetOutAddress);
        uint oldUsdCap = context.usdCap;

        uint mintAmountOut = context.mint(assetIn, amountIn);
        cashbackIn = context.userCashbackBalance;
        context.userCashbackBalance = 0;

        shares = (mintAmountOut * assetIn.price * totalSupply) / DENOMINATOR / oldUsdCap;

        uint burnAmountIn = (shares * context.usdCap) * DENOMINATOR / assetOut.price / (totalSupply + shares);

        amountOut = context.burn(assetOut, burnAmountIn);
        cashbackOut = context.userCashbackBalance;

        fee = amountIn * DENOMINATOR / ((amountOut * assetOut.price) / assetIn.price) - 1e18;
    }

    function estimateSwapAmountIn(address poolAddress, address assetInAddress, address assetOutAddress, uint amountOut)
        public
        view
        returns (uint shares, uint amountIn, uint fee, uint cashbackIn, uint cashbackOut)
    {
        (MpContext memory context, MpAsset memory assetIn, MpAsset memory assetOut, uint totalSupply) =
            Multipool(poolAddress).getTradeData(assetInAddress, assetOutAddress);
        uint oldUsdCap = context.usdCap;

        uint burnAmountIn;
        {
            {
                uint _amountOut = amountOut;
                (uint _burnAmountIn, uint burnCashback,) = context.burnTrace(assetOut, assetIn.price, _amountOut);
                cashbackOut = burnCashback;
                burnAmountIn = _burnAmountIn;
            }
        }

        {
            {
                shares = (burnAmountIn * assetOut.price * totalSupply) / DENOMINATOR / oldUsdCap;

                uint mintAmountOut = (shares * context.usdCap) * DENOMINATOR / assetIn.price / totalSupply;

                amountIn = context.mintRev(assetIn, mintAmountOut);
                cashbackIn = context.userCashbackBalance;
            }
        }

        uint amoutInNoFees = amountOut * assetOut.price /  assetIn.price;
        fee = amoutInNoFees * DENOMINATOR / amountIn - 1e18;
    }
}
