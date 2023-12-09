// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {UniV3Feed} from "../src/lib/Price.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice} from "../test/MultipoolUtils.t.sol";

contract DeployArbi is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.envAddress("PUBLIC_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Multipool mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(mpImpl),
            abi.encodeWithSignature(
                "initialize(string,string,uint128)",
                "Arbitrum Ecosystem Index",
                "ARBI",
                uint128(toX96(0.00069e18))
            )
        );
        Multipool mp = Multipool(address(proxy));

        console.log("ARBI address: ", address(mp));
        console.log("Instructions address: ", address(mpImpl));

        mp.setAuthorityRights(deployerPublicKey, true, true);
        mp.setSharePriceValidityDuration(600);

        address[] memory tokenAddresses = new address[](6);
        tokenAddresses[0] = address(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);
        tokenAddresses[1] = address(0x3082CC23568eA640225c2467653dB90e9250AaA0);
        tokenAddresses[2] = address(0x0341C0C0ec423328621788d4854119B97f44E391);
        tokenAddresses[3] = address(0x95146881b86B3ee99e63705eC87AfE29Fcc044D9);
        tokenAddresses[4] = address(0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8);
        tokenAddresses[5] = address(0x51fC0f6660482Ea73330E414eFd7808811a57Fa2);

        FeedType[] memory feedTypes = new FeedType[](6);
        feedTypes[0] = FeedType.UniV3;
        feedTypes[1] = FeedType.UniV3;
        feedTypes[2] = FeedType.UniV3;
        feedTypes[3] = FeedType.UniV3;
        feedTypes[4] = FeedType.UniV3;
        feedTypes[5] = FeedType.UniV3;

        bytes[] memory feedData = new bytes[](6);
        feedData[0] = abi.encode(
            UniV3Feed({
                oracle: address(0x1aEEdD3727A6431b8F070C0aFaA81Cc74f273882),
                reversed: true,
                twapInterval: 60
            })
        );
        feedData[1] = abi.encode(
            UniV3Feed({
                oracle: address(0x446BF9748B4eA044dd759d9B9311C70491dF8F29),
                reversed: false,
                twapInterval: 60
            })
        );
        feedData[2] = abi.encode(
            UniV3Feed({
                oracle: address(0xd3E11119d2680c963F1CDCffeCe0c4adE823Fb58),
                reversed: false,
                twapInterval: 60
            })
        );
        feedData[3] = abi.encode(
            UniV3Feed({
                oracle: address(0x1eE25aDA6ee9Aa7B2c56d05DAb5Be476752605Fd),
                reversed: true,
                twapInterval: 60
            })
        );
        feedData[4] = abi.encode(
            UniV3Feed({
                oracle: address(0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c),
                reversed: false,
                twapInterval: 60
            })
        );
        feedData[5] = abi.encode(
            UniV3Feed({
                oracle: address(0x4d834a9b910E6392460eBcfB59F8EEf27D5c19Ff),
                reversed: false,
                twapInterval: 60
            })
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
