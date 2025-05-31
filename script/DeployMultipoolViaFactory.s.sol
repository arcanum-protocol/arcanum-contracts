// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {Oracle} from "../src/multipool/Oracle.sol";
import {MultipoolFactory, MultipoolCreationParams} from "../src/multipool/Factory.sol";
import {Trader} from "../src/trader/Trader.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {
    toX96,
    toX32,
    toX16,
    updatePrice,
    AbstractFixedValueOracle,
    computeContractAddress
} from "../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=127.0.0.1:8545 --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);
        {
            Trader trader = new Trader{salt: keccak256(abi.encode("Trader"))}();
            console.log("trader ", address(trader));
        }
        // MockERC20WithDecimals[] memory tokens = new MockERC20WithDecimals[](5);
        uint16[] memory s = new uint16[](5);
        bytes32[] memory prices = new bytes32[](5);
        address[] memory tokensAddresses = new address[](5);

        {
            bytes32 val;
            bytes memory data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[0] = val;
            data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(20e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[1] = val;
            data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(30e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[2] = val;
            data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(25e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[3] = val;
            data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(1e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[4] = val;
        }

        address positionManager = 0x6b2937Bde17889EDCf8fbD8dE31C3C2a70Bc4d65;

        // IUniswapV3Factory uf = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        IUniswapV3Factory uf = IUniswapV3Factory(0x248AB79Bbb9bC29bB72f7Cd42F17e054Fc40188e);
        {
            // uint8[5] memory decimals = [6, 6, 18, 18, 18];
            // for (uint i = 0; i < tokens.length; i++) {
            //     tokens[i] = new MockERC20WithDecimals{
            //         salt: keccak256(abi.encode("TokenSalt3", "token", i))
            //     }("token", "token", decimals[i]);
            //     tokens[i].mint(deployerPublicKey, 10000e30);
            //     console.log("token", i, " address: ", address(tokens[i]));
            // }

            tokensAddresses[0] = address(0xCdFE37e195d98d3C8C669C56a70C418327F17B5f);
            tokensAddresses[1] = address(0x97f959ff7C81B91CCa5253241f4F585C35b8fd5E);
            tokensAddresses[2] = address(0x7d6190956Bd55B17524662E7F42f140C403b5c4F);
            tokensAddresses[3] = address(0x74621BB03a08612D1Ba28563E7dDf8BC43B3Fc50);
            tokensAddresses[4] = address(0xF1B9706661a8b14AF90E1e756a84Bcef650160BB);
            for (uint i = 0; i < tokensAddresses.length; i++) {
                for (uint y = 0; y < tokensAddresses.length; y++) {
                    if (tokensAddresses[i] == tokensAddresses[y]) {
                        continue;
                    }
                    (address token0, address token1) = tokensAddresses[i] < tokensAddresses[y]
                        ? (tokensAddresses[i], tokensAddresses[y])
                        : (tokensAddresses[y], tokensAddresses[i]);
                    address pool = uf.getPool(token0, token1, 3000);
                    // 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
                    if (pool == address(0)) {
                        // address newPool =
                        //     uf.createPool(token0, token1, 3000);
                        // IUniswapV3Pool(newPool).initialize(50000000000);
                        IPositionManager(positionManager).createAndInitializePoolIfNecessary(
                            token0, token1, 3000, 50000000000
                        );
                        MockERC20WithDecimals(tokensAddresses[i]).approve(positionManager, 10000e30);
                        MockERC20WithDecimals(tokensAddresses[y]).approve(positionManager, 10000e30);
                        IPositionManager.MintParams memory p = IPositionManager.MintParams({
                            token0: token0,
                            token1: token1,
                            fee: 3000,
                            tickLower: 81000,
                            tickUpper: 90000,
                            amount0Desired: 12042000000000000,
                            amount1Desired: 12042000000000000,
                            amount0Min: 0,
                            amount1Min: 0,
                            recipient: deployerPublicKey,
                            deadline: block.timestamp + 1000
                        });
                        IPositionManager(positionManager).mint{value: 1e16}(p);
                        // newPool.mint(deployerPublicKey, 0, 1, 12042000000000000, "");
                    }
                }
            }

            s[0] = 10;
            s[1] = 10;
            s[2] = 10;
            s[3] = 10;
            s[4] = 10;
        }

        Multipool mpImpl = new Multipool{salt: keccak256(abi.encode("MultipoolSalt"))}();
        Oracle oracle = new Oracle{salt: keccak256(abi.encode("Oracle"))}();
        console.log("oracle", address(oracle));

        MultipoolFactory factoryImpl =
            new MultipoolFactory{salt: keccak256(abi.encode("FACTORYSalt"))}();
        ERC1967Proxy factoryProxy =
            new ERC1967Proxy{salt: keccak256(abi.encode("FactoryProxy"))}(address(factoryImpl), "");

        console.log("factory ", address(factoryProxy));
        console.log("factoryImpl ", address(factoryImpl));

        MultipoolFactory f = MultipoolFactory(address(factoryProxy));

        address mp = computeContractAddress(address(f), address(mpImpl), 1, deployerPublicKey);
        console.log("mp ", mp);

        IUniswapV3Router.ExactInputSingleParams memory swapParams = IUniswapV3Router
            .ExactInputSingleParams({
            tokenIn: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            tokenOut: 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE,
            fee: 500,
            recipient: mp,
            amountIn: 1e14,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });
        {
            f.initialize(deployerPublicKey, address(mpImpl));

            MultipoolCreationParams memory params = MultipoolCreationParams({
                name: "MpSepolia",
                symbol: "MPS",
                deviationIncreaseFee: toX16(0.15e18),
                deviationLimit: toX16(0.0003e18),
                feeToCashbackRatio: toX16(0.6e18),
                baseFee: toX16(0.0001e18),
                lpFee: toX16(0.0001e18),
                _managerFeeReceiver: deployerPublicKey,
                _lpFeeReceiver: deployerPublicKey,
                managerFee: toX16(0.15e18),
                oracleAddress: address(oracle),
                assetAddresses: tokensAddresses,
                priceData: prices,
                targetShares: s,
                initialLiquidityAsset: 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE,
                nonce: 1,
                owner: deployerPublicKey,
                protocolFeeReceiver: address(0)
            });
            WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).deposit{value: 10e18}();
            WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(
                0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, 1e14
            );
            // WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).transfer(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
            // 1e14);
            IUniswapV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45).exactInputSingle{
                value: 1e14
            }(swapParams);
            f.createMultipool(params);
        }

        updatePrice(mp, mp, abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18))));

        // WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(
        //     0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, 1e14
        // );
        // swapParams = IUniswapV3Router.ExactInputSingleParams({
        //     tokenIn: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        //     tokenOut: 0xB8c77482e45F1F44dE1745F52C74426C631bDD52,
        //     fee: 3000,
        //     recipient: mp,
        //     amountIn: 1e14,
        //     amountOutMinimum: 1,
        //     sqrtPriceLimitX96: 0
        // });
        // uint amountOut = IUniswapV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45)
        //     .exactInputSingle{value: 1e14}(swapParams);
        // OraclePrice memory op;
        // ReceiverData memory rd = ReceiverData({
        //     receiverAddress: deployerPublicKey,
        //     refundAddress: deployerPublicKey,
        //     refundEthToReceiver: true
        // });
        // Multipool(mp).swap{value: 1e15}(
        //     op, 0xB8c77482e45F1F44dE1745F52C74426C631bDD52, mp, amountOut, true, rd
        // );

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
