// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {MultipoolFactory, MultipoolCreationParams} from "../../src/multipool/Factory.sol";
import {Trader} from "../../src/trader/Trader.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {
    toX96,
    toX32,
    toX16,
    updatePrice,
    AbstractFixedValueOracle,
    computeContractAddress
} from "../../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=127.0.0.1:8545 --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        Multipool mp = new Multipool();

        MultipoolFactory mpF = new MultipoolFactory();
        MultipoolFactory oldF =  MultipoolFactory(0x7eFe6656d08f2d6689Ed8ca8b5A3DEA0efaa769f);
        console2.log(oldF.owner());
        console2.log(deployerPublicKey);
        oldF.updateImplementationAddress(address(mp));
        oldF.upgradeTo(address(mpF));

        vm.stopBroadcast();
    }
}
