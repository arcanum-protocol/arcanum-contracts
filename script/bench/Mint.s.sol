// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {UniV3Feed} from "../../src/lib/Price.sol";
import {Staker} from "../../src/multipool/Staker.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice, AbstractFixedValueOracle} from "../../test/MultipoolUtils.t.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract Mint is Script {
    using ECDSA for bytes32;

    Multipool mp;

    function mintAndUpdateToken(address token, uint quote, uint p) internal {
        uint val = (quote << 96) / p;
        updatePrice(address(mp), token, abi.encodePacked(FeedType.FixedValue, uint128(p)));
        if (val > 0) {
            MockERC20WithDecimals(token).mint(address(mp), val);
        }
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        mp = Multipool(address(0x26d58226d328FafD7ab72C234783E898191e6484));
//   token 0  address:  0x6573027624bA52bebCAE1Ae07ed98b0B188F1E33
//   token 1  address:  0x4c2ab15e33bc34610c63863bb3A39De0B79a0D15
//   token 2  address:  0xF8b370484A153CD3df5dd6C1a027b007025077F2
//   token 3  address:  0x102F9659Eb51E00477256a53DA460a475c4eaF75
//   token 4  address:  0x2BeB75450683B0f6ac402387d392849949CE7A6D
        address[5] memory tokens = [
            0xDF4d4Af5C8Feb45c08856a8A016B6CB0b86b8810, 
            0xABd7D864420583a317a873BceDf6481D157828Ea, 
            0xAc8AFD9B3A775Ddb79Ce83F1Cd18114D7B6809e3,
            0xca3b3F1ae22c71eCdC6fBf36998507099fF7dfFc,
            0x5FF153F54E541a67eA78b5Ab8e69E8f6F5CAB82C
        ];
        uint[5] memory quotes = [uint(400e18), 300e18, 300e18, 300e18, 300e18];
        uint[5] memory p = [toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18), toX96(10e18)];

        uint quoteSum = 1600e18;
        {
            for (uint i; i < tokens.length; i++) {
                mintAndUpdateToken(tokens[i], quotes[i], p[i]);
            }
        }

        uint newPrice = toX96(10e18);
        // uint quoteSum = 10e18;
        // uint val = (quoteSum << 96) / newPrice;
        ForcePushArgs memory fp;
        AssetArgs[] memory assets;
        {
            assets = sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(0xDF4d4Af5C8Feb45c08856a8A016B6CB0b86b8810), amount: int((10e18 << 96) / newPrice)}),
                        AssetArgs({
                            assetAddress: address(mp),
                            amount: -int((10e18 << 96) / toX96(0.1e18))
                        })
                    ]
                )
            );
        }
        {
        fp.contractAddress = address(mp);
        fp.timestamp = uint128(block.timestamp);
        fp.sharePrice = uint128(toX96(0.1e18));
        bytes32 message = keccak256(
            abi.encodePacked(fp.contractAddress, uint(block.timestamp), uint(toX96(0.1e18)), block.chainid)
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, message);
        fp.signature = abi.encodePacked(r, s, v);
        }

        mp.swap{value: 1e13}(fp, assets, true, deployerPublicKey, false, deployerPublicKey);

        vm.stopBroadcast();
    }
}
