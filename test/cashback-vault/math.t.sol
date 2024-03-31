// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {CashbackDistributor} from "../../src/lib/CashbackDistributor.sol";

contract FarmingMathTests is Test {
    receive() external payable {}

    function assertEq(CashbackDistributor memory a, CashbackDistributor memory b) public pure {
        assertEq(a.cashbackPerSec, b.cashbackPerSec, "cashback per sec don't match");
        assertEq(a.cashbackLimit, b.cashbackLimit, "cashback limit don't match");
        assertEq(a.cashbackBalance, b.cashbackBalance, "cashback balance don't match");
    }

    function test_DistributorHappyPath() public {
        CashbackDistributor memory distributor;
        CashbackDistributor memory distributorResult;

        assertEq(0, distributor.distribute(0, 0));
        assertEq(distributor, distributorResult);

        distributor.updateDistribution(0.5e18, 1.5e18, 0);
        distributorResult.cashbackPerSec = 0.5e18;
        distributorResult.cashbackLimit = 1.5e18;
        distributorResult.cashbackBalance = 0;
        assertEq(0, distributor.distribute(0, 0));
        assertEq(distributor, distributorResult);

        assertEq(0, distributor.distribute(0, 10));
        assertEq(distributor, distributorResult);

        vm.expectRevert();
        assertEq(0, distributor.distribute(100, 0));

        distributor.updateDistribution(0.5e18, 1.5e18, 3.5e18);
        distributorResult.cashbackBalance = 3.5e18;
        assertEq(distributor, distributorResult);

        assertEq(1.5e18, distributor.distribute(0, 20));
        assertEq(1.5e18, distributor.distribute(20, 200));
        assertEq(0.5e18, distributor.distribute(200, 210));

        assertEq(0, distributor.distribute(210, 220));

        vm.expectRevert();
        distributor.updateDistribution(0.5e18, 1.5e18, -10e18);

        distributor.updateDistribution(0.5e18, 1.5e18, 0.5e18);
        distributorResult.cashbackBalance = 0.5e18;
        assertEq(distributor, distributorResult);

        assertEq(0.5e18, distributor.distribute(210, 1));

        distributor.updateDistribution(0.5e18, 1.5e18, 0.5e18);
        distributorResult.cashbackBalance = 0.5e18;
        assertEq(distributor, distributorResult);

        distributor.updateDistribution(0.5e18, 1.5e18, -0.5e18);
        distributorResult.cashbackBalance = 0;
        assertEq(distributor, distributorResult);

        distributor.updateDistribution(0.000001e18, 1.5e18, 0.5e18);
        distributorResult.cashbackBalance = 0.5e18;
        assertEq(distributor, distributorResult);
        assertEq(0.000002e18, distributor.distribute(100, 102));
    }
}
