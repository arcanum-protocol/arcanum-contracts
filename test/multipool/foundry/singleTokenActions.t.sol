// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../../contracts/etf/Multipool.sol";

contract singleTokenActions is Test {
    Multipool m;

    function setUp() public {
        m = new Multipool("Token", "Token");
    }

    function testName() public {
        assertEq(t.name(), "Token");
    }
}:
