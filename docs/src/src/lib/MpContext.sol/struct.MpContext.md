# MpContext
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/lib/MpContext.sol)


```solidity
struct MpContext {
    uint sharePrice;
    uint oldTotalSupply;
    int totalSupplyDelta;
    uint totalTargetShares;
    uint deviationParam;
    uint deviationLimit;
    uint depegBaseFee;
    uint baseFee;
    uint collectedDeveloperFees;
    uint developerBaseFee;
    int unusedEthBalance;
    uint totalCollectedCashbacks;
    uint collectedFees;
    uint cummulativeInAmount;
    uint cummulativeOutAmount;
}
```

