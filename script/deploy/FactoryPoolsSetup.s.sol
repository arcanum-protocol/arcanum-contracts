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
        MultipoolRouter router = new MultipoolRouter(0x7eFe6656d08f2d6689Ed8ca8b5A3DEA0efaa769f);
        console.log("router ", address(router));

        // {
        //     Trader trader = new Trader{salt: keccak256(abi.encode("Trader1"))}();
        //     console.log("trader ", address(trader));
        // }
        // uint16[] memory s = new uint16[](5);
        // bytes32[] memory prices = new bytes32[](5);
        // address[] memory tokensAddresses = new address[](5);
        // MockERC20WithDecimals[] memory tokens = new MockERC20WithDecimals[](5);
        // {
        //     bytes32 val;
        //     bytes memory data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18)));
        //     assembly {
        //         val := mload(add(data, 32))
        //     }
        //     prices[0] = val;
        //     data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(20e18)));
        //     assembly {
        //         val := mload(add(data, 32))
        //     }
        //     prices[1] = val;
        //     data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(30e18)));
        //     assembly {
        //         val := mload(add(data, 32))
        //     }
        //     prices[2] = val;
        //     data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(25e18)));
        //     assembly {
        //         val := mload(add(data, 32))
        //     }
        //     prices[3] = val;
        //     data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(1e18)));
        //     assembly {
        //         val := mload(add(data, 32))
        //     }
        //     prices[4] = val;
        // }

        // sepolia arb
        // address positionManager = 0x6b2937Bde17889EDCf8fbD8dE31C3C2a70Bc4d65;

        // monad
        // address positionManager = 0x3dCc735C74F10FE2B9db2BB55C40fbBbf24490f7;

        // address factory = IPositionManager(positionManager).factory();
        // console2.log("uniswap factory", factory);

        // IUniswapV3Factory uf = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        // IUniswapV3Factory uf = IUniswapV3Factory(0x961235a9020B05C44DF1026D956D1F4D78014276);
        // {
        //     uint8[5] memory decimals = [6, 6, 18, 18, 18];
        //     for (uint i = 0; i < tokens.length; i++) {
        //         tokens[i] = new MockERC20WithDecimals{
        //             salt: keccak256(abi.encode("TokenSalt", "token", i))
        //         }("token", "token", decimals[i]);
        //         tokens[i].mint(deployerPublicKey, 10000e30);
        //         console.log("token", i, " address: ", address(tokens[i]));
        //     }
        //     tokensAddresses[0] = address(tokens[0]);
        //     tokensAddresses[1] = address(tokens[1]);
        //     tokensAddresses[2] = address(tokens[2]);
        //     tokensAddresses[3] = address(tokens[3]);
        //     tokensAddresses[4] = address(tokens[4]);
        //     for (uint i = 0; i < tokensAddresses.length; i++) {
        //         for (uint y = 0; y < tokensAddresses.length; y++) {
        //             if (tokensAddresses[i] == tokensAddresses[y]) {
        //                 continue;
        //             }
        //             (address token0, address token1) = tokensAddresses[i] < tokensAddresses[y] ?
        //     (tokensAddresses[i], tokensAddresses[y]) : (tokensAddresses[y], tokensAddresses[i]);
        //             address pool = uf.getPool(token0, token1, 3000);
        //             if (pool == address(0)) {
        //                 IPositionManager(positionManager).createAndInitializePoolIfNecessary(token0,
        //     token1, 3000, 50000000000);
        //                 MockERC20WithDecimals(tokensAddresses[i]).approve(
        //                     positionManager, 10000e30
        //                 );
        //                 MockERC20WithDecimals(tokensAddresses[y]).approve(
        //                     positionManager, 10000e30
        //                 );
        //                 IPositionManager.MintParams memory p = IPositionManager.MintParams({
        //                     token0: token0,
        //                     token1: token1,
        //                     fee: 3000,
        //                     tickLower: 81000,
        //                     tickUpper: 90000,
        //                     amount0Desired: 12042000000000000,
        //                     amount1Desired: 12042000000000000,
        //                     amount0Min: 0,
        //                     amount1Min: 0,
        //                     recipient: deployerPublicKey,
        //                     deadline: block.timestamp + 1000
        //                 });
        //                 IPositionManager(positionManager).mint{value: 1e16}(p);
        //             }
        //         }
        //     }

        //     // s[0] = 10;
        //     // s[1] = 10;
        //     // s[2] = 10;
        //     // s[3] = 10;
        //     // s[4] = 10;
        // }
        // console.log("right before");
        // Multipool mpImpl = new Multipool{salt: keccak256(abi.encode("MultipoolSalt1"))}();
        // console.log("mp impl", address(mpImpl));
        // Oracle oracle =
        //     new Oracle{salt: keccak256(abi.encode("Oracle"))}();
        // console.log("oracle", address(oracle));

        // MultipoolFactory factoryImpl =
        //     new MultipoolFactory{salt: keccak256(abi.encode("FACTORYSalt1"))}();
        // ERC1967Proxy factoryProxy =
        //     new ERC1967Proxy{salt: keccak256(abi.encode("FactoryProxy1"))}(address(factoryImpl),
        // "");

        // console.log("factory ", address(factoryProxy));
        // console.log("factoryImpl ", address(factoryImpl));

        // MultipoolFactory f = MultipoolFactory(address(factoryProxy));
        // // // arb sepolia
        // // WETH weth = WETH(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73);
        // // IUniswapV3Router uniRouter =
        // IUniswapV3Router(0x101F443B4d1b059569D643917553c771E1b9663E);
        // f.initialize(deployerPublicKey, address(mpImpl));

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
    function factory() external view returns (address);

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
