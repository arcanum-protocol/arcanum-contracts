// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {
    toX96, toX32, updatePrice, AbstractFixedValueOracle
} from "../../test/MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract Mint is Script {
    using ECDSA for bytes32;

    Multipool mp;

    function mintAndUpdateToken(address token, uint quote, uint p) internal {
        uint val = 1e18;
        updatePrice(address(mp), token, abi.encodePacked(FeedType.FixedValue, uint128(p)));
        if (val > 0) {
            MockERC20WithDecimals(token).mint(address(mp), val);
        }
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        mp = Multipool(address(0x90b1AcD4e333A0fE29D6a90fa77D0c6Cc592c913));
        //           oracle  0x13D8E43D75e93740916DCFa03306433f22576A9c
        //   mp  0x90b1AcD4e333A0fE29D6a90fa77D0c6Cc592c913
        //   token 0  address:  0xCdFE37e195d98d3C8C669C56a70C418327F17B5f
        //   token 1  address:  0x97f959ff7C81B91CCa5253241f4F585C35b8fd5E
        //   token 2  address:  0x7d6190956Bd55B17524662E7F42f140C403b5c4F
        //   token 3  address:  0x74621BB03a08612D1Ba28563E7dDf8BC43B3Fc50
        //   token 4  address:  0xF1B9706661a8b14AF90E1e756a84Bcef650160BB
        address[5] memory tokens = [
            0xCdFE37e195d98d3C8C669C56a70C418327F17B5f,
            0x97f959ff7C81B91CCa5253241f4F585C35b8fd5E,
            0x7d6190956Bd55B17524662E7F42f140C403b5c4F,
            0x74621BB03a08612D1Ba28563E7dDf8BC43B3Fc50,
            0xF1B9706661a8b14AF90E1e756a84Bcef650160BB
        ];
        // uint[5] memory quotes = [uint(400e18), 300e18, 300e18, 300e18, 300e18];
        // uint[5] memory p = [toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18),
        // toX96(10e18)];

        // uint quoteSum = 1600e18;
        // {
        //     for (uint i; i < tokens.length; i++) {
        //         mintAndUpdateToken(tokens[i], quotes[i], p[i]);
        //     }
        // }

        // uint newPrice = toX96(10e18);
        // uint quoteSum = 10e18;
        // uint val = (quoteSum << 96) / newPrice;

        // {
        // fp.contractAddress = address(mp);
        // fp.timestamp = uint128(block.timestamp);
        // fp.sharePrice = uint128(toX96(0.1e18));
        // bytes32 message = keccak256(
        //     abi.encodePacked(fp.contractAddress, uint(block.timestamp), uint(toX96(0.1e18)),
        // block.chainid)
        // ).toEthSignedMessageHash();
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, message);
        // fp.signature = abi.encodePacked(r, s, v);
        // }

        Oracle oracle = Oracle(payable(0x224a2AcAB00e97645EA075168b2bf0Ad3124437f));

        // payable(address(oracle)).transfer(1e16);

        oracle.stake(deployerPublicKey, 1e18, deployerPublicKey);

        uint256 ts = block.timestamp;
        bytes memory data = abi.encodePacked(
            address(mp), uint(ts), uint(49432770753888933655371916), uint(block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(deployerPrivateKey, keccak256(data).toEthSignedMessageHash());

        OraclePrice memory op;

        op.timestamp = uint128(ts);
        op.sharePrice = uint128(49432770753888933655371916);
        op.contractAddress = address(mp);
        op.signature = abi.encodePacked(r, s, v); // bytes32 -> bytes conversion

        // mp.swap{value: 1e15}(op, tokens[0], address(mp), 1e18, true, rd);
        // mp.swap{value: 1e17}(op, tokens[1], address(mp), 1e17, true, rd);
        // mp.swap{value: 1e16}(op, tokens[2], address(mp), 1e17, true, rd);

        MockERC20(tokens[1]).mint(address(mp), 1e5);

        mp.swap{value: 1e16}(
            op, tokens[1], tokens[0], 1e5, true, deployerPublicKey, deployerPublicKey, true
        );

        vm.stopBroadcast();
    }
}
