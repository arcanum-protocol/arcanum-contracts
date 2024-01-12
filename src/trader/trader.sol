// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

import {IUniswapV3Pool} from "uniswapv3/interfaces/IUniswapV3Pool.sol";
import {Multipool} from "../multipool/Multipool.sol";
import {AssetArgs, ForcePushArgs} from "../types/SwapArgs.sol";
import {ISwapRouter} from "../interfaces/IUniswapRouter.sol";

interface WETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
uint160 constant MIN_SQRT_RATIO = 4295128739;
/// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

contract Trader {
    receive() external payable {}

    struct Args {
        IERC20 tokenIn;
        bool zeroForOneIn;
        IERC20 tokenOut;
        bool zeroForOneOut;

        IUniswapV3Pool poolIn;
        IUniswapV3Pool poolOut;

        uint multipoolAmountIn;
        uint multipoolAmountOut;
        uint multipoolFee;

        Multipool multipool;
        ForcePushArgs fp;

        uint gasLimit;
        WETH weth;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        (Args memory args, uint value) = abi.decode(_data, (Args, uint));
        if (msg.sender == address(args.poolIn)) {
            WETH weth = WETH(args.weth);
            weth.deposit{value: value - args.multipoolFee}();
            uint amountToPay = amount0Delta > 0 ? uint(amount0Delta) : uint(amount1Delta);
            weth.transfer(msg.sender, amountToPay);


            AssetArgs[] memory assetArgs = new AssetArgs[](2);
            if (args.tokenIn < args.tokenOut) {
                assetArgs[0] = AssetArgs({
                   assetAddress: address(args.tokenIn),
                   amount: int(args.multipoolAmountIn)
                });
                assetArgs[1] = AssetArgs({
                   assetAddress: address(args.tokenOut),
                   amount: -int(args.multipoolAmountOut)
                });
            } else {
                assetArgs[1] = AssetArgs({
                   assetAddress: address(args.tokenIn),
                   amount: int(args.multipoolAmountIn)
                });
                assetArgs[0] = AssetArgs({
                   assetAddress: address(args.tokenOut),
                   amount: -int(args.multipoolAmountOut)
                });
            }

            args.multipool.swap{value: args.multipoolFee}(
                args.fp,
                assetArgs,
                true,
                address(this),
                false,
                address(this)
            );

            uint amountIn = args.tokenOut.balanceOf(address(this));
            args.poolOut.swap(
                address(this),
                args.zeroForOneOut,
                int(amountIn),
                args.zeroForOneOut ? MIN_SQRT_RATIO+1 : MAX_SQRT_RATIO-1,
                abi.encode(args, amountIn)
            );
        } else {
            args.tokenOut.transfer(msg.sender, value);
            args.weth.withdraw(args.weth.balanceOf(address(this)));
        }
    }

    function trade(Args calldata args) external payable returns(uint profit, uint gasUsed) {
        uint suppliedValue = address(this).balance;
        args.poolIn.swap(
            address(args.multipool),
            args.zeroForOneIn,
            -int(args.multipoolAmountIn),
            args.zeroForOneIn ? MIN_SQRT_RATIO+1 : MAX_SQRT_RATIO-1,
            abi.encode(args, msg.value)
        );
        unchecked {
            require(address(this).balance > suppliedValue, "no profit");
            profit = address(this).balance - suppliedValue;
        }
        payable(msg.sender).transfer(address(this).balance);
        gasUsed = args.gasLimit - gasleft();
    }
}
