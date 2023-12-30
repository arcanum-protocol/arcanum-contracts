# ContextMath
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/275ab153e36267157a2ba5626f6cd734bad189ea/src/lib/MpContext.sol)


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

