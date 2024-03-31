// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

struct CashbackDistributor {
    uint cashbackPerSec;
    uint cashbackLimit;
    uint cashbackBalance;
}

using {
    CashbackDistributorMath.distribute,
    CashbackDistributorMath.addBalance,
    CashbackDistributorMath.updateDistribution
} for CashbackDistributor global;

library CashbackDistributorMath {
    function distribute(
        CashbackDistributor memory distributor,
        uint lastUpdateTime,
        uint currentTime
    )
        internal
        pure
        returns (uint value)
    {
        value = (currentTime - lastUpdateTime) * distributor.cashbackPerSec;
        uint cashbackLimit = distributor.cashbackLimit;
        uint cashbackBalance = distributor.cashbackBalance;
        if (value > cashbackLimit) value = cashbackLimit;
        if (value > cashbackBalance) value = cashbackBalance;
        distributor.cashbackBalance -= value;
    }

    function addBalance(CashbackDistributor memory distributor, uint balanceDelta) internal pure {
        distributor.cashbackBalance += balanceDelta;
    }

    function updateDistribution(
        CashbackDistributor memory distributor,
        uint newCashbackPerSec,
        uint newCashbackLimit,
        int cashbackBalanceChange
    )
        internal
        pure
    {
        if (cashbackBalanceChange > 0) distributor.cashbackBalance += uint(cashbackBalanceChange);
        if (cashbackBalanceChange < 0) distributor.cashbackBalance -= uint(-cashbackBalanceChange);
        distributor.cashbackPerSec = newCashbackPerSec;
        distributor.cashbackLimit = newCashbackLimit;
    }
}
