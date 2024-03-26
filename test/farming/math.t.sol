// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {UserInfo, PoolInfo, FarmingMath} from "../../src/lib/Farm.sol";

contract FarmingMathTests is Test {
    receive() external payable {}

    function assertUser(UserInfo memory a, UserInfo memory b) public pure {
        assertEq(a.amount, b.amount, "amount don't match");
        assertEq(a.rd, b.rd, "rd don't match");
        assertEq(a.rd2, b.rd2, "rd 2 don't match");
    }

    function assertPool(PoolInfo memory a, PoolInfo memory b) public pure {
        assertEq(a.lockAsset, b.lockAsset, "lock assets don't match");
        assertEq(
            a.lockAssetTotalNumber, b.lockAssetTotalNumber, "lock assets total number don't match"
        );
        assertEq(a.rewardAsset, b.rewardAsset, "reward asset");
        assertEq(a.rewardAsset2, b.rewardAsset2, "reward asset 2");

        assertEq(a.rpb, b.rpb, "rpb don't match");
        assertEq(a.arps, b.arps, "arps don't match");
        assertEq(a.availableRewards, b.availableRewards, "available rewards don't match");

        assertEq(a.rpb2, b.rpb2, "rpb 2 don't match");
        assertEq(a.arps2, b.arps2, "arps 2 don't match");
        assertEq(a.availableRewards2, b.availableRewards2, "available rewards 2 don't match");

        assertEq(a.lastUpdateBlock, b.lastUpdateBlock, "last update block don't match");
    }

    function test_FarmingHappyPath1() public pure {
        PoolInfo memory pool;
        PoolInfo memory ethalon;
        UserInfo memory alice;
        UserInfo memory bob;

        UserInfo memory aliceEthalon;
        UserInfo memory bobEthalon;

        pool.updateDistribution(5, int(100e18), 1e18);

        ethalon.rpb = 1e18;
        ethalon.availableRewards = 100e18;
        ethalon.lastUpdateBlock = 5;

        assertPool(pool, ethalon);

        pool.deposit(alice, 6, 1e18);
        pool.deposit(bob, 6, 1e18);

        aliceEthalon.amount = 1e18;
        bobEthalon.amount = 1e18;

        assertUser(alice, aliceEthalon);
        assertUser(bob, bobEthalon);

        pool.withdraw(alice, 7, 0);

        aliceEthalon.rd = 0.5e18;
        assertUser(alice, aliceEthalon);

        ethalon.lastUpdateBlock = 7;
        ethalon.lockAssetTotalNumber = 2e18;
        ethalon.arps = 1e18 * 1e18 / 2e18;
        ethalon.availableRewards = 99e18;
        assertPool(pool, ethalon);

        pool.withdraw(bob, 200, 0);

        bobEthalon.rd = 50e18;
        assertUser(bob, bobEthalon);

        pool.withdraw(bob, 200, 0);
        assertUser(bob, bobEthalon);

        ethalon.lastUpdateBlock = 200;
        ethalon.lockAssetTotalNumber = 2e18;
        ethalon.arps = 50e18;
        ethalon.availableRewards = 0;
        assertPool(pool, ethalon);

        pool.withdraw(bob, 200, 0.5e18);
        bobEthalon.rd = 25e18;
        bobEthalon.amount = 0.5e18;
        assertUser(bob, bobEthalon);

        pool.updateDistribution(250, int(1e18), 1e18);

        ethalon.lastUpdateBlock = 250;
        ethalon.lockAssetTotalNumber = 1.5e18;
        ethalon.availableRewards = 1e18;
        assertPool(pool, ethalon);

        pool.withdraw(alice, 251, 1e18);

        aliceEthalon.amount = 0;
        aliceEthalon.rd = 50e18 + 6666666666666666666;

        pool.withdraw(bob, 251, 0.5e18);

        bobEthalon.amount = 0;
        bobEthalon.rd = 50e18 + (1e18 - 6666666666666666666);

        ethalon.lastUpdateBlock = 251;
        ethalon.lockAssetTotalNumber = 0;
        ethalon.availableRewards = 0;
        ethalon.arps = 50e18 + 1e18 * 2 / uint(3);
        assertPool(pool, ethalon);
    }
}
