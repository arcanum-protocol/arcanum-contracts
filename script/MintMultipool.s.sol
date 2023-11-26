// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import {MockERC20} from "../src/mocks/erc20.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96} from "../test/MultipoolUtils.t.sol";

contract MintMultipool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.envAddress("PUBLIC_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address token = vm.envAddress("TOKEN");
        address multipool = vm.envAddress("MULTIPOOL");

        Multipool mp = Multipool(multipool);
        MockERC20 t = MockERC20(token);

        MpAsset memory asset = mp.getAsset(token);

        Multipool.AssetArg[] memory a = new Multipool.AssetArg[](2);
        a[0] = Multipool.AssetArg({
            addr: address(t),
            amount: 10e18
        });
        a[1] = Multipool.AssetArg({
            addr: address(t),
            amount: -10e18
        });

        t.mint(multipool, 10e18);
        //mp.swap(a);
        vm.stopBroadcast();
    }
}
