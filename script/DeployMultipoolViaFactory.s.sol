// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {DummyOracle} from "../src/multipool/DummyOracle.sol";
import {MultipoolFactory} from "../src/multipool/Factory.sol";
import {Trader} from "../src/trader/Trader.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, toX16, updatePrice, AbstractFixedValueOracle} from "../test/MultipoolUtils.t.sol";

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
        MockERC20WithDecimals[] memory tokens = new MockERC20WithDecimals[](5);
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

//   token 0  address:  0x1e2278885dD5bf24157839c16A16B1796F5D6471
//   token 1  address:  0x5Bb3a4dd468e9eD1b05D170d8374e090082d9327
//   token 2  address:  0x6d974b13C1a7A3fAEde5D41327D0F9332fAe4BE2
//   token 3  address:  0xAF4ba2A449aF49fd76FCfBfA5309DAF4Ae32A79d
//   token 4  address:  0x5d55a4911e2A8c2CDF0d166977995ce140191e00
//   factory  0x9e63677dA7Aa5BF649ED092832305b38BAa3E78F
//   factoryImpl  0x43d9f09Fe049A29E856c2fAC35A233d0965402AA
        IUniswapV3Factory uf = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        {
            uint8[5] memory decimals = [6,6,18,18,18];
            for (uint i = 0; i < tokens.length; i++) {
                tokens[i] = new MockERC20WithDecimals{salt: keccak256(abi.encode("TokenSalt3", "token", i))}("token", "token", decimals[i]);
                tokens[i].mint(deployerPublicKey, 10000e18);
                console.log("token", i, " address: ", address(tokens[i]));
            }

            tokensAddresses[0] = address(tokens[0]);
            tokensAddresses[1] = address(tokens[1]);
            tokensAddresses[2] = address(tokens[2]);
            tokensAddresses[3] = address(tokens[3]);
            tokensAddresses[4] = address(tokens[4]);
            for (uint i = 0; i < tokensAddresses.length; i++) {
                for (uint y = 0; y < tokensAddresses.length; y++) {
                    if (tokensAddresses[i] == tokensAddresses[y]) {
                        continue;
                    }
                    address pool = uf.getPool(tokensAddresses[i], address(tokens[y]), 3000);
                    // 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
                    if (pool == address(0)) {
                        address newPool = uf.createPool(tokensAddresses[i], tokensAddresses[y], 3000);
                        MockERC20WithDecimals(tokens[i]).approve(0xC36442b4a4522E871399CD717aBDD847Ab11FE88, 1000000000000000000);
                        MockERC20WithDecimals(tokens[y]).approve(0xC36442b4a4522E871399CD717aBDD847Ab11FE88, 5000000000000000000000);
                        IUniswapV3Pool(newPool).initialize(50000000000);
                        IPositionManager.MintParams memory p = IPositionManager.MintParams({
                            token0: tokensAddresses[i],
                            token1: tokensAddresses[y],
                            fee: 3000,
                            tickLower: 84000,
                            tickUpper: 86000,
                            amount0Desired: 12042000000000000,
                            amount1Desired: 12042000000000000,
                            amount0Min: 11000000000000000,
                            amount1Min: 11000000000000000,
                            recipient: deployerPublicKey,
                            deadline: 50000000000
                        });
                        IPositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88).mint(p);
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
        DummyOracle oracle = new DummyOracle{salt: keccak256(abi.encode("DummyOracle"))}(address(0), 0);
        console.log("oracle", address(oracle));

        MultipoolFactory factoryImpl = new MultipoolFactory{salt: keccak256(abi.encode("FACTORYSalt"))}();
        ERC1967Proxy factoryProxy = new ERC1967Proxy{salt: keccak256(abi.encode("FactoryProxy"))}(
            address(factoryImpl),
            ""
        );

        console.log("factory ",  address(factoryProxy));
        console.log("factoryImpl ",  address(factoryImpl));

        MultipoolFactory f = MultipoolFactory(address(factoryProxy));
        f.initialize(deployerPublicKey, address(mpImpl));
        MultipoolFactory.MultipoolCreationParams memory params = MultipoolFactory.MultipoolCreationParams ({
            name: "MpSepolia",
            symbol: "MPS",
            initialSharePrice: uint96(toX32(0.1e18)),

            deviationIncreaseFee: toX16(0.15e18),
            deviationLimit: toX16(0.0003e18),
            feeToCashbackRatio: toX16(0.6e18),
            baseFee: toX16(0.0001e18),
            managementFeeRecepient: deployerPublicKey,
            managementFee: toX16(0.15e18),

            oracleAddress: address(oracle),

            strategyManager: address(0),

            assetAddresses: tokensAddresses,
            priceData: prices,
            targetShares: s
        });
        f.createMultipool(params);
        // get factory nonce
        // Multipool mp = Multipool(address(uint160(uint256(keccak256(abi.encodePacked(address(f), uint(1)))))));
        updatePrice(address(0x141Fe6805f0831C3F88A2B046C63c0cb99923538), address(0x141Fe6805f0831C3F88A2B046C63c0cb99923538), abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18))));
        vm.stopBroadcast();
    }
}

interface IUniswapV3Pool {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;
}


interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);
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
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}