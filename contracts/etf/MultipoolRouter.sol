// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Multipool, MpAsset as UintMpAsset, MpContext as UintMpContext} from "./Multipool.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import {MpAsset, MpContext} from "../lib/multipool/MultipoolMath.sol";

import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract MultipoolRouter {
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "Multipool Router: EXPIRED");
        _;
    }

    constructor() {}

    function convertContext(
        UintMpContext memory ctx
    ) internal pure returns (MpContext memory context) {
        context.totalCurrentUsdAmount = ud(ctx.totalCurrentUsdAmount);
        context.totalAssetPercents = ud(ctx.totalAssetPercents);
        context.curveCoef = ud(ctx.halfDeviationFeeRatio);
        context.deviationPercentLimit = ud(ctx.deviationPercentLimit);
        context.operationBaseFee = ud(ctx.operationBaseFee);
        context.userCashbackBalance = ud(ctx.userCashbackBalance);
    }

    function convertAsset(
        UintMpAsset memory _asset
    ) internal pure returns (MpAsset memory asset) {
        asset.quantity = ud(_asset.quantity);
        asset.price = ud(_asset.price);
        asset.collectedFees = ud(_asset.collectedFees);
        asset.collectedCashbacks = ud(_asset.collectedCashbacks);
        asset.percent = ud(_asset.percent);
    }

    function mintWithSharesOut(
        address _pool,
        address _asset,
        UD60x18 _sharesOut,
        uint _amountInMax,
        address _to,
        uint deadline
    ) public ensure(deadline) {
        // Transfer all amount in in case the last part will return via multipool
        IERC20(_asset).transferFrom(msg.sender, _pool, _amountInMax);
        // No need to check sleepage because contract will fail if there is no
        // enough funst been transfered
        Multipool(_pool).mint(_asset, _sharesOut.unwrap(), _to);
    }

    function burnWithSharesIn(
        address _pool,
        address _asset,
        UD60x18 _sharesIn,
        UD60x18 _amountOutMin,
        address _to,
        uint deadline
    ) public ensure(deadline) {
        IERC20(_pool).transferFrom(msg.sender, _pool, _sharesIn.unwrap());
        (uint amountOut, ) = Multipool(_pool).burn(
            _asset,
            _sharesIn.unwrap(),
            _to
        );

        require(
            ud(amountOut) >= _amountOutMin,
            "Multipool Router: sleepage exeeded"
        );
    }

    function swap(
        address _pool,
        address _assetIn,
        address _assetOut,
        UD60x18 _amountInMax,
        UD60x18 _amountOutMin,
        UD60x18 _shares,
        address _to,
        uint deadline
    ) public ensure(deadline) {
        // Transfer all amount in in case the last part will return via multipool
        IERC20(_pool).transferFrom(msg.sender, _pool, _amountInMax.unwrap());
        // No need to check sleepage because contract will fail if there is no
        // enough funst been transfered
        (uint amountIn, uint amountOut, , ) = Multipool(_pool).swap(
            _assetIn,
            _assetOut,
            _shares.unwrap(),
            _to
        );
        require(
            ud(amountOut) >= _amountOutMin,
            "Multipool Router: sleepage exeeded"
        );
        require(
            ud(amountIn) <= _amountInMax,
            "Multipool Router: sleepage exeeded"
        );
    }

    //NON ready feature
    function mintWithAmountIn(
        address _pool,
        address _asset,
        UD60x18 _amountIn,
        UD60x18 _sharesOutMin,
        address _to,
        uint deadline
    ) public ensure(deadline) {
        MpAsset memory asset = convertAsset(Multipool(_pool).getAssets(_asset));
        MpContext memory context = convertContext(
            Multipool(_pool).getMintContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 amountOut = context.mint(asset, _amountIn);

        UD60x18 sharesOut = (amountOut * asset.price * totalSupply) /
            oldTotalCurrentUsdAmount;
        require(
            sharesOut >= _sharesOutMin,
            "Multipool Router: sleepage exeeded"
        );

        IERC20(_asset).transferFrom(msg.sender, _pool, _amountIn.unwrap());
        Multipool(_pool).mint(_asset, sharesOut.unwrap(), _to);
    }

    //NON ready feature
    function burnWithAmountOut(
        address _pool,
        address _asset,
        UD60x18 _amountOut,
        UD60x18 _sharesInMax,
        address _to,
        uint deadline
    ) public ensure(deadline) {
        MpAsset memory asset = convertAsset(Multipool(_pool).getAssets(_asset));
        MpContext memory context = convertContext(
            Multipool(_pool).getBurnContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 requiredAmountIn = context.burnRev(asset, _amountOut);
        UD60x18 requiredSharesIn = (requiredAmountIn *
            asset.price *
            totalSupply) / oldTotalCurrentUsdAmount;
        require(
            requiredSharesIn <= _sharesInMax,
            "Multipool Router: sleepage exeeded"
        );

        IERC20(_pool).transferFrom(
            msg.sender,
            _pool,
            requiredSharesIn.unwrap()
        );
        Multipool(_pool).burn(_asset, requiredSharesIn.unwrap(), _to);
    }

    //NON ready feature
    function swapWithAmountIn(
        address _pool,
        address _assetIn,
        address _assetOut,
        UD60x18 _amountIn,
        UD60x18 _amountOutMin,
        address _to,
        uint deadline
    ) public ensure(deadline) {
        UD60x18 shares;
        {
            {
                MpAsset memory assetIn = convertAsset(
                    Multipool(_pool).getAssets(_assetIn)
                );
                MpContext memory context = convertContext(
                    Multipool(_pool).getMintContext()
                );
                UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
                UD60x18 oldTotalCurrentUsdAmount = context
                    .totalCurrentUsdAmount;

                UD60x18 mintAmountOut = context.mint(assetIn, _amountIn);

                shares =
                    (mintAmountOut * assetIn.price * totalSupply) /
                    oldTotalCurrentUsdAmount;
            }
        }

        IERC20(_assetIn).transferFrom(msg.sender, _pool, _amountIn.unwrap());
        (uint amountIn, uint amountOut, , ) = Multipool(_pool).swap(
            _assetIn,
            _assetOut,
            shares.unwrap(),
            _to
        );

        require(
            ud(amountOut) >= _amountOutMin,
            "Multipool Router: sleepage exeeded"
        );
        require(
            ud(amountIn) <= _amountIn,
            "Multipool Router: sleepage exeeded"
        );
    }

    //NON ready feature
    function swapWithAmountOut(
        address _pool,
        address _assetIn,
        address _assetOut,
        UD60x18 _amountOut,
        UD60x18 _amountInMax,
        address _to,
        uint deadline
    ) public ensure(deadline) {
        UD60x18 shares;
        {
            {
                MpAsset memory assetOut = convertAsset(
                    Multipool(_pool).getAssets(_assetOut)
                );
                MpContext memory context = convertContext(
                    Multipool(_pool).getBurnContext()
                );
                UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
                UD60x18 oldTotalCurrentUsdAmount = context
                    .totalCurrentUsdAmount;

                UD60x18 burnAmountIn = context.burnRev(assetOut, _amountOut);
                shares =
                    (burnAmountIn * assetOut.price * totalSupply) /
                    oldTotalCurrentUsdAmount;
            }
        }

        IERC20(_assetIn).transferFrom(msg.sender, _pool, _amountInMax.unwrap());
        (, uint amountOut, , ) = Multipool(_pool).swap(
            _assetIn,
            _assetOut,
            shares.unwrap(),
            _to
        );

        require(
            ud(amountOut) >= _amountOut,
            "Multipool Router: sleepage exeeded"
        );
    }

    function estimateMintSharesOut(
        address _pool,
        address _asset,
        UD60x18 _amountIn
    ) public view returns (UD60x18 sharesOut) {
        MpAsset memory asset = convertAsset(Multipool(_pool).getAssets(_asset));
        MpContext memory context = convertContext(
            Multipool(_pool).getMintContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 amountOut = context.mint(asset, _amountIn);

        sharesOut =
            (amountOut * asset.price * totalSupply) /
            oldTotalCurrentUsdAmount;
    }

    function estimateMintAmountIn(
        address _pool,
        address _asset,
        UD60x18 _sharesOut
    ) public view returns (UD60x18 _amountIn) {
        MpAsset memory asset = convertAsset(Multipool(_pool).getAssets(_asset));
        MpContext memory context = convertContext(
            Multipool(_pool).getMintContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 amountIn = (_sharesOut * oldTotalCurrentUsdAmount) /
            asset.price /
            totalSupply;

        _amountIn = context.mintRev(asset, amountIn);
    }

    // this works straight way
    function estimateBurnAmountOut(
        address _pool,
        address _asset,
        UD60x18 _sharesIn
    ) public view returns (UD60x18 _amountOut) {
        MpAsset memory asset = convertAsset(Multipool(_pool).getAssets(_asset));
        MpContext memory context = convertContext(
            Multipool(_pool).getBurnContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 amountIn = (_sharesIn * oldTotalCurrentUsdAmount) /
            asset.price /
            totalSupply;

        _amountOut = context.burn(asset, amountIn);
    }

    function estimateBurnSharesIn(
        address _pool,
        address _asset,
        UD60x18 _amountOut
    ) public view returns (UD60x18 _sharesIn) {
        MpAsset memory asset = convertAsset(Multipool(_pool).getAssets(_asset));
        MpContext memory context = convertContext(
            Multipool(_pool).getBurnContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 amountIn = context.burnRev(asset, _amountOut);

        _sharesIn =
            (amountIn * asset.price * totalSupply) /
            oldTotalCurrentUsdAmount;
    }

    function estimateSwapSharesByAmountIn(
        address _pool,
        address _assetIn,
        address _assetOut,
        UD60x18 _amountIn
    ) public view returns (UD60x18 shares, UD60x18 amountOut) {
        MpAsset memory assetIn = convertAsset(
            Multipool(_pool).getAssets(_assetIn)
        );
        MpAsset memory assetOut = convertAsset(
            Multipool(_pool).getAssets(_assetOut)
        );
        MpContext memory context = convertContext(
            Multipool(_pool).getTradeContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 mintAmountOut = context.mint(assetIn, _amountIn);

        shares =
            (mintAmountOut * assetIn.price * totalSupply) /
            oldTotalCurrentUsdAmount;

        UD60x18 burnAmountIn = (shares * context.totalCurrentUsdAmount) /
            assetOut.price /
            (totalSupply + shares);

        amountOut = context.burn(assetOut, burnAmountIn);
    }

    function estimateSwapSharesByAmountOut(
        address _pool,
        address _assetIn,
        address _assetOut,
        UD60x18 _amountOut
    ) public view returns (UD60x18 shares, UD60x18 amountIn) {
        MpAsset memory assetIn = convertAsset(
            Multipool(_pool).getAssets(_assetIn)
        );
        MpAsset memory assetOut = convertAsset(
            Multipool(_pool).getAssets(_assetOut)
        );
        MpContext memory context = convertContext(
            Multipool(_pool).getTradeContext()
        );
        UD60x18 totalSupply = ud(Multipool(_pool).totalSupply());
        UD60x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        UD60x18 burnAmountIn = context.burnRev(assetOut, _amountOut);

        shares =
            (burnAmountIn * assetOut.price * totalSupply) /
            oldTotalCurrentUsdAmount;

        UD60x18 mintAmountIn = (shares * context.totalCurrentUsdAmount) /
            assetIn.price /
            (totalSupply - shares);

        amountIn = context.mintRev(assetIn, mintAmountIn);
    }
}
