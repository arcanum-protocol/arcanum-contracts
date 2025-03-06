// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import "forge-std/Script.sol";
import {Multipool} from "../src/multipool/Multipool.sol";
import {OraclePrice} from "../src/types/OraclePrice.sol";
import {ReceiverData} from "../src/types/ReceiverData.sol";

contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);
        address tokenAddress = 0x1e2278885dD5bf24157839c16A16B1796F5D6471;
        OraclePrice memory op;
        ReceiverData memory rd = ReceiverData({
            receiverAddress: deployerPublicKey,
            refundAddress: deployerPublicKey,
            refundEthToReceiver: true
        });
        Multipool(0xC6f70B36C5B54BFf3C508FBb2F16331Dfae84Cea).swap{value: 1e17}(op, tokenAddress, 0xC6f70B36C5B54BFf3C508FBb2F16331Dfae84Cea, 10e18, true, rd);
        vm.stopBroadcast();
    }
}

