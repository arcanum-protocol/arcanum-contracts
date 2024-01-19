// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {UniV3Feed} from "../src/lib/Price.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice} from "../test/MultipoolUtils.t.sol";

contract DeploySpi is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.envAddress("PUBLIC_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Multipool mpImpl = Multipool(0xd47eAbdf744968618046087A7b0985A0e9e4a1Cc);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(mpImpl),
            abi.encodeWithSignature(
                "initialize(string,string,uint128)",
                "Sharp Portfolio Index",
                "SPI",
                uint128(toX96(0.0004e18))
            )
        );
        Multipool mp = Multipool(address(proxy));

        console.log("SPI address: ", address(mp));
        console.log("Instructions address: ", address(mpImpl));

        mp.setAuthorityRights(deployerPublicKey, true, true);
        mp.setSharePriceParams(600, 0);

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
        tokenAddresses[1] = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
        tokenAddresses[2] = address(0x5979D7b546E38E414F7E9822514be443A4800529);

        FeedType[] memory feedTypes = new FeedType[](3);
        feedTypes[0] = FeedType.UniV3;
        feedTypes[1] = FeedType.UniV3;
        feedTypes[2] = FeedType.UniV3;

        bytes[] memory feedData = new bytes[](3);
        feedData[0] = abi.encode(
            UniV3Feed({
                oracle: address(0x2f5e87C9312fa29aed5c179E456625D79015299c),
                reversed: false,
                twapInterval: 60
            })
        );
        feedData[1] = abi.encode(
            UniV3Feed({
                oracle: address(0x641C00A822e8b671738d32a431a4Fb6074E5c79d),
                reversed: true,
                twapInterval: 60
            })
        );
        feedData[2] = abi.encode(
            UniV3Feed({
                oracle: address(0x35218a1cbaC5Bbc3E57fd9Bd38219D37571b3537),
                reversed: false,
                twapInterval: 60
            })
        );

        uint[] memory targetShares = new uint[](3);
        targetShares[0] = 48079;
        targetShares[1] = 34299;
        targetShares[2] = 17621;

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
        //MultipoolRouter router = new MultipoolRouter();

        //console.log("Router address: ", address(router));
        vm.stopBroadcast();
    }
}
