// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import "forge-std/Script.sol";
import {Multipool} from "../src/multipool/Multipool.sol";
import {WETH} from "../src/multipool/MultipoolRouter.sol";
import {OraclePrice} from "../src/types/OraclePrice.sol";

contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);
        address tokenIn = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
        address tokenOut = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address mp = 0xC6f70B36C5B54BFf3C508FBb2F16331Dfae84Cea;
        OraclePrice memory op;
        WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(
            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, 1e7
        );
        IUniswapV3Router.ExactInputSingleParams memory swapParams = IUniswapV3Router
            .ExactInputSingleParams({
            tokenIn: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            tokenOut: tokenIn,
            fee: 10000,
            recipient: mp,
            amountIn: 1e7,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });
        uint amountOut = IUniswapV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45)
            .exactInputSingle{value: 1e7}(swapParams);
        Multipool(mp).swap{value: 1e17}(
            op, tokenIn, tokenOut, amountOut, true, deployerPublicKey, deployerPublicKey, true
        );
        vm.stopBroadcast();
    }
}

interface IUniswapV3Router {
    function factory() external returns (address);

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory params)
        external
        payable
        returns (uint256 amountOut);

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        returns (uint256 amountIn);
}
