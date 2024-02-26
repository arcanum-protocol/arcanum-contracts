// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

struct UserInfo {
    uint amount;
    uint rd;
    uint accRewards;
}

struct PoolInfo {
    address lockAsset;
    uint lockAssetTotalNumber;
    address rewardAsset;
    uint rpb;
    uint arps; // Accumulated rewards per share, times 1e18. See below.
    uint availableRewards;
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

        pool.lastUpdateBlock = currentBlockNumber;
        if (pool.lockAssetTotalNumber > 0) {
            pool.arps += rewards * 1e18 / pool.lockAssetTotalNumber;
            pool.availableRewards -= rewards;
        } else {
            pool.arps = 0;
        }
    }

    function updateRewards(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber
    )
        internal
        pure
    {
        updatePool(pool, currentBlockNumber);
        uint amount = user.amount * pool.arps / 1e18 - user.rd;
        user.accRewards += amount;
    }

    function deposit(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber,
        uint depositAmount
    )
        internal
        pure
    {
        updateRewards(pool, user, currentBlockNumber);
        user.amount += depositAmount;
        user.rd = user.amount * pool.arps / 1e18;
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
    {
        updateRewards(pool, user, currentBlockNumber);
        user.amount -= withdrawAmount;
        user.rd = user.amount * pool.arps / 1e18;
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
}
