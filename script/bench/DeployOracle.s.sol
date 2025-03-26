// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, toX16, toX16RatioTick, updatePrice} from "../../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=https://arbitrum-sepolia.drpc.org --broadcast
// -vvvv
contract Deploy is Script {
    function run() external {
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        // console.log(deployerPublicKey);
        vm.startBroadcast(deployerPrivateKey);

        Oracle oracleImpl = new Oracle{salt: keccak256(abi.encode("OracleSalt", 1))}();
        ERC1967Proxy oracleProxy = new ERC1967Proxy{value: 1e16}(
            address(oracleImpl),
            abi.encodeWithSignature("initialize(string,string)", "NAME", "SYMBL")
        );
        console.log("oracle ", address(oracleProxy));
        // oracle address 0x224a2AcAB00e97645EA075168b2bf0Ad3124437f
        // new oracle address 0x621e0e380B71Cfe414e8ECeD92A89F25e28c4543

        Multipool mp = Multipool(0x90b1AcD4e333A0fE29D6a90fa77D0c6Cc592c913);

        mp.updateOracleAddress(address(oracleProxy));

        Oracle oracle = Oracle(payable(address(oracleProxy)));
        address o = oracle.owner();
        oracle.updateRewardPerSecond(12);
        oracle.updateStakeLimits(1e18, 20e18, 86400);
        oracle.updateFraudData(false, 1000);

        oracle.toggleOracle(deployerPublicKey);
        vm.stopBroadcast();
    }
}
