//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Multipool.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract MultipoolRouter {

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'Multipool Router: EXPIRED');
        _;
    }

    constructor () {}

    function mintWithSharesOut(
       address _pool,
       address _asset,
       uint _sharesOut,
       uint _amountInMax,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        // Transfer all amount in in case the last part will return via multipool
        IERC20(_pool).transferFrom(msg.sender, _pool, _amountInMax);
        // No need to check sleepage because contract will fail if there is no
        // enough funst been transfered
        Multipool(_pool).mint(_asset, _sharesOut, _to);
   }


    function burnWithSharesIn(
       address _pool,
       address _asset,
       uint _sharesIn,
       uint _amountOutMin,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        IERC20(_pool).transferFrom(msg.sender, _pool, _sharesIn);
        uint amountOut = Multipool(_pool).burn(_asset, _sharesIn, _to);

        require(amountOut >= _amountOutMin, "Multipool Router: sleepage exeeded");
   }

   function swap(
       address _pool,
       address _assetIn,
       address _assetOut,
       uint _amountInMax,
       uint _amountOutMin,
       uint _shares,
       address _to,
       uint deadline
   ) public ensure(deadline) {
        // Transfer all amount in in case the last part will return via multipool
        IERC20(_pool).transferFrom(msg.sender, _pool, _amountInMax);
        // No need to check sleepage because contract will fail if there is no
        // enough funst been transfered
        (uint amountIn, uint amountOut) = Multipool(_pool).swap(_assetIn, _assetOut, _shares, _to);
        require(amountOut >= _amountOutMin, "Multipool Router: sleepage exeeded");
        require(amountIn <= _amountInMax, "Multipool Router: sleepage exeeded");
   }

    //NON ready feature
    function burnWithAmountOut(
       address _pool,
       address _asset,
       uint _amountOut,
       uint _sharesInMax,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        MpAsset memory asset = Multipool(_pool).getAssets(_asset);
        MpContext memory context = Multipool(_pool).getBurnContext();
        uint totalSupply = Multipool(_pool).totalSupply();
        SD59x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        SD59x18 requiredAmountIn = context.burnRev(asset, sd(int(_amountOut)));
        uint requiredSharesIn = uint((requiredAmountIn * asset.price 
            * sd(int(totalSupply)) / oldTotalCurrentUsdAmount).unwrap());
        require(requiredSharesIn <= _sharesInMax, "Multipool Router: sleepage exeeded");
        
        IERC20(_pool).transferFrom(msg.sender, _pool, requiredSharesIn);
        Multipool(_pool).burn(_asset, requiredSharesIn, _to);
   }

    //NON ready feature
    function mintWithAmountIn(
       address _pool,
       address _asset,
       uint _amountIn,
       uint _sharesOutMin,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        MpAsset memory asset = Multipool(_pool).getAssets(_asset);
        MpContext memory context = Multipool(_pool).getMintContext();
        uint totalSupply = Multipool(_pool).totalSupply();
        SD59x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        SD59x18 amountOut = context.mint(asset, sd(int(_amountIn)));

        SD59x18 sharesOut = amountOut * asset.price 
            * sd(int(totalSupply)) / oldTotalCurrentUsdAmount;
        require(uint(sharesOut.unwrap()) >= _sharesOutMin, "Multipool Router: sleepage exeeded");
        
        IERC20(_pool).transferFrom(msg.sender, _pool, _amountIn);
        Multipool(_pool).mint(_asset, uint(sharesOut.unwrap()), _to);
   }

    //NON ready feature
    function swapWithAmountIn(
       address _pool,
       address _assetIn,
       address _assetOut,
       uint _amountIn,
       uint _amountOutMin,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        uint shares;
        {{
            MpAsset memory assetIn = Multipool(_pool).getAssets(_assetIn);
            MpContext memory context = Multipool(_pool).getMintContext();
            uint totalSupply = Multipool(_pool).totalSupply();
            SD59x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

            SD59x18 mintAmountOut = context.mint(assetIn, sd(int(_amountIn)));

            shares = uint((mintAmountOut * assetIn.price 
                * sd(int(totalSupply)) / oldTotalCurrentUsdAmount).unwrap());
        }}

        IERC20(_pool).transferFrom(msg.sender, _pool, _amountIn);
        (uint amountIn, uint amountOut) = Multipool(_pool).swap(_assetIn, _assetOut, shares, _to);

        require(amountOut >= _amountOutMin, "Multipool Router: sleepage exeeded");
        require(amountIn <= _amountIn, "Multipool Router: sleepage exeeded");
   }

    //NON ready feature
    function swapWithAmountOut(
       address _pool,
       address _assetIn,
       address _assetOut,
       uint _amountOut,
       uint _amountInMax,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        uint shares;
        {{
            MpAsset memory assetOut = Multipool(_pool).getAssets(_assetOut);
            MpContext memory context = Multipool(_pool).getBurnContext();
            uint totalSupply = Multipool(_pool).totalSupply();
            SD59x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

            SD59x18 burnAmountIn = context.burnRev(assetOut, sd(int(_amountOut)));
            shares = uint((burnAmountIn * assetOut.price 
                * sd(int(totalSupply)) / oldTotalCurrentUsdAmount).unwrap());
        }}
        
        IERC20(_pool).transferFrom(msg.sender, _pool, _amountInMax);
        (uint amountIn, uint amountOut) = Multipool(_pool).swap(_assetIn, _assetOut, shares, _to);

        require(amountOut >= _amountOut, "Multipool Router: sleepage exeeded");
   }

}
