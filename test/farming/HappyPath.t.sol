// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {UserInfo, PoolInfo, FarmingMath} from "../../src/lib/Farm.sol";
import {Farm} from "../../src/farm/Farm.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";

contract FarmingTests is Test {
    receive() external payable {}

    Farm farm;
    MockERC20 asset;
    MockERC20 reward;
    MockERC20 points;

    function setUp() public {
        Farm impl = new Farm();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeWithSignature("initialize(address)", address(this))
        );
        farm = Farm(address(proxy));
        asset = new MockERC20("asset", "asset", 0);
        reward = new MockERC20("reward", "reward", 0);
        points = new MockERC20("points", "points", 0);
    }

    function test_FarmingHappyPath2() public {
        farm.addPool(address(asset), address(reward), address(0));

        reward.mint(address(this), 100e18);
        reward.approve(address(farm), 100e18);

        farm.updateDistribution(0, 100e18, 1e18);

        asset.mint(address(this), 1e18);
        asset.approve(address(farm), 1e18);

        farm.deposit(0, 1e18);

        skip(50);

        (uint rewards, uint rewards2) = farm.availableRewards(0, address(this));
        assertEq(50e18, rewards);
        assertEq(0, rewards2);
    }

    function test_FarmingWaitWithNoDistribution() public {
        farm.addPool(address(asset), address(reward), address(0));

        reward.mint(address(this), 100e18);
        reward.approve(address(farm), 100e18);

        farm.updateDistribution(0, 100e18, 1e18);

        skip(10000);

        asset.mint(address(this), 1e18);
        asset.approve(address(farm), 1e18);

        farm.deposit(0, 1e18);

        skip(50);

        (uint rewards, uint rewards2) = farm.availableRewards(0, address(this));
        assertEq(50e18, rewards);
        assertEq(0, rewards2);
    }

    function test_FarmingDepositAndWaitDistribution() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        farm.addPool(address(asset), address(reward), address(0));

        asset.mint(alice, 100e18);
        vm.prank(alice);
        asset.approve(address(farm), 1000e18);

        asset.mint(bob, 100e18);
        vm.prank(bob);
        asset.approve(address(farm), 1000e18);

        skip(10000);

        reward.mint(address(this), 100e18);
        reward.approve(address(farm), 100e18);

        farm.updateDistribution(0, 100e18, 1e18);

        vm.prank(alice);
        farm.deposit(0, 10e18);

        vm.prank(alice);
        vm.expectRevert();
        farm.deposit(0, 100e18);

        skip(50);

        (uint rewards, uint rewards2) = farm.availableRewards(0, alice);
        assertEq(50e18, rewards);
        assertEq(0, rewards2);

        assertEq(0e18, reward.balanceOf(alice));
        vm.prank(alice);
        farm.withdraw(0, 0, false);
        assertEq(50e18, reward.balanceOf(alice));

        vm.prank(bob);
        farm.deposit(0, 100e18);

        skip(150);

        (rewards, rewards2) = farm.availableRewards(0, alice);
        assertEq(4.54545454545454545e18, rewards);
        assertEq(0, rewards2);

        (rewards, rewards2) = farm.availableRewards(0, bob);
        assertEq(50e18 - 4.545454545454545454e18 - 46, rewards);
        assertEq(0, rewards2);

        vm.prank(alice);
        farm.withdraw(0, 10e18, false);
        assertEq(100e18, asset.balanceOf(alice));
        assertEq(50e18 + 4.54545454545454545e18, reward.balanceOf(alice));

        vm.prank(alice);
        farm.withdraw(0, 0, false);
        assertEq(100e18, asset.balanceOf(alice));
        assertEq(50e18 + 4.54545454545454545e18, reward.balanceOf(alice));

        vm.prank(bob);
        vm.expectRevert();
        farm.withdraw(0, 10000e18, false);
        assertEq(0e18, asset.balanceOf(bob));

        assertEq(0e18, reward.balanceOf(bob));
        vm.prank(bob);
        farm.withdraw(0, 100e18, false);
        assertEq(100e18, asset.balanceOf(bob));
        assertEq(50e18 - 4.545454545454545454e18 - 46, reward.balanceOf(bob));
    }

    function test_UpdateDistributionWithInsufficientBalance() public {
        farm.addPool(address(asset), address(reward), address(0));

        reward.mint(address(this), 10e18);
        reward.approve(address(farm), 100e18);

        vm.expectRevert();
        farm.updateDistribution(0, 100e18, 1e18);

        vm.expectRevert();
        farm.updateDistribution(0, -100e18, 1e18);
    }

    function test_CheckMultipleDistrubutionUpdatesWork() public {
        farm.addPool(address(asset), address(reward), address(0));

        reward.mint(address(this), 10e18);
        reward.approve(address(farm), 10e18);

        farm.updateDistribution(0, 5e18, 0.5e18);

        skip(4);

        farm.updateDistribution(0, 5e18, 0.5e18);

        skip(6);

        skip(10);

        address alice = makeAddr("alice");
        asset.mint(alice, 100e18);
        vm.prank(alice);
        asset.approve(address(farm), 10e18);

        vm.prank(alice);
        farm.deposit(0, 10e18);

        (uint rewards, uint rewards2) = farm.availableRewards(0, alice);
        assertEq(0e18, rewards);
        assertEq(0e18, rewards2);

        skip(10);

        (rewards, rewards2) = farm.availableRewards(0, alice);
        assertEq(5e18, rewards);
        assertEq(0e18, rewards2);

        skip(10);

        (rewards, rewards2) = farm.availableRewards(0, alice);
        assertEq(10e18, rewards);
        assertEq(0e18, rewards2);

        skip(10000000000000000);

        (rewards, rewards2) = farm.availableRewards(0, alice);
        assertEq(10e18, rewards);
        assertEq(0e18, rewards2);
    }

    function test_FarmRewardCompoundingWithTwoTokensFail() public {
        farm.addPool(address(asset), address(reward), address(points));
        address alice = makeAddr("alice");

        reward.mint(address(this), 20e18);
        reward.approve(address(farm), 20e18);

        points.mint(address(this), 100e18);
        points.approve(address(farm), 100e18);

        farm.updateDistribution(0, 20e18, 1e18);
        farm.updateDistribution2(0, 100e18, 0.5e18);

        asset.mint(alice, 100e18);
        vm.prank(alice);
        asset.approve(address(farm), 10e18);

        vm.prank(alice);
        farm.deposit(0, 10e18);

        skip(10);

        vm.prank(alice);
        vm.expectRevert(Farm.CantCompound.selector);
        farm.withdraw(0, 10e18, true);
    }

    function test_FarmRewardCompoundingWithTwoTokens() public {
        farm.addPool(address(asset), address(asset), address(points));
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        asset.mint(address(this), 20e18);
        asset.approve(address(farm), 20e18);

        points.mint(address(this), 100e18);
        points.approve(address(farm), 100e18);

        farm.updateDistribution(0, 20e18, 1e18);
        farm.updateDistribution2(0, 100e18, 0.5e18);

        skip(100);

        asset.mint(alice, 100e18);
        vm.prank(alice);
        asset.approve(address(farm), 10e18);

        vm.prank(alice);
        farm.deposit(0, 10e18);

        asset.mint(bob, 100e18);
        vm.prank(bob);
        asset.approve(address(farm), 10e18);

        vm.prank(bob);
        farm.deposit(0, 10e18);

        skip(10);

        (uint rewards, uint rewards2) = farm.availableRewards(0, alice);
        assertEq(5e18, rewards);
        assertEq(2.5e18, rewards2);

        (rewards, rewards2) = farm.availableRewards(0, bob);
        assertEq(5e18, rewards);
        assertEq(2.5e18, rewards2);

        vm.prank(alice);
        farm.withdraw(0, 0, true);

        (rewards, rewards2) = farm.availableRewards(0, alice);
        assertEq(0e18, rewards);
        assertEq(0e18, rewards2);

        (rewards, rewards2) = farm.availableRewards(0, bob);
        assertEq(5e18, rewards);
        assertEq(2.5e18, rewards2);

        skip(20);

        (rewards, rewards2) = farm.availableRewards(0, alice);
        assertEq(6e18, rewards);
        assertEq(6e18, rewards2);

        (rewards, rewards2) = farm.availableRewards(0, bob);
        assertEq(4e18 + 5e18, rewards);
        assertEq(4e18 + 2.5e18, rewards2);

        vm.prank(alice);
        farm.withdraw(0, 15e18, false);

        assertEq(100e18 + 11e18, asset.balanceOf(alice));
        assertEq(6e18 + 2.5e18, points.balanceOf(alice));

        vm.prank(bob);
        farm.withdraw(0, 10e18, false);

        assertEq(100e18 + 9e18, asset.balanceOf(bob));
        assertEq(4e18 + 2.5e18, points.balanceOf(bob));

        skip(20);

        (rewards, rewards2) = farm.availableRewards(0, alice);
        assertEq(0e18, rewards);
        assertEq(0e18, rewards2);

        (rewards, rewards2) = farm.availableRewards(0, bob);
        assertEq(0e18, rewards);
        assertEq(0e18, rewards2);
    }
}
