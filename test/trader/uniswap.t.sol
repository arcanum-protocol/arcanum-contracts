// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {Trader, WETH} from "../../src/trader/Trader.sol";
import {FeedInfo, FeedType, PriceMath} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32} from "../MultipoolUtils.t.sol";
import {IUniswapV3Pool} from "uniswapv3/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "../../src/interfaces/IUniswapRouter.sol";
import {ForcePushArgs} from "../../src/types/SwapArgs.sol";

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

    function test_SwapWithTrader1() public {
        vm.selectFork(arbitrumFork);

        Trader t = new Trader();

        bytes[] memory s = new bytes[](1);
        s[0] =
            hex"cf1efb7ec342bd4ed3401265ffac80b501d640e19c2f47c64a021b4812ccd7e6621e512608e828eed20778a9f4d963f5007196cbbe0f44a4e135bd7d0ab4e6011b";

        Trader.Args memory args = Trader.Args({
            tokenIn: IERC20(0x539bdE0d7Dbd336b79148AA742883198BBF60342),
            zeroForOneIn: false,
            tokenOut: IERC20(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8),
            zeroForOneOut: true,
            // magic/eth 3000 0x59d72ddb29da32847a4665d08ffc8464a7185fae
            // magic/eth 10000 0x7e7fb3cceca5f2ac952edf221fd2a9f62e411980
            poolIn: IUniswapV3Pool(0x59D72DDB29Da32847A4665d08ffc8464A7185FAE),
            // pendle/eth 3000 0xdbaeb7f0dfe3a0aafd798ccecb5b22e708f7852c
            // pendle/eth 10000 0xe8629b6a488f366d27dad801d1b5b445199e2ada
            poolOut: IUniswapV3Pool(0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c),
            multipoolAmountIn: 2902027515851877489,
            multipoolAmountOut: 10000,
            multipoolFee: 1000000000000000,
            multipool: Multipool(0x4810E5A7741ea5fdbb658eDA632ddfAc3b19e3c6),
            fp: ForcePushArgs({
                contractAddress: 0x4810E5A7741ea5fdbb658eDA632ddfAc3b19e3c6,
                timestamp: 1704676035,
                sharePrice: 49764838329715057682058381,
                signatures: s
            }),
            gasLimit: 600000,
            weth: WETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        });
        vm.warp(1704676035);
        //vm.expectRevert("no profit");
        t.trade{value: 1e18, gas: args.gasLimit}(args);
    }

    function test_SwapWithTrader2() public {
        vm.selectFork(arbitrumFork2);

        Trader t = new Trader();

        bytes[] memory s = new bytes[](1);
        s[0] =
            hex"85323389dc46ab062d52d2ce9846626489239c2768b237fbddd03647e4625af8663a0988039dd9c8f4b1acb0935da7429c563a2c2197bb04ff10070e5a670c2e1c";

        Trader.Args memory args = Trader.Args({
            tokenIn: IERC20(0x3082CC23568eA640225c2467653dB90e9250AaA0),
            zeroForOneIn: false,
            tokenOut: IERC20(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8),
            zeroForOneOut: true,
            poolIn: IUniswapV3Pool(0x446BF9748B4eA044dd759d9B9311C70491dF8F29),
            // pendle/eth 3000 0xdbaeb7f0dfe3a0aafd798ccecb5b22e708f7852c
            // pendle/eth 10000 0xe8629b6a488f366d27dad801d1b5b445199e2ada
            poolOut: IUniswapV3Pool(0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c),
            multipoolAmountIn: 235459495774334240,
            multipoolAmountOut: 10000,
            multipoolFee: 1000000000000000,
            multipool: Multipool(0x4810E5A7741ea5fdbb658eDA632ddfAc3b19e3c6),
            fp: ForcePushArgs({
                contractAddress: 0x4810E5A7741ea5fdbb658eDA632ddfAc3b19e3c6,
                timestamp: 1704739268,
                sharePrice: 49432770753888933655371916,
                signatures: s
            }),
            gasLimit: 5000000,
            weth: WETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        });
        vm.warp(1704728497);
        //vm.expectRevert("no profit");
        t.trade{value: 0.02e18, gas: args.gasLimit}(args);
    }
}
