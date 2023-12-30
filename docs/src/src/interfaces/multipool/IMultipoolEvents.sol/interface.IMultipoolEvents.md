# IMultipoolEvents
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/275ab153e36267157a2ba5626f6cd734bad189ea/src/interfaces/multipool/IMultipoolEvents.sol)


## Events
### AssetChange
Emitted when any quantity or cashback change happens even for multipool share


```solidity
event AssetChange(address indexed asset, uint quantity, uint128 collectedCashbacks);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|address of changed assets (address(this) for multipool)|
|`quantity`|`uint256`|absolute value of new stored quantity|
|`collectedCashbacks`|`uint128`|absolute value of new cashbacks (always 0 for multipool)|

### FeesChange
Emitted when fee charging params change. All ratios are Q32 values.


```solidity
event FeesChange(
    address indexed developerAddress,
    uint64 deviationParam,
    uint64 deviationLimit,
    uint64 depegBaseFee,
    uint64 baseFee,
    uint64 developerBaseFee
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`developerAddress`|`address`|address to send arcanum protocol development and maintaince fees|
|`deviationParam`|`uint64`|curve parameter that is a fee ratio at the half of the curve divided by deviation limit|
|`deviationLimit`|`uint64`|curve parameter that shows maximum deviation changes that may be made by callers|
|`depegBaseFee`|`uint64`|parameter that shows ratio of value taken from deviation fee as base fee|
|`baseFee`|`uint64`|parameter that shows ratio of value taken from each operation quote value|
|`developerBaseFee`|`uint64`|parameter that shows ratio of value that is taken from base fee share for arcanum protocol developers and maintainers|

### TargetShareChange
Thrown when target share of any asset got updated


```solidity
event TargetShareChange(address indexed asset, uint newTargetShare, uint newTotalTargetShares);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|changed target share address asset|
|`newTargetShare`|`uint256`|absolute value of updated target share|
|`newTotalTargetShares`|`uint256`|absolute value of new sum of all target shares|

### PriceFeedChange
Thrown when price feed for an asset got updated


```solidity
event PriceFeedChange(address indexed targetAsset, FeedInfo newFeed);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetAsset`|`address`|address of asset wich price feed data is changed|
|`newFeed`|`FeedInfo`|updated price feed data|

### SharePriceExpirationChange
Thrown when expiration time for share price force push change


```solidity
event SharePriceExpirationChange(uint validityDuration);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`validityDuration`|`uint256`|time in seconds when force push data is valid|

### AuthorityRightsChange
Thrown when permissions of authorities were changed per each authority.
event provides addresses new permissions


```solidity
event AuthorityRightsChange(
    address indexed account, bool isForcePushAuthority, bool isTargetShareAuthority
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|address of toggled authority|
|`isForcePushAuthority`|`bool`|true if is trused to sign force push price data|
|`isTargetShareAuthority`|`bool`|true if is trusted to change target shares|

### PauseChange
Thrown when contract is paused or unpaused


```solidity
event PauseChange(bool isPaused);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isPaused`|`bool`|shows new value of pause|

### CollectedFeesChange
Thrown every time new fee gets collected


```solidity
event CollectedFeesChange(uint totalCollectedBalance, uint totalCollectedCashbacks);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalCollectedBalance`|`uint256`|shows contracts native token balance which is sum of all fees and cashbacks|
|`totalCollectedCashbacks`|`uint256`|shows sum of all collected cashbacks|

