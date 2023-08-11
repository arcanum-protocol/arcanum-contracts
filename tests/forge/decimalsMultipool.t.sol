pragma solidity 0.8.10;

import "forge-std/Test.sol";
import { Multipool } from "../../contracts/etf/Multipool.sol";

contract TestContractBTest is Test {
    Multipool m;

    function setUp() public {
        m = new Multipool("A", "A");
    }

    function test_NumberIs42() public {
        assertEq(m.symbol(), "A");
    }

    function testFail_Subtract43() public {
        return;
    }
}
