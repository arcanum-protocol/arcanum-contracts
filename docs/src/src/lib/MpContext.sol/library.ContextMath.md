# ContextMath
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/lib/MpContext.sol)


## Functions
### subAbs


```solidity
function subAbs(uint a, uint b) internal pure returns (uint c);
```

### pos


```solidity
function pos(int a) internal pure returns (uint b);
```

### addDelta


```solidity
function addDelta(uint a, int b) internal pure returns (uint c);
```

### calculateTotalSupplyDelta


```solidity
function calculateTotalSupplyDelta(MpContext memory ctx, bool isExactInput) internal pure;
```

### calculateBaseFee


```solidity
function calculateBaseFee(MpContext memory ctx, bool isExactInput) internal pure;
```

### calculateDeviationFee


```solidity
function calculateDeviationFee(
    MpContext memory ctx,
    MpAsset memory asset,
    int quantityDelta,
    uint price
)
    internal
    pure;
```

### applyCollected


```solidity
function applyCollected(MpContext memory ctx, address payable refundTo) internal;
```

