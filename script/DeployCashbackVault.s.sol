// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/cashback-vault/CashbackVault.sol";
import "../src/tokens/points.sol";
import "../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {UniV3Feed} from "../src/lib/Price.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice} from "../test/MultipoolUtils.t.sol";

contract MigrateCashbackVault is Script {
    function run() external {
        // test deployer private key
        uint256 pkey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pkey);
        CashbackVault vaultImpl = new CashbackVault();
        CashbackVault vault = CashbackVault(0xB9cb365F599885F6D97106918bbd406FE09b8590);
        vault.upgradeTo(address(vaultImpl));

        vm.stopBroadcast();
    }
}

contract DeployCashbackVault is Script {
    function run() external {
        // test deployer private key
        uint256 pkey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pkey);

        vm.startBroadcast(pkey);

        CashbackVault vaultImpl = new CashbackVault();
        bytes32 vaultSalt = keccak256(abi.encode("dubi dubi"));

        CashbackVault vault = CashbackVault(
            address(
                new ERC1967Proxy{salt: vaultSalt}(
                    address(vaultImpl), abi.encodeWithSignature("initialize(address)", deployer)
                )
            )
        );

        console.log("cashback vault", address(vault));
        console.log("cashback vault impl", address(vaultImpl));
        console.log("deployer", address(deployer));

        vm.stopBroadcast();
    }
}
