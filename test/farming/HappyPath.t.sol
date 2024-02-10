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

    function setUp() public {
        Farm impl = new Farm();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeWithSignature("initialize()")
        );
        farm = Farm(address(proxy));
        asset = new MockERC20("asset", "asset", 0);
        reward = new MockERC20("reward", "reward", 0);
    }

    function test_FarmingHappyPath2() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        farm.addPool(address(asset), address(reward));

        reward.mint(address(this), 100e18);
        reward.approve(address(farm), 100e18);

        farm.updateDistribution(0, 100e18, 1e18);

        asset.mint(address(this), 1e18);
        asset.approve(address(farm), 1e18);

        farm.deposit(0, 1e18);

        skip(50);

        assertEq(50e18, farm.availableRewards(0, address(this)));
    }
}
