// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";

// import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
// import {Oracle} from "../../src/multipool/Oracle.sol";
// import {MultipoolFactory, MultipoolCreationParams} from "../../src/multipool/Factory.sol";
// import {Trader} from "../../src/trader/Trader.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
// import {
//     toX96,
//     toX32,
//     toX16,
//     updatePrice,
//     AbstractFixedValueOracle,
// } from "../../test/MultipoolUtils.t.sol";

// forge script ./script/bench/Deploy.s.sol --rpc-url=
// https://arb-sepolia.g.alchemy.com/v2/c_34X8mrHf2CeUbKJyRn9El7loLauTbU --broadcast -vvvv
contract Deploy is Script {
    function toX16(uint val) public pure returns (uint16 valX16) {
        valX16 = uint16((val << 16) / 1e18);
    }

    function toX96(uint val) public pure returns (uint valX96) {
        valX96 = (val << 96) / 1e18;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        uint16[] memory s = new uint16[](3);
        bytes32[] memory prices = new bytes32[](3);
        bytes32[] memory mpPrices = new bytes32[](1);
        address[] memory tokensAddresses = new address[](3);
        address[] memory mpAsset = new address[](1);
        tokensAddresses[0] = address(0x1e2278885dD5bf24157839c16A16B1796F5D6471);
        tokensAddresses[1] = address(0x5Bb3a4dd468e9eD1b05D170d8374e090082d9327);
        tokensAddresses[2] = address(0x6d974b13C1a7A3fAEde5D41327D0F9332fAe4BE2);
        {
            bytes32 val;
            bytes memory data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[0] = val;
            data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(20e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[1] = val;
            mpPrices[0] = val;
            data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(30e18)));
            assembly {
                val := mload(add(data, 32))
            }
            prices[2] = val;
        }

        Multipool mp = Multipool(0x755540A20662419566ED173a5084234dB8317Ae5);
        mpAsset[0] = address(mp);

        MockERC20(tokensAddresses[2]).transfer(address(mp), 1e6);
        OraclePrice memory op;
        mp.swap(
            op,
            tokensAddresses[2],
            tokensAddresses[0],
            1e5,
            true,
            deployerPublicKey,
            deployerPublicKey,
            true
        );

        // uint price =
        // Multipool(0x8a3BDf2870CF7931d2d8AC712367d5437D473148).getPrice(0xb2f82D0f38dc453D596Ad40A37799446Cc89274A);
        // console2.log(price);
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
        // WETH(0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701).deposit{value: 5e18}();
        // uint balance =
        // WETH(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73).balanceOf(deployerPublicKey);
        // console2.log(balance);
        // WETH(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73).transfer(
        //     0x07D966dBA9707a54c7fD0518dc08C84Af0124f34, balance - 1
        // );

        // updatePrice(address(0x057A931a8Ab1111fF163745De18040dc0b35F153),
        //     address(0x057A931a8Ab1111fF163745De18040dc0b35F153),
        //     abi.encodePacked(FeedType.FixedValue, uint128(toX96(1e18)))
        // );
        // updatePrice(address(0xA664650dF459AA696183d8FddeF6597971836763),
        //     address(0x00F26C926345D6F8e1BfCa684873C35070DC49Fd),
        //     abi.encodePacked(FeedType.FixedValue, uint128(toX96(1e16)))
        // );
        vm.stopBroadcast();
    }
}
