// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import {MockERC20} from "../src/mocks/erc20.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32} from "../test/MultipoolUtils.t.sol";

contract DeployTestnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.envAddress("PUBLIC_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Multipool mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(mpImpl), "");
        Multipool mp = Multipool(address(proxy));
        mp.initialize("Exchange tradable fund", "ETF", deployerPublicKey, toX96(0.1e18));
        console.log("multipool address: ", address(mp));

        MockERC20[] memory tokens = new MockERC20[](5);
        for (uint i; i < tokens.length; i++) {
            tokens[i] = new MockERC20('token', 'token', 0);
            tokens[i].mint(deployerPublicKey, 100e18);
            uint price = (i + 1) * 0.01e18;
            mp.updatePrice(address(tokens[i]), FeedType.FixedValue, abi.encode(price));
            address[] memory tk = new address[](1);
            tk[0] = address(tokens[i]);
            uint[] memory am = new uint[](1);
            am[0] = 10e18;
            mp.updateTargetShares(tk, am);
            console.log("token", i, " address: ", address(tokens[i]));
            console.log("token", i, " price: ", price);
        }
        mp.setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.6e18), toX32(0.0001e18));
        vm.stopBroadcast();
    }
}
