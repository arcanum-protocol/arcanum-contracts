// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

struct UserInfo {
    uint claimed;
    uint quantity;
    uint protocolRD;
    uint lastUpdateBlock;
}

struct PoolInfo {
    uint256 totalRewards;
    uint256 totalQuantity;
    address multipoolAddress;
    uint collectedAmount;
    uint protocolTokenRPB;
    uint protocolTokenAvailableRewards;
    uint protocolTokenArps;
    uint lastUpdateBlock;
}

using {
    FarmingMath.deposit,
    FarmingMath.withdraw,
    FarmingMath.updateDistribution
} for PoolInfo global;

library FarmingMath {
    function updatePool(PoolInfo memory pool, uint currentBlockNumber) internal pure {
        uint rewards = pool.protocolTokenRPB * (currentBlockNumber - pool.lastUpdateBlock);
        if (rewards > pool.protocolTokenAvailableRewards) {
            rewards = pool.protocolTokenAvailableRewards;
        }

        pool.lastUpdateBlock = currentBlockNumber;
        if (pool.totalQuantity > 0) {
            pool.protocolTokenArps += rewards * 1e18 / pool.totalQuantity;
            pool.protocolTokenAvailableRewards -= rewards;

        } else {
            pool.protocolTokenArps = 0;
        }
    }

    function updateRewards(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber,
        uint pendingAmount
    )
        internal
        pure
        returns (uint rewards, uint protocolRewards)
    {
        updatePool(pool, currentBlockNumber);
        rewards = (user.quantity * pool.totalRewards + pendingAmount / pool.totalQuantity) - user.claimed;
        uint amount = user.quantity * pool.protocolTokenArps / 1e18 - user.protocolRD;
        protocolRewards += amount;

    }

    function deposit(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber,
        uint depositAmount,
        uint pendingAmount
    )
        internal
        pure
        returns (uint rewards, uint protocolRewards)
    {
        (rewards, protocolRewards) = updateRewards(pool, user, currentBlockNumber, pendingAmount);
        user.quantity += depositAmount;
        user.protocolRD = user.quantity * pool.protocolTokenArps / 1e18;
        pool.totalQuantity += depositAmount;
    }

    function withdraw(
        PoolInfo memory pool,
        UserInfo memory user,
        uint currentBlockNumber,
        uint withdrawAmount,
        uint pendingAmount
    )
        internal
        pure
        returns (uint rewards, uint protocolRewards)
    {
        (rewards, protocolRewards) = updateRewards(pool, user, currentBlockNumber, pendingAmount);
        user.quantity -= withdrawAmount;
        user.protocolRD = user.quantity * pool.protocolTokenArps / 1e18;
        pool.totalQuantity -= withdrawAmount;
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
            pool.protocolTokenAvailableRewards += uint(rewardsDelta);
        } else {
            pool.protocolTokenAvailableRewards -= uint(-rewardsDelta);
        }
        pool.protocolTokenRPB = newRpb;
    }

}
