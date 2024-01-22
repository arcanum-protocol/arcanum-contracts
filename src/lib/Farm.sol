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

library FarmingMath {

    function updatePool(PoolInfo memory pool, uint currentBlockNumber) public pure {

        uint rewards = pool.rpb * (currentBlockNumber - pool.lastUpdateBlock);
        if (rewards > pool.availableRewards) {
            rewards = pool.availableRewards;
        }
        pool.arps +=  rewards * 1e18 / pool.lockAssetTotalNumber;
    }

    function updateRewards(PoolInfo memory pool, UserInfo memory user, uint currentBlockNumber) public pure {
        updatePool(pool, currentBlockNumber);
        uint amount = user.amount * pool.arps - user.rd;
        user.rd += amount;
        user.accRewards += amount;
    }

    function deposit(PoolInfo memory pool, UserInfo memory user, uint currentBlockNumber, uint depositAmount) public pure {
        updateRewards(pool, user, currentBlockNumber); 
        user.amount += depositAmount;
        pool.lockAssetTotalNumber += depositAmount;
    }

    function withdraw(PoolInfo memory pool, UserInfo memory user, uint currentBlockNumber, uint withdrawAmount) public pure {
        updateRewards(pool, user, currentBlockNumber); 
        user.amount -= withdrawAmount;
        pool.lockAssetTotalNumber -= withdrawAmount;
    }

    function updateDistribution(PoolInfo memory pool, uint currentBlockNumber, int rewardsDelta, uint newRpb) public pure {
        updatePool(pool, currentBlockNumber);
        if (rewardsDelta >= 0) {
            pool.availableRewards += uint(rewardsDelta);
        } else {
            pool.availableRewards -= uint(-rewardsDelta);
        }
        pool.rpb = newRpb;
    }
}

