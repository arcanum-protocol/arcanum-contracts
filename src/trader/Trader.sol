// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

import {IUniswapV3Pool} from "uniswapv3/interfaces/IUniswapV3Pool.sol";
import {ICashbackVault} from "../interfaces/ICashbackVault.sol";
import {IWrapper} from "../interfaces/IWrapper.sol";
import {Multipool} from "../multipool/Multipool.sol";
import {AssetArgs, ForcePushArgs} from "../types/SwapArgs.sol";
import {ISwapRouter} from "../interfaces/IUniswapRouter.sol";

interface WETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to
/// getSqrtRatioAtTick(MIN_TICK)
uint160 constant MIN_SQRT_RATIO = 4295128739;
/// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to
/// getSqrtRatioAtTick(MAX_TICK)
uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

contract Trader {
    receive() external payable {}

    error Reverted(bytes data);

    struct Call {
        IWrapper wrapper;
        bytes data;
    }

    struct Args {
        IERC20 tokenIn;
        IERC20 tokenOut;
        IERC20 multipoolTokenIn;
        IERC20 multipoolTokenOut;
        Call firstCall;
        Call secondCall;
        uint tmpAmount;
        IUniswapV3Pool poolIn;
        bool zeroForOneIn;
        IUniswapV3Pool poolOut;
        bool zeroForOneOut;
        uint multipoolSleepage;
        uint multipoolFee;
        Multipool multipool;
        ForcePushArgs fp;
        uint gasLimit;
        WETH weth;
        ICashbackVault cashback;
        address[] assets;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    )
        external
    {
        (Args memory args, uint value, bool firstCall) = abi.decode(_data, (Args, uint, bool));
        if (firstCall) {
            if (address(args.cashback) != address(0)) {
                args.cashback.payCashback(address(args.multipool), args.assets);
            }
            WETH weth = WETH(args.weth);
            weth.deposit{value: value - args.multipoolFee}();
            uint amountToPay = amount0Delta > 0 ? uint(amount0Delta) : uint(amount1Delta);
            weth.transfer(msg.sender, amountToPay);

            int amount;
            if (args.tokenIn != args.multipoolTokenIn) {
                args.tokenIn.transfer(address(args.firstCall.wrapper), args.tmpAmount);
                amount = int(
                    args.firstCall.wrapper.wrap(
                        args.tmpAmount, address(args.multipool), args.firstCall.data
                    )
                );
            } else {
                args.tokenIn.transfer(address(args.multipool), args.tmpAmount);
                amount = int(args.tmpAmount);
            }

            AssetArgs[] memory assetArgs = new AssetArgs[](2);
            if (args.multipoolTokenIn < args.multipoolTokenOut) {
                assetArgs[0] =
                    AssetArgs({assetAddress: address(args.multipoolTokenIn), amount: amount});
                assetArgs[1] = AssetArgs({
                    assetAddress: address(args.multipoolTokenOut),
                    amount: -int(args.multipoolSleepage)
                });
            } else {
                assetArgs[1] =
                    AssetArgs({assetAddress: address(args.multipoolTokenIn), amount: amount});
                assetArgs[0] = AssetArgs({
                    assetAddress: address(args.multipoolTokenOut),
                    amount: -int(args.multipoolSleepage)
                });
            }

            args.multipool.swap{value: args.multipoolFee}(
                args.fp, assetArgs, true, address(this), false, address(this)
            );

            uint amountOut = args.multipoolTokenOut.balanceOf(address(this));

            if (args.tokenOut != args.multipoolTokenOut) {
                args.multipoolTokenOut.transfer(address(args.secondCall.wrapper), amountOut);
                amountOut =
                    args.secondCall.wrapper.unwrap(amountOut, address(this), args.secondCall.data);
            }
        } else {
            args.tokenOut.transfer(msg.sender, value);
            args.weth.withdraw(args.weth.balanceOf(address(this)));
        }
    }

    function trade(Args calldata args) external payable returns (uint profit, uint gasUsed) {
        uint suppliedValue = msg.value;
        args.poolIn.swap(
            address(this),
            args.zeroForOneIn,
            -int(args.tmpAmount),
            args.zeroForOneIn ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            abi.encode(args, msg.value, true)
        );

        uint amountOut = args.tokenOut.balanceOf(address(this));
        args.poolOut.swap(
            address(this),
            args.zeroForOneOut,
            int(amountOut),
            args.zeroForOneOut ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            abi.encode(args, amountOut, false)
        );

        unchecked {
            require(address(this).balance > suppliedValue, "no profit");
            profit = address(this).balance - suppliedValue;
        }
        payable(msg.sender).transfer(address(this).balance);
        gasUsed = args.gasLimit - gasleft();
    }
}
