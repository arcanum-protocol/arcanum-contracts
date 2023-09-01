// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //string memory mpName = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        //Multipool mp = new Multipool();

        vm.stopBroadcast();
    }
}
