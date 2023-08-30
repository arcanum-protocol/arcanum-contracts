// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";

contract DeployERC20 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //string memory name = vm.envUint("NAME")
        //string memory symbol = vm.envUint("SYMBOL")
        vm.startBroadcast(deployerPrivateKey);

        //MockERC20 mp = new MockERC20();

        vm.stopBroadcast();
    }
}
