// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

struct UserInfo {
    uint amount;
    uint rd;
    uint rd2;
}

struct PoolInfo {
    address lockAsset;
    uint lockAssetTotalNumber;
    address rewardAsset;
    address rewardAsset2;
    uint rpb;
    uint arps; // Accumulated rewards per share, times 1e18. See below.
    uint availableRewards;
    uint rpb2;
    uint arps2; // Accumulated rewards per share, times 1e18. See below.
    uint availableRewards2;
    uint lastUpdateBlock;
}

using {
    FarmingMath.deposit,
    FarmingMath.withdraw,
    FarmingMath.updateDistribution
} for PoolInfo global;

library FarmingMath {
    function updatePool(PoolInfo memory pool, uint currentBlockNumber) internal pure {
        uint rewards = pool.rpb * (currentBlockNumber - pool.lastUpdateBlock);
        if (rewards > pool.availableRewards) {
            rewards = pool.availableRewards;
        }

        uint rewards2 = pool.rpb2 * (currentBlockNumber - pool.lastUpdateBlock);
        if (rewards2 > pool.availableRewards2) {
            rewards2 = pool.availableRewards2;
        }

        pool.lastUpdateBlock = currentBlockNumber;
        if (pool.lockAssetTotalNumber > 0) {
            pool.arps += rewards * 1e18 / pool.lockAssetTotalNumber;
            pool.availableRewards -= rewards;

            pool.arps2 += rewards2 * 1e18 / pool.lockAssetTotalNumber;
            pool.availableRewards2 -= rewards2;
        } else {
            pool.arps = 0;
            pool.arps2 = 0;
        }
    }

    function updateRewards(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber
    )
        internal
        pure
        returns (uint accRewards, uint accRewards2)
    {
        updatePool(pool, currentBlockNumber);
        uint amount = user.amount * pool.arps / 1e18 - user.rd;
        accRewards += amount;

        uint amount2 = user.amount * pool.arps2 / 1e18 - user.rd2;
        accRewards2 += amount2;
    }

    function deposit(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber,
        uint depositAmount
    )
        internal
        pure
        returns (uint accRewards, uint accRewards2)
    {
        (accRewards, accRewards2) = updateRewards(pool, user, currentBlockNumber);
        user.amount += depositAmount;
        user.rd = user.amount * pool.arps / 1e18;
        user.rd2 = user.amount * pool.arps2 / 1e18;
        pool.lockAssetTotalNumber += depositAmount;
    }

    function withdraw(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber,
        uint withdrawAmount
    )
        internal
        pure
        returns (uint accRewards, uint accRewards2)
    {
        (accRewards, accRewards2) = updateRewards(pool, user, currentBlockNumber);
        user.amount -= withdrawAmount;
        user.rd = user.amount * pool.arps / 1e18;
        user.rd2 = user.amount * pool.arps2 / 1e18;
        pool.lockAssetTotalNumber -= withdrawAmount;
    }

    function updateDistribution(
        PoolInfo memory pool,
        uint currentBlockNumber,
        int rewardsDelta,
        uint newRpb
    )
        internal
        pure
    {
        updatePool(pool, currentBlockNumber);
        if (rewardsDelta >= 0) {
            pool.availableRewards += uint(rewardsDelta);
        } else {
            pool.availableRewards -= uint(-rewardsDelta);
        }
        pool.rpb = newRpb;
    }

    function updateDistribution2(
        PoolInfo memory pool,
        uint currentBlockNumber,
        int rewardsDelta,
        uint newRpb
    )
        internal
        pure
    {
        updatePool(pool, currentBlockNumber);
        if (rewardsDelta >= 0) {
            pool.availableRewards2 += uint(rewardsDelta);
        } else {
            pool.availableRewards2 -= uint(-rewardsDelta);
        }
        pool.rpb2 = newRpb;
    }
}
