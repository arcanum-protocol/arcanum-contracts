// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {DummyOracle} from "../src/multipool/DummyOracle.sol";
import {MultipoolFactory} from "../src/multipool/Factory.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, toX16, updatePrice, AbstractFixedValueOracle} from "../../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=127.0.0.1:8545 --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);

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

        {
            uint8[5] memory decimals = [6,6,18,18,18];
            for (uint i = 0; i < tokens.length; i++) {
                tokens[i] = new MockERC20WithDecimals{salt: keccak256(abi.encode("TokenSalt", "token", i))}("token", "token", decimals[i]);
                tokens[i].mint(deployerPublicKey, 10000e18);
                console.log("token", i, " address: ", address(tokens[i]));
            }

            tokensAddresses[0] = address(tokens[0]);
            tokensAddresses[1] = address(tokens[1]);
            tokensAddresses[2] = address(tokens[2]);
            tokensAddresses[3] = address(tokens[3]);
            tokensAddresses[4] = address(tokens[4]);

            s[0] = 10;
            s[1] = 10;
            s[2] = 10;
            s[3] = 10;
            s[4] = 10;
        }

        Multipool mpImpl = new Multipool{salt: keccak256(abi.encode("MultipoolSalt"))}();
        DummyOracle oracle = new DummyOracle{salt: keccak256(abi.encode("DummyOracle"))}(address(0), 0);


        MultipoolFactory factoryImpl = new MultipoolFactory{salt: keccak256(abi.encode("FACTORYSalt"))}();
        ERC1967Proxy factoryProxy = new ERC1967Proxy{salt: keccak256(abi.encode("FactoryProxy"))}(
            address(factoryImpl),
            ""
        );

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

        vm.stopBroadcast();
    }
}
