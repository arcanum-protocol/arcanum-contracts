// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/Factory.sol";
import "../src/farm/Farm.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {Multicall3} from "../src/mocks/multicall.sol";
import {UniV3Feed} from "../src/lib/Price.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice} from "../test/MultipoolUtils.t.sol";

contract DeployTestEnv is Script {
    function run() external {
        // test deployer private key
        uint256 pkey = uint(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        address deployer = vm.addr(pkey);

        vm.startBroadcast(pkey);

        bytes32 salt = keccak256(abi.encode("chipipi", 1));
        console.log("salt", uint(salt));

        console.log(
            "creation code", uint(keccak256(abi.encodePacked(type(Multipool).creationCode)))
        );

        Multipool mpImpl = new Multipool{salt: salt}();
        console.log("mp impl", address(mpImpl));

        {
            salt = keccak256(abi.encode("chipi daba", 1));
            MultipoolFactory factoryImpl = new MultipoolFactory{salt: salt}();
            console.log("factory impl", address(factoryImpl));
            salt = keccak256(abi.encode("chipi chipi", 1));
            ERC1967Proxy factoryProxy = new ERC1967Proxy{salt: salt}(address(factoryImpl), "");
            MultipoolFactory factory = MultipoolFactory(address(factoryProxy));
            factory.initialize(deployer, address(mpImpl));
            console.log("factory ", address(factory));
        }

        salt = keccak256(abi.encode("chipi chipi"));
        Multicall3 multicall = new Multicall3{salt: salt}();
        console.log(address(multicall));

        ERC1967Proxy proxy =
            new ERC1967Proxy{salt: keccak256(abi.encode("chapa chapa"))}(address(mpImpl), "");
        Multipool mp = Multipool(address(proxy));
        mp.initialize("Exchange tradable fund", "ETF", uint128(toX96(0.1e18)));
        console.log("mp ", address(mp));

        mp.setAuthorityRights(deployer, true, true);
        mp.setSharePriceParams(600, 0);

        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
        MockERC20[] memory tokens = new MockERC20[](5);
        for (uint i; i < tokens.length; i++) {
            salt = keccak256(abi.encode("chapa chapa", "token", i));
            tokens[i] = new MockERC20{salt: salt}("token", "token", 0);
            tokens[i].mint(deployer, 100e18);
            uint price = toX96((i + 1) * 0.01e18);
            updatePrice(address(mp), address(tokens[i]), FeedType.FixedValue, abi.encode(price));
            address[] memory tk = new address[](1);
            tk[0] = address(tokens[i]);
            uint[] memory am = new uint[](1);
            am[0] = 10e18;
            mp.updateTargetShares(tk, am);
            console.log("token", i, " address: ", address(tokens[i]));
            console.log("token", i, " price: ", price);
        }
        mp.setFeeParams(
            toX32(0.15e18),
            toX32(0.0003e18),
            toX32(0.6e18),
            toX32(0.0001e18),
            toX32(0.15e18),
            deployer
        );

        vm.stopBroadcast();
    }
}

contract DeployEtfWithFactory is Script {
    function run() external {
        // test deployer private key
        uint256 pkey = uint(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        address deployer = vm.addr(pkey);
        MultipoolFactory factory = MultipoolFactory(0xAfef20a6b3e05d6bc9b9541d9BF692E7914406F0);

        vm.startBroadcast(pkey);

        address[] memory oracleAddresses = new address[](1);
        oracleAddresses[0] = deployer;

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(0x65177a42ce789f8111C879Bd53e96DEBED63c685);
        assetAddresses[1] = address(0x3a822B7099a4D43099D26A2A5de655692F854fc0);

        FeedType[] memory priceFeedKinds = new FeedType[](2);
        priceFeedKinds[0] = FeedType.FixedValue;
        priceFeedKinds[1] = FeedType.FixedValue;

        bytes[] memory feedData = new bytes[](2);
        feedData[0] = abi.encode(toX96(0.1e18));
        feedData[1] = abi.encode(toX96(0.5e18));

        uint[] memory targetShares = new uint[](2);
        targetShares[0] = 2;
        targetShares[1] = 1;

        factory.spawnMultipool(
            MultipoolFactory.MultipoolSetupArgs({
                name: "Test",
                symbol: "TEST",
                signatureThershold: 1,
                sharePriceValidity: 600,
                initialSharePrice: toX32(1e18),
                deviationLimit: toX32(0.15e18),
                halfDeviationFee: toX32(0.003e18),
                depegBaseFee: toX32(0.3e18),
                baseFee: toX32(0.01e18),
                developerBaseFee: toX32(0.01e18),
                developerAddress: deployer,
                oracleAddresses: oracleAddresses,
                assetAddresses: assetAddresses,
                priceFeedKinds: priceFeedKinds,
                feedData: feedData,
                targetShares: targetShares
            })
        );

        vm.stopBroadcast();
    }
}
