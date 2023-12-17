# IMultipoolErrors
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/interfaces/multipool/IMultipoolErrors.sol)


## Errors
### InvalidForcePushAuthority
Thrown when force push signature verification fails


```solidity
error InvalidForcePushAuthority();
```

### InvalidTargetShareAuthority
Thrown when target share change initiator is invalid


```solidity
error InvalidTargetShareAuthority();
```

### ForcePushPriceExpired
Thrown when force push signature verification fails


```solidity
error ForcePushPriceExpired(uint blockTimestamp, uint priceTimestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockTimestamp`|`uint256`|current block timestamp|
|`priceTimestamp`|`uint256`|signed with price timestamp|

### ZeroAmountSupplied
Thrown when zero amount supplied for any asset token


```solidity
error ZeroAmountSupplied();
```

### InsufficientBalance
Thrown when supplied amount is less than required for swap


```solidity
error InsufficientBalance(address asset);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|asset who's balance is invalid|

### SleepageExceeded
Thrown when sleepage check for some asset failed


```solidity
error SleepageExceeded();
```

### AssetsNotSortedOrNotUnique
Thrown when supplied assets have duplicates or are not sorted ascending


```solidity
error AssetsNotSortedOrNotUnique();
```

### IsPaused
Thrown when contract is paused


```solidity
error IsPaused();
```

### FeeExceeded
Thrown when supplied native token value for fee expired


```solidity
error FeeExceeded();
```

### DeviationExceedsLimit
Thrown when any asset's deviation after operation grows and exceeds deviation limit


```solidity
error DeviationExceedsLimit();
```

### NotEnoughQuantityToBurn
Thrown when contract has less balance of token than is requested for burn


```solidity
error NotEnoughQuantityToBurn();
```

### NoPriceOriginSet
Is thrown if price feed data is unset


```solidity
error NoPriceOriginSet();
```

