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
        // address[] memory tokensAddresses = new address[](4);

        //     // tokensAddresses[0] = address(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73);
        //     tokensAddresses[0] = address(0x97f959ff7C81B91CCa5253241f4F585C35b8fd5E);
        //     tokensAddresses[1] = address(0x7d6190956Bd55B17524662E7F42f140C403b5c4F);
        //     tokensAddresses[2] = address(0x74621BB03a08612D1Ba28563E7dDf8BC43B3Fc50);
        //     tokensAddresses[3] = address(0xF1B9706661a8b14AF90E1e756a84Bcef650160BB);
        // // console.log(deployerPublicKey);
        // vm.startBroadcast(deployerPrivateKey);
        // address user = 0x07D966dBA9707a54c7fD0518dc08C84Af0124f34;
        // for (uint i = 0; i < tokensAddresses.length; i++) {
        //     MockERC20WithDecimals(tokensAddresses[i]).mint(user, 1000e18);
        // }
        // WETH(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73).deposit{value: 1e17}();
        uint balance = WETH(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73).balanceOf(deployerPublicKey);
        console2.log(balance);
        WETH(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73).transfer(
            0x07D966dBA9707a54c7fD0518dc08C84Af0124f34, balance - 1
        );

        // updatePrice(address(0x46489e10E6E78EAFE087fde1Bc74e745182a2Eab),
        // address(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73),
        // abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18))));
        vm.stopBroadcast();
    }
}
