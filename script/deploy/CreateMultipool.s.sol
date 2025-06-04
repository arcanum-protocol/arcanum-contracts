// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {MultipoolFactory, MultipoolCreationParams} from "../../src/multipool/Factory.sol";
import {Trader} from "../../src/trader/Trader.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {
    toX96,
    toX32,
    toX16,
    updatePrice,
    toX16RatioTick,
    AbstractFixedValueOracle,
    computeContractAddress
} from "../../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=127.0.0.1:8545 --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);
        uint16[] memory s = new uint16[](5);
        bytes32[] memory prices = new bytes32[](5);
        address[] memory tokensAddresses = new address[](5);

        {
            bytes32 val;
            bytes memory data = abi.encodePacked(
                FeedType.UniV3, 0x0E5b205A058101584d0b94736212A517730F5FC0, true, uint64(0)
            );
            assembly {
                val := mload(add(data, 32))
            }
            prices[0] = val;
            data = abi.encodePacked(
                FeedType.UniV3, 0x00F26C926345D6F8e1BfCa684873C35070DC49Fd, false, uint64(0)
            );
            assembly {
                val := mload(add(data, 32))
            }
            prices[1] = val;
            data = abi.encodePacked(
                FeedType.UniV3, 0x96c8dfe099cEb7fe7cB9e5e070858f66363BD75C, true, uint64(0)
            );
            assembly {
                val := mload(add(data, 32))
            }
            prices[2] = val;
            data = abi.encodePacked(
                FeedType.UniV3, 0xf5E71C63967570Ff6fa4Db961F95e612b54CBe47, true, uint64(0)
            );
            assembly {
                val := mload(add(data, 32))
            }
            prices[3] = val;
            data = abi.encodePacked(
                FeedType.UniV3, 0xD1F87e48269F972110F77E989d519Cf151EDb485, true, uint64(0)
            );
            assembly {
                val := mload(add(data, 32))
            }
            prices[4] = val;
        }

        // address positionManager = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;
        // address universalRouter = 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2;

        // IUniswapV3Factory uf = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        // IUniswapV3Factory uf = IUniswapV3Factory(0x961235a9020B05C44DF1026D956D1F4D78014276);
        {
            tokensAddresses[0] = address(0xb2f82D0f38dc453D596Ad40A37799446Cc89274A);
            tokensAddresses[1] = address(0x0F0BDEbF0F83cD1EE3974779Bcb7315f9808c714);
            tokensAddresses[2] = address(0xE0590015A873bF326bd645c3E1266d4db41C4E6B);
            tokensAddresses[3] = address(0xfe140e1dCe99Be9F4F15d657CD9b7BF622270C50);
            tokensAddresses[4] = address(0xaEef2f6B429Cb59C9B2D7bB2141ADa993E8571c3);
            // for (uint i = 0; i < tokensAddresses.length; i++) {
            //     for (uint y = 0; y < tokensAddresses.length; y++) {
            //         if (tokensAddresses[i] == tokensAddresses[y]) {
            //             continue;
            //         }
            //         (address token0, address token1) = tokensAddresses[i] < tokensAddresses[y] ?
            // (tokensAddresses[i], tokensAddresses[y]) : (tokensAddresses[y], tokensAddresses[i]);
            //         address pool = uf.getPool(token0, token1, 3000);
            //         // 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
            //         if (pool == address(0)) {
            //             // IUniswapV3Pool(newPool).initialize(50000000000);
            //             IPositionManager(positionManager).createAndInitializePoolIfNecessary(token0,
            // token1, 3000, 50000000000);
            //             MockERC20WithDecimals(tokensAddresses[i]).approve(
            //                 positionManager, 10000e30
            //             );
            //             MockERC20WithDecimals(tokensAddresses[y]).approve(
            //                 positionManager, 10000e30
            //             );
            //             IPositionManager.MintParams memory p = IPositionManager.MintParams({
            //                 token0: token0,
            //                 token1: token1,
            //                 fee: 3000,
            //                 tickLower: 81000,
            //                 tickUpper: 90000,
            //                 amount0Desired: 12042000000000000,
            //                 amount1Desired: 12042000000000000,
            //                 amount0Min: 0,
            //                 amount1Min: 0,
            //                 recipient: deployerPublicKey,
            //                 deadline: block.timestamp + 1000
            //             });
            //             IPositionManager(positionManager).mint{value: 1e16}(p);
            //             // newPool.mint(deployerPublicKey, 0, 1, 12042000000000000, "");
            //         }
            //     }
            // }

            // s[0] = 10;
            // s[1] = 10;
            // s[2] = 10;
            // s[3] = 10;
            // s[4] = 10;
        }

        Oracle oracle = Oracle(payable(0x97CD13624bB12D4Ec39469b140f529459d5d369d));

        MultipoolFactory f = MultipoolFactory(0x7eFe6656d08f2d6689Ed8ca8b5A3DEA0efaa769f);
        // arb sepolia
        WETH weth = WETH(0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701);
        IUniswapV3Router uniRouter = IUniswapV3Router(0x4c4eABd5Fb1D1A7234A48692551eAECFF8194CA7);
        // NOTACTIVATED  0x22a2485421280363e9567b901F7CA63658f63db8
        // NOT ACTIVATED TFTF 0x4c4eABd5Fb1D1A7234A48692551eAECFF8194CA7
        address mp = 0x4cC4BcDAD979F9626d11E638479FD07a28E9E038;
        // address mp = computeContractAddress(address(f),
        // 0x14090b42338e02C786cDd6F29Bb83553FDe8f084, 1);
        // address mp = 0x46489e10E6E78EAFE087fde1Bc74e745182a2Eab;
        // console.log("mp ", mp);

        // IUniswapV3Router.ExactInputSingleParams memory swapParams = IUniswapV3Router
        //     .ExactInputSingleParams({
        //     tokenIn: address(weth),
        //     tokenOut: 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea,
        //     fee: 100,
        //     recipient: deployerPublicKey,
        //     amountIn: 1e18,
        //     amountOutMinimum: 1,
        //     sqrtPriceLimitX96: 0
        // });
        MockERC20(0xf817257fed379853cDe0fa4F97AB987181B1E5Ea).approve(0x4c4eABd5Fb1D1A7234A48692551eAECFF8194CA7, 1e33);
        address tokenIn = 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea;
        address tokenOut = 0xb2f82D0f38dc453D596Ad40A37799446Cc89274A;
        uint24 fees = 100;
        bytes memory b = abi.encodePacked(weth, fees, tokenOut); 
        console2.logBytes(b);
        // 0xf817257fed379853cde0fa4f97ab987181b1e5ea000064760afe86e5de5fa0ee542fc7b7b713e1c5425701000064b2f82d0f38dc453d596ad40a37799446cc89274a
        // 0xf817257fed379853cde0fa4f97ab987181b1e5ea000064760afe86e5de5fa0ee542fc7b7b713e1c5425701000064b2f82d0f38dc453d596ad40a37799446cc89274a
        IUniswapV3Router.ExactInputParams memory swapParams = IUniswapV3Router
            .ExactInputParams({
            path: vm.parseBytes("0x760afe86e5de5fa0ee542fc7b7b713e1c5425701000064b2f82d0f38dc453d596ad40a37799446cc89274a"),
            recipient: 0x8435316b1408D0fF946a46A44BC3188202a37532,
            deadline: 1749449131,
            amountIn: 1e4,
            amountOutMinimum: 0
        });
        {
            // MultipoolCreationParams memory params = MultipoolCreationParams({
            //     name: "MpMonad",
            //     symbol: "MPM",
            //     initialSharePrice: uint96(toX32(0.001e18)),
            //     deviationIncreaseFee: toX16(0.00015e18),
            //     deviationLimit: toX16(3e18),
            //     feeToCashbackRatio: toX16(0.6e18),
            //     baseFee: toX16(0.0001e18),
            //     managementFeeRecepient: deployerPublicKey,
            //     managementFee: toX16(0.15e14),
            //     oracleAddress: address(oracle),
            //     strategyManager: address(0),
            //     assetAddresses: tokensAddresses,
            //     priceData: prices,
            //     targetShares: s,
            //     initialLiquidityAsset: address(0),
            //     nonce: 11,
            //     owner: deployerPublicKey,
            //     protocolFeeReceiver: deployerPublicKey
            // });
            // weth.deposit{value: 1e18}();
            weth.approve(
                address(uniRouter), 1e18
            ); // approve to router
            // weth.transfer(address(mp), 1e18);
            uniRouter.exactInput{
                value: 1e18
            }(swapParams);
            // f.createMultipool(params);
        }

        // updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue,
        // uint128(toX96(10e18))));

        // weth.approve(address(uniRouter), 1e18);
        // swapParams = IUniswapV3Router.ExactInputSingleParams({
        //     tokenIn: address(weth),
        //     tokenOut: tokensAddresses[4],
        //     fee: 100,
        //     recipient: mp,
        //     amountIn: 1e17,
        //     amountOutMinimum: 1,
        //     sqrtPriceLimitX96: 0
        // });
        // uint amountOut = uniRouter.exactInputSingle{value: 1e12}(swapParams);
        OraclePrice memory op;
        // console2.log(amountOut);
        //  Multipool(mp).setFeeParams(
        //     toX16RatioTick(0.0003e5),
        //     toX16RatioTick(0.15e5),
        //     toX16RatioTick(0.6e5),
        //     toX16RatioTick(0.01e5),
        //     deployerPublicKey,
        //     toX16RatioTick(0.1e5)
        // );
        // (uint input, uint output, ,,,,,,,,,,,,,,,,,) = Multipool(mp).estimateSwap(op, mp,
        // tokensAddresses[1], 10e18, false);
        // IERC20(0xb2f82D0f38dc453D596Ad40A37799446Cc89274A).transfer(mp, 1e16);
        // Multipool(mp).swap{value: 1e16}(op, 0xb2f82D0f38dc453D596Ad40A37799446Cc89274A, address(mp), 1e16, true, deployerPublicKey, deployerPublicKey, true);

        // //
        // WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
        // // 1e16);
        // // swapParams = IUniswapV3Router.ExactInputSingleParams({
        // //     tokenIn: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        // //     tokenOut: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84,
        // //     fee: 10000,
        // //     recipient: mp,
        // //     amountIn: 1e16,
        // //     amountOutMinimum: 1,
        // //     sqrtPriceLimitX96: 0
        // // });
        // // amountOut =
        // // IUniswapV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45).exactInputSingle{value:
        // // 1e16}(swapParams);
        // // Multipool(mp).swap{value: 1e16}(op, 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84, mp,
        // // amountOut - 1000, true, rd);
        // swapParams = IUniswapV3Router.ExactInputSingleParams({
        //     tokenIn: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        //     tokenOut: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
        //     fee: 500,
        //     recipient: mp,
        //     amountIn: 1e16,
        //     amountOutMinimum: 1,
        //     sqrtPriceLimitX96: 0
        // });
        // amountOut =
        // IUniswapV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45).exactInputSingle{
        //     value: 1e16
        // }(swapParams);
        // Multipool(mp).swap{value: 1e16}(
        //     op, 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, mp, amountOut, true, rd
        // );
        // WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(
        //     0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, 1e17
        // );
        // swapParams = IUniswapV3Router.ExactInputSingleParams({
        //     tokenIn: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        //     tokenOut: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
        //     fee: 3000,
        //     recipient: mp,
        //     amountIn: 1e17,
        //     amountOutMinimum: 1,
        //     sqrtPriceLimitX96: 0
        // });
        // amountOut =
        // IUniswapV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45).exactInputSingle{
        //     value: 1e17
        // }(swapParams);
        // Multipool(mp).swap{value: 3e17}(
        //     op, 0x514910771AF9Ca656af840dff83E8264EcF986CA, mp, amountOut, true, rd
        // );

        // MockERC20(tokensAddresses[0]).mint(mp, 10e18);

        vm.stopBroadcast();
    }
}

interface IUniswapV3Pool {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;
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

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    )
        external
        view
        returns (address pool);

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    )
        external
        returns (address pool);
}

interface IPositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created
    /// but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function createAndInitializePoolIfNecessary(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint160 sqrtPriceX96
    )
        external
        returns (address pool);
}
