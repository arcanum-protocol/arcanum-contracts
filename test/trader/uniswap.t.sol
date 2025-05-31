// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {SiloPriceAdapter} from "../../src/multipool/SiloAdapter.sol";
import {Trader, WETH} from "../../src/trader/Trader.sol";
import {FeedType, PriceMath} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32} from "../MultipoolUtils.t.sol";
import {IUniswapV3Pool} from "uniswapv3/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "../../src/interfaces/IUniswapRouter.sol";
import {IWrapper} from "../../src/interfaces/IWrapper.sol";
import {ICashbackVault} from "../../src/interfaces/ICashbackVault.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";

/// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to
/// getSqrtRatioAtTick(MIN_TICK)
uint160 constant MIN_SQRT_RATIO = 4295128739;
/// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to
/// getSqrtRatioAtTick(MAX_TICK)
uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

interface AaveV3 is IERC20 {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    )
        external;
    function withdraw(address asset, uint256 amount, address to) external;
    function symbol() external returns (string memory symbol);
}

contract MultipoolPriceFetching is Test {
    receive() external payable {}

    uint mainnetFork;
    uint arbitrumFork;
    uint arbitrumFork2;

    function setUp() public {
        vm.skip(true);
        mainnetFork = vm.createFork("https://eth.llamarpc.com", 18943463);
        arbitrumFork = vm.createFork("https://rpc.ankr.com/arbitrum", 168178553);
        arbitrumFork2 = vm.createFork("https://rpc.ankr.com/arbitrum", 168426081);
    }

    function test_SwapInUniv3() public {
        vm.selectFork(mainnetFork);

        IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        WETH weth = WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        weth.deposit{value: 1e18}();
        //weth.transfer(pool, 1e18);

        ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

        weth.approve(address(swapRouter), 1e18);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(usdc),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: 1e18,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        uint amountOut = swapRouter.exactInputSingle(params);

        // amountOutMin must be retrieved from an oracle of some kind

        uint am = usdc.balanceOf(address(this));
        usdc.approve(address(swapRouter), am);

        ISwapRouter.ExactOutputSingleParams memory params2 = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(weth),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: 99900025e10,
            amountInMaximum: type(uint).max,
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactOutputSingle(params2);

        weth.withdraw(weth.balanceOf(address(this)));
    }

    function test_SwapWithTrader2() public {
        vm.selectFork(arbitrumFork2);

        Trader t = new Trader();

        address[] memory assets;

        Trader.Call memory c;
        Trader.Args memory args = Trader.Args({
            tokenIn: IERC20(0x3082CC23568eA640225c2467653dB90e9250AaA0),
            tokenOut: IERC20(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8),
            multipoolTokenIn: IERC20(0x3082CC23568eA640225c2467653dB90e9250AaA0),
            multipoolTokenOut: IERC20(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8),
            firstCall: c,
            secondCall: c,
            poolIn: IUniswapV3Pool(0x446BF9748B4eA044dd759d9B9311C70491dF8F29),
            zeroForOneIn: false,
            poolOut: IUniswapV3Pool(0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c),
            zeroForOneOut: true,
            // pendle/eth 3000 0xdbaeb7f0dfe3a0aafd798ccecb5b22e708f7852c
            // pendle/eth 10000 0xe8629b6a488f366d27dad801d1b5b445199e2ada
            tmpAmount: 235459495774334240,
            multipoolFee: 1000000000000000,
            multipool: Multipool(0x4810E5A7741ea5fdbb658eDA632ddfAc3b19e3c6),
            oraclePrice: OraclePrice({
                contractAddress: 0x4810E5A7741ea5fdbb658eDA632ddfAc3b19e3c6,
                timestamp: 1704739268,
                sharePrice: 49432770753888933655371916,
                signature: hex"85323389dc46ab062d52d2ce9846626489239c2768b237fbddd03647e4625af8663a0988039dd9c8f4b1acb0935da7429c563a2c2197bb04ff10070e5a670c2e1c"
            }),
            gasLimit: 5000000,
            weth: WETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1),
            cashback: ICashbackVault(address(0)),
            assets: assets
        });
        vm.warp(1704728497);
        //vm.expectRevert("no profit");
        t.trade{value: 0.02e18, gas: args.gasLimit}(args);
    }
}
