// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {UniV3Feed} from "../../src/lib/Price.sol";
import {Staker} from "../../src/multipool/Staker.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice, AbstractFixedValueOracle, toX16RatioTick} from "../../test/MultipoolUtils.t.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract Swap is Script {
    using ECDSA for bytes32;

    Multipool mp;

    function mintAndUpdateToken(address token, uint quote, uint p) internal {

    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        mp = Multipool(address(0x26d58226d328FafD7ab72C234783E898191e6484));

        address[5] memory tokens = [
            0xDF4d4Af5C8Feb45c08856a8A016B6CB0b86b8810, 
            0xABd7D864420583a317a873BceDf6481D157828Ea, 
            0xAc8AFD9B3A775Ddb79Ce83F1Cd18114D7B6809e3,
            0xca3b3F1ae22c71eCdC6fBf36998507099fF7dfFc,
            0x5FF153F54E541a67eA78b5Ab8e69E8f6F5CAB82C
        ];
        uint[5] memory quotes = [uint(400e18), 300e18, 400e18, 300e18, 300e18];

        uint[5] memory p = [toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18), toX96(10e18)];
        mp.setFeeParams(toX16RatioTick(1e5), 0, 0, 0, 0, address(0));
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18))));
        AssetArgs[] memory args = new AssetArgs[](6);

        uint quoteSum = 1700e18;
        {
            for (uint i; i < tokens.length; i++) {
                uint val = (quotes[i] << 96) / p[i];
                updatePrice(address(mp), tokens[i], abi.encodePacked(FeedType.FixedValue, uint128(p[i])));
                if (val > 0) {
                    MockERC20WithDecimals(tokens[i]).mint(address(mp), val);
                }
                args[i] = AssetArgs({assetAddress: tokens[i], amount: int(val)});
            }
        }
        {
            address priceAdapter10 = address(new AbstractFixedValueOracle(p[0]));

            address[] memory priceAdapterAddresses = new address[](2);
            priceAdapterAddresses[0] = address(tokens[0]);
            priceAdapterAddresses[1] = address(tokens[1]);
            bytes[] memory priceAdapterBytes = new bytes[](2);
            priceAdapterBytes[0] = abi.encode(FeedType.Adapter, priceAdapter10, uint64(10000123212));
            priceAdapterBytes[1] = abi.encode(FeedType.FixedValue, p[1]);
            updatePrice(address(mp), address(tokens[0]), abi.encodePacked(FeedType.Adapter, priceAdapter10, uint64(10000123212)));
            updatePrice(address(mp), address(tokens[1]), abi.encodePacked(FeedType.FixedValue, p[1]));
        }

                args[5] =
            AssetArgs({assetAddress: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))});

        args = sort(args);

        ForcePushArgs memory fp;
        mp.swap(fp, args, true, deployerPublicKey, false, deployerPublicKey);
        MockERC20WithDecimals(tokens[0]).mint(address(mp), 1e18);
        MockERC20WithDecimals(tokens[1]).mint(address(mp), 0.5e18);

        AssetArgs[] memory assets;
        {
            assets = sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: tokens[0], amount: int(1e18)}),
                        AssetArgs({assetAddress: tokens[1], amount: int(-0.2e18)}),
                        // AssetArgs({assetAddress: tokens[2], amount: int(-2e18)}),
                        // AssetArgs({assetAddress: tokens[3], amount: int(-4e18)})
                    ]
                )
            );
        }

        mp.swap{value: 1e14}(fp, assets, true, deployerPublicKey, false, deployerPublicKey);

        // mp.transfer(address(mp), 17000000000000000000010);

        // assets = sort(
        //         dynamic(
        //             [
        //                 AssetArgs({assetAddress: address(mp), amount: int(17000000000000000000010)}),
        //                 AssetArgs({assetAddress: tokens[0], amount: int(-41e18)}),
        //                 AssetArgs({assetAddress: tokens[1], amount: int(-15.5e18)}),
        //                 AssetArgs({assetAddress: tokens[2], amount: int(-78e18)}),
        //                 AssetArgs({assetAddress: tokens[3], amount: int(-116e18)}),
        //                 AssetArgs({assetAddress: tokens[4], amount: int(-30e18)})
        //             ]
        //         )
        //     );
        // mp.swap{value: 100e18}(fp, assets, true, deployerPublicKey, false, deployerPublicKey);
        vm.stopBroadcast();
    }
}
