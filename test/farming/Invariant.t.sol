// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {UserInfo, PoolInfo, FarmingMath} from "../../src/lib/Farm.sol";
import {Farm} from "../../src/farm/Farm.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";

contract FarmingHandler is Test {
    Farm farm;

    uint assetNumber;
    uint userNumber;

    address[] users;

    uint startBalance;
    MockERC20[] assets;

    constructor() {
        Farm impl = new Farm();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeWithSignature("initialize(address)", address(this))
        );
        farm = Farm(address(proxy));

        userNumber = 100;
        assetNumber = 5;

        startBalance = 500e18;

        for (uint i = 0; i < assetNumber; ++i) {
            assets.push(new MockERC20("asset", "asset", 0));
        }

        for (uint i = 0; i < userNumber; ++i) {
            users.push(makeAddr("user"));
            for (uint j = 0; j < assetNumber; ++j) {
                assets[j].mint(users[i], startBalance);
            }
        }
        farm.addPool(address(assets[0]), address(assets[1]));
    }

    function getPoolId(
        uint seed,
        uint chanceOfInvalidity
    )
        internal
        view
        returns (uint poolId, bool isInvalid)
    {
        if (seed % 100 < chanceOfInvalidity) {
            poolId = seed + farm.poolNumber();
            isInvalid = true;
        } else {
            poolId = bound(seed, 0, farm.poolNumber());
            isInvalid = false;
        }
    }

    function getAsset(
        uint seed,
        uint chanceOfInvalidity
    )
        internal
        returns (address asset, bool isInvalid)
    {
        if (seed % 100 < chanceOfInvalidity) {
            asset = makeAddr("invalid asset");
            isInvalid = true;
        } else {
            asset = address(assets[bound(seed, 0, assets.length - 1)]);
            isInvalid = false;
        }
    }

    // yes or no or fuck you
    function ynf(uint seed) internal returns (bool ans) {
        if (seed % 2 == 0) {
            ans = true;
        } else {
            ans = false;
        }
    }

    function addPool(uint assetSeed, uint rewardSeed) external {
        (address asset, bool isInvalid1) = getAsset(assetSeed, 0);
        (address reward, bool isInvalid2) = getAsset(rewardSeed, 0);
        if (isInvalid1 || isInvalid2) {
            return;
        }
        vm.prank(farm.owner());
        farm.addPool(asset, reward);
    }

    // this function will be called by the pool during the flashloan
    function deposit(uint poolIdSeed, uint userSeed, uint amountSeed) external payable {
        (uint poolId, bool isInvalid) = getPoolId(poolIdSeed, 0);
        address user = users[bound(userSeed, 0, users.length - 1)];
        uint amount = bound(amountSeed, 0, startBalance);
        if (isInvalid) {
            return;
        }
        PoolInfo memory poolInfo = farm.getPool(poolId);

        MockERC20 asset = MockERC20(poolInfo.lockAsset);

        vm.startPrank(user);
        asset.approve(address(farm), amount);
        farm.deposit(poolId, amount);
    }

    // used for withdrawing ether balance in the pool
    function withdraw(
        uint poolIdSeed,
        uint userSeed,
        uint amountSeed,
        uint claimRewardsSeed
    )
        external
    {
        (uint poolId, bool isInvalid) = getPoolId(poolIdSeed, 0);
        address user = users[bound(userSeed, 0, users.length - 1)];

        if (isInvalid) {
            return;
        }
        UserInfo memory userInfo = farm.getUser(poolId, user);
        PoolInfo memory poolInfo = farm.getPool(poolId);
        uint amount = bound(amountSeed, 0, userInfo.amount);

        bool claimRewards = ynf(claimRewardsSeed);

        MockERC20 asset = MockERC20(poolInfo.lockAsset);

        vm.startPrank(user);
        asset.approve(address(farm), amount);
        farm.withdraw(poolId, amount, claimRewards, address(0), abi.encode(0));
    }

    function addRewards(
        uint poolIdSeed,
        int amountSeed,
        uint intervalSeed,
        uint removeSeed
    )
        external
    {
        (uint poolId, bool isInvalid) = getPoolId(poolIdSeed, 0);
        PoolInfo memory poolInfo = farm.getPool(poolId);
        int amount = bound(amountSeed, -int(startBalance), int(startBalance));
        uint interval = bound(intervalSeed, 0, 86400);

        uint amountAbs;
        if (amount > 0) {
            amountAbs = uint(amount);
        } else {
            amountAbs = uint(-amount);
        }

        if (amount > 0) {
            MockERC20(poolInfo.rewardAsset).mint(farm.owner(), uint(amount));
            vm.prank(farm.owner());
            MockERC20(poolInfo.rewardAsset).approve(address(farm), uint(amount));
        }

        vm.prank(farm.owner());
        farm.updateDistribution(poolId, amount, amountAbs / interval);
    }

    receive() external payable {}
}

contract FarmingTests is Test {
    FarmingHandler actor;

    receive() external payable {}

    function setUp() public {
        actor = new FarmingHandler();
        targetContract(address(actor));
    }

    function invariant_farming() external {}
}
