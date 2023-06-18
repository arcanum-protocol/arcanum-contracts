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

//    function dryMint(
//        address _pool,
//        address _asset, 
//        uint _quantity, 
//        uint _share
//    ) public view returns (uint amountIn, uint share, uint cashback) {
//        MultipoolMath.Asset memory asset = Multipool(_pool).assets(_asset);
//        MultipoolMath.Context memory context = Multipool(_pool).getMintContext();
//        SD59x18 suppliableBalance = sd(int(_quantity));
//        uint refund;
//        if (_share == 0) {
//            SD59x18 utilisableQuantity = MultipoolMath.evalMintContext(suppliableBalance, context, asset);
//
//            if (totalCurrentUsdAmount > sd(0)) {
//                _share = uint(SD59x18.unwrap(utilisableQuantity * asset.price 
//                    * sd(int(totalSupply())) / totalCurrentUsdAmount));
//            } else {
//                _share = uint(SD59x18.unwrap(utilisableQuantity));
//            }
//
//            amountIn = uint(suppliableBalance.unwrap());
//            cashback = uint(SD59x18.unwrap(context.userCashbackBalance));
//            share = _share;
//        } else {
//            SD59x18 requiredShareBalance = sd(int(_share)) * totalCurrentUsdAmount
//                / sd(int(totalSupply())) / asset.price;
//            SD59x18 requiredSuppliableQuantity = 
//                MultipoolMath.reversedEvalMintContext(requiredShareBalance, context, asset);
//
//            require(requiredShareBalance <= suppliableBalance, "required to burn more share than provided");
//            
//            amountIn = uint(requiredSuppliableQuantity.unwrap());
//            cashback = uint(SD59x18.unwrap(context.userCashbackBalance));
//            share = _share;
//        }
//    }

    function amountToShare() public view returns (SD59x18) {
        return sd(0);
    }

//    function dryBurn(
//        address _pool,
//        uint _share,
//        address _asset,
//        uint _quantity    
//    ) public view returns (uint share, uint amountOut, uint cashback) {
//        MultipoolMath.Asset memory asset = Multipool(_pool).assets(_asset);
//        MultipoolMath.Context memory context = Multipool(_pool).getBurnContext();
//
//        uint refund;
//        SD59x18 burnQuantity = sd(int(_share)) * totalCurrentUsdAmount 
//            / sd(int(totalSupply())) / asset.price;
//        if (_quantity == 0) {
//            SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(burnQuantity, context, asset);
//
//            share = _share;
//            amountOut = uint(SD59x18.unwrap(utilisableQuantity));
//            cashback = uint(SD59x18.unwrap(context.userCashbackBalance));
//        } else {
//            SD59x18 requiredSuppliableQuantity = MultipoolMath.reversedEvalBurnContext(sd(int(_quantity)), context, asset);
//            uint requiredSuppliableShare = uint(SD59x18.unwrap(requiredSuppliableQuantity 
//                * asset.price * sd(int(totalSupply())) / totalCurrentUsdAmount));
//            if (_share != 0) {
//                require(requiredSuppliableShare <= _share, "required to burn more share than provided");
//            }
//
//            share = requiredSuppliableShare;
//            amountOut = _quantity;
//            cashback = uint(SD59x18.unwrap(context.userCashbackBalance));
//        }
//   }

//   function drySwap(
//       address _pool,
//       address _assetIn,
//       address _assetOut,
//       uint _quantityIn,
//       uint _quantityOut
//   ) public returns (
//    uint amountIn, 
//    uint amountOut, 
//    uint cashbackIn, 
//    uint cashbackOut
//   ) {
//        MultipoolMath.Asset memory assetIn = Multipool(_pool).assets(_assetIn);
//        MultipoolMath.Asset memory assetOut = Multipool(_pool).assets(_assetOut);
//        MultipoolMath.Context memory context = Multipool(_pool).getTradeContext();
//
//        SD59x18 suppliableBalance = sd(int(_quantityIn));
//        if (_quantityOut == 0) {
//            SD59x18 mintQuantityOut = MultipoolMath.evalMintContext(suppliableBalance, context, assetIn);
//
//            SD59x18 burnQuantityIn = mintQuantityOut * assetOut.price / assetIn.price;
//
//            cashbackIn = uint(SD59x18.unwrap(context.userCashbackBalance));
//            context.userCashbackBalance = sd(0);
//
//            SD59x18 burnQuantityOut = MultipoolMath.evalBurnContext(burnQuantityIn, context, assetOut);
//
//            amountOut = uint(SD59x18.unwrap(burnQuantityOut));
//            amountIn = _quantityIn;
//            cashbackOut = uint(SD59x18.unwrap(context.userCashbackBalance));
//        } else {
//            SD59x18 requiredSuppliableQuantity = 
//                MultipoolMath.reversedEvalBurnContext(sd(int(_quantityOut)), context, assetOut);
//            SD59x18 mintQuantityOut = requiredSuppliableQuantity * assetIn.price / assetOut.price ;
//
//            cashbackOut = uint(SD59x18.unwrap(context.userCashbackBalance));
//            context.userCashbackBalance = sd(0);
//
//            SD59x18 mintQuantityIn = 
//                MultipoolMath.reversedEvalMintContext(mintQuantityOut, context, assetIn);
//
//            require(mintQuantityIn <= suppliableBalance, 
//                    "required to burn more share than provided");
//
//            amountOut = _quantityOut;
//            amountIn = uint(mintQuantityIn.unwrap());
//            cashbackIn = uint(SD59x18.unwrap(context.userCashbackBalance));
//        }
//   }

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

    //NON ready feature
    function mintWithAmountIn(
       address _pool,
       address _asset,
       uint _amountIn,
       uint _sharesOutMin,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        MultipoolMath.Asset memory asset = Multipool(_pool).getAssets(_asset);
        MultipoolMath.Context memory context = Multipool(_pool).getMintContext();
        uint totalSupply = Multipool(_pool).totalSupply();
        SD59x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        SD59x18 amountOut = MultipoolMath.evalMintContext(sd(int(_amountIn)), context, asset);

        SD59x18 sharesOut = amountOut * asset.price 
            * sd(int(totalSupply)) / oldTotalCurrentUsdAmount;
        require(uint(sharesOut.unwrap()) >= _sharesOutMin, "Multipool Router: sleepage exeeded");
        
        IERC20(_pool).transferFrom(msg.sender, _pool, _amountIn);
        Multipool(_pool).mint(_asset, uint(sharesOut.unwrap()), _to);
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

    //NON ready feature
    function burnWithAmountOut(
       address _pool,
       address _asset,
       uint _amountOut,
       uint _sharesInMax,
       address _to,
       uint deadline
    ) public ensure(deadline) {
        MultipoolMath.Asset memory asset = Multipool(_pool).getAssets(_asset);
        MultipoolMath.Context memory context = Multipool(_pool).getBurnContext();
        uint totalSupply = Multipool(_pool).totalSupply();
        SD59x18 oldTotalCurrentUsdAmount = context.totalCurrentUsdAmount;

        SD59x18 requiredAmountIn = MultipoolMath.reversedEvalBurnContext(sd(int(_amountOut)), context, asset);
        uint requiredSharesIn = uint((requiredAmountIn * asset.price 
            * sd(int(totalSupply)) / oldTotalCurrentUsdAmount).unwrap());
        require(requiredSharesIn <= _sharesInMax, "Multipool Router: sleepage exeeded");
        
        IERC20(_pool).transferFrom(msg.sender, _pool, requiredSharesIn);
        Multipool(_pool).burn(_asset, requiredSharesIn, _to);
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
        uint amountOut = Multipool(_pool).swap(_assetIn, _assetOut, _shares, _to);
        require(amountOut >= _amountOutMin, "Multipool Router: sleepage exeeded");
   }
//     function mintWithSwapPath(
//         address _etf,
//         address[][] calldata _swapPaths, // array of tokens array to swap
//         address[][] calldata _pairs, // Uniswap pairs to be used inside swaps
//         uint[][] calldata _amounts, // amounts of tokens that should be used in swap
//         uint _minShare,
//         address _to
//     ) external {
//         for (uint256 i; i < _swapPaths.length; i++) {
//             IERC20(_swapPaths[i][0]).transferFrom(
//                 msg.sender,
//                 _pairs[i][0],
//                 _amounts[i][0]
//             );
//             uint256 length = _pairs[i].length;
//             for (uint256 y; y < length; y++) {
//                 // decomposition to avoid stack to deep
//                 (uint256 amount0Out, uint256 amount1Out) = sortAmounts(
//                     _swapPaths[i][y],
//                     _swapPaths[i][y + 1],
//                     _amounts[i][y + 1]
//                 );
//                 address to = y == length - 1 ? _etf : _pairs[i][y+1];
//                 IUniswapV2Pair(_pairs[i][y]).swap(
//                     amount0Out,
//                     amount1Out,
//                     to,
//                     new bytes(0)
//                 );
//             }
//             require(
//                 Multipool(_etf).mint(_swapPaths[i][_swapPaths.length], _to) > _minShare, 
//                 "Receiver share is too low"
//             );
//         }
//     }
}
