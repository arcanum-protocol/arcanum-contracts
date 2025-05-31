// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {DummyOracle} from "../../src/multipool/DummyOracle.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";
import {MultipoolUtils, toX96, toX32, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract DummyOracleTests is Test, MultipoolUtils {
    using ECDSA for bytes32;

    receive() external payable {}

    function test_Access() public {
        vm.startPrank(owner);
        DummyOracle oracle = new DummyOracle(address(this), 10000);
        assertEq(oracle.oracle(), address(this));
        assertEq(oracle.priceValidityDuration(), 10000);

        oracle.updateParams(user0, 12500);
        assertEq(oracle.oracle(), user0);
        assertEq(oracle.priceValidityDuration(), 12500);
        vm.stopPrank();

        vm.startPrank(user0);

        vm.expectRevert();
        oracle.updateParams(address(0), 12500);

        vm.stopPrank();
    }

    function test_CommitPrice() public {
        vm.prank(owner);
        DummyOracle oracle = new DummyOracle(address(owner), 10000);
        uint256 ts = block.timestamp;
        bytes memory data = abi.encodePacked(
            address(owner), uint(ts), uint(49432770753888933655371916), uint(block.chainid)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, keccak256(data).toEthSignedMessageHash());
        OraclePrice memory op;
        op.timestamp = uint128(ts);
        op.sharePrice = uint128(49432770753888933655371916);
        op.contractAddress = address(owner);
        op.signature = abi.encodePacked(r, s, v); // bytes32 -> bytes conversion
        vm.deal(owner, 1e18);

        vm.prank(owner);
        oracle.commitPrice{value: 1e10}(op);

        vm.prank(user0);
        vm.expectRevert();
        oracle.commitPrice{value: 1e10}(op);

        vm.warp(block.timestamp + 10001);
        vm.prank(owner);
        vm.expectRevert();
        oracle.commitPrice{value: 1e10}(op);
    }
}
