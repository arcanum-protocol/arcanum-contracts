// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {UniV3Feed} from "../src/lib/Price.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice} from "../test/MultipoolUtils.t.sol";

contract RemoveAssetQuantity is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("CONTRACT");

        Multipool mp = Multipool(contractAddress);

        vm.startBroadcast(deployerPrivateKey);

        address[] memory tokenAddresses = new address[](6);
        tokenAddresses[0] = address(0x51fC0f6660482Ea73330E414eFd7808811a57Fa2);
        tokenAddresses[1] = address(0x0341C0C0ec423328621788d4854119B97f44E391);
        tokenAddresses[2] = address(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8);
        tokenAddresses[3] = address(0x539bdE0d7Dbd336b79148AA742883198BBF60342);
        tokenAddresses[4] = address(0x3082CC23568eA640225c2467653dB90e9250AaA0);
        tokenAddresses[5] = address(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);

        uint[] memory targetShares = new uint[](6);
        targetShares[0] = 0;
        targetShares[1] = 0;
        targetShares[2] = 1;
        targetShares[3] = 1;
        targetShares[4] = 1;
        targetShares[5] = 1;

        mp.updateTargetShares(tokenAddresses, targetShares);

        vm.stopBroadcast();
    }
}

contract UpdateTargetShares is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("CONTRACT");

        Multipool mp = Multipool(contractAddress);

        vm.startBroadcast(deployerPrivateKey);

        address[] memory tokenAddresses = new address[](6);
        tokenAddresses[0] = address(0x51fC0f6660482Ea73330E414eFd7808811a57Fa2);
        tokenAddresses[1] = address(0x0341C0C0ec423328621788d4854119B97f44E391);
        tokenAddresses[2] = address(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8);
        tokenAddresses[3] = address(0x539bdE0d7Dbd336b79148AA742883198BBF60342);
        tokenAddresses[4] = address(0x3082CC23568eA640225c2467653dB90e9250AaA0);
        tokenAddresses[5] = address(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);

        uint[] memory targetShares = new uint[](6);
        targetShares[0] = 0;
        targetShares[1] = 0;
        targetShares[2] = 1;
        targetShares[3] = 1;
        targetShares[4] = 1;
        targetShares[5] = 1;

        mp.updateTargetShares(tokenAddresses, targetShares);

        vm.stopBroadcast();
    }
}

contract DeployArbi is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.envAddress("PUBLIC_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Multipool mpImpl = new Multipool{salt: keccak256(abi.encode("MultipoolSalt", 1))}();
        ERC1967Proxy proxy = new ERC1967Proxy{salt: keccak256(abi.encode("ProxySalt", 1))}(
            address(mpImpl),
            abi.encodeWithSignature(
                "initialize(string,string,uint128)",
                "Index",
                "ETF",
                uint128(toX96(0.00069e18))
            )
        );
        Multipool mp = Multipool(address(proxy));

        address[] memory tokenAddresses = new MockERC20WithDecimals[](6);
        uint8[5] memory decimals = [6,6,18,18,18,18];
        for (uint i; i < tokens.length; i++) {
            salt = keccak256(abi.encode("TokenSalt", "token", i));
            tokens[i] = new MockERC20WithDecimals{salt: salt}("token", "token", decimals[i]);
            tokens[i].mint(deployer, 10000e18);
            console.log("token", i, " address: ", address(tokens[i]));
        }

        console.log("Proxy address: ", address(mp));
        console.log("Etf address: ", address(mpImpl));

        mp.setAuthorityRights(deployerPublicKey, true, true);
        mp.setSharePriceParams(600, 0);


        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(tokenAddresses, s);
        AssetArgs[] memory args = new AssetArgs[](6);

        uint quoteSum;

        for (uint i = 0; i < t.length; i++) {
            quoteSum += quoteValues[i];
            uint val = (quoteValues[i] << 96) / p[i];
            updatePrice(address(mp), address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
            if (val > 0) {
                tokens[i].mint(address(mp), val);
            }
            args[i] = AssetArgs({assetAddress: address(tokens[i]), amount: int(val)});
        }

        // insert adapter for token 1 here
        address priceAdapter10 = address(new AbstractFixedValueOracle(p[0]));

        address[] memory priceAdapterAddresses = new address[](2);
        
        priceAdapterAddresses[0] = address(tokens[0]);
        priceAdapterAddresses[1] = address(tokens[1]);
        FeedType[] memory priceAdapterType = new FeedType[](2);
        priceAdapterType[0] = FeedType.Adapter;
        priceAdapterType[1] = FeedType.FixedValue;
        bytes[] memory priceAdapterBytes = new bytes[](2);
        priceAdapterBytes[0] = abi.encode(priceAdapter10, uint(10000000000000000123212));
        priceAdapterBytes[1] = abi.encode(p[1]);
        mp.updatePrices(priceAdapterAddresses, priceAdapterType, priceAdapterBytes);

        args[5] =
            AssetArgs({assetAddress: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))});

        args = sort(args);

        ForcePushArgs memory fp;
        mp.setFeeParams(
            toX32(0.15e18), toX32(0.0003e18), toX32(0.6e18), toX32(0.01e18), toX32(0.1e18), users[2]
        );

 
        uint[] memory targetShares = new uint[](6);
        targetShares[0] = 2000;
        targetShares[1] = 960;
        targetShares[2] = 352;
        targetShares[3] = 3600;
        targetShares[4] = 264;
        targetShares[5] = 448;

        mp.updatePrices(tokenAddresses, feedTypes, feedData);
        mp.updateTargetShares(tokenAddresses, targetShares);

        mp.setFeeParams(
            toX32(0.15e18),
            toX32(0.0003e18),
            toX32(0.6e18),
            toX32(0.0001e18),
            toX32(0.15e18),
            deployerPublicKey
        );
        MultipoolRouter router = new MultipoolRouter();

        console.log("Router address: ", address(router));
        vm.stopBroadcast();
    }
}
