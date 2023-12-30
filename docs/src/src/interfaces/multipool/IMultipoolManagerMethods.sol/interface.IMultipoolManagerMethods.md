# IMultipoolManagerMethods
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/275ab153e36267157a2ba5626f6cd734bad189ea/src/interfaces/multipool/IMultipoolManagerMethods.sol)


## Functions
### updatePrices

Updates price feeds for multiple tokens.

*Values in each of these arrays should match with indexes (e.g. index 1 contains all
data for asset 1)*


```solidity
function updatePrices(
    address[] calldata assetAddresses,
    FeedType[] calldata kinds,
    bytes[] calldata feedData
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assetAddresses`|`address[]`|Addresses of assets for wich to update feeds|
|`kinds`|`FeedType[]`|Price feed extraction strategy type|
|`feedData`|`bytes[]`|Data with encoded payload for price extraction|


### updateTargetShares

Updates target shares for multiple tokens.

*Values in each of these arrays should match with indexes (e.g. index 1 contains all
data for asset 1)*


```solidity
function updateTargetShares(
    address[] calldata assetAddresses,
    uint[] calldata targetShares
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assetAddresses`|`address[]`|Addresses of assets for wich to update target shares|
|`targetShares`|`uint256[]`|Share values to update to|


### withdrawFees

Method that allows to withdraw collected to owner fees. May be only called by owner

*Sends all collected values at once*


```solidity
function withdrawFees(address to) external returns (uint fees);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to wich to transfer collected fees|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fees`|`uint256`|withdrawn native token value|


### withdrawDeveloperFees

Method that allows to withdraw developer fees from contract

*Can be invoked by anyone but is still safe as recepient is always developer address*


```solidity
function withdrawDeveloperFees() external returns (uint fees);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fees`|`uint256`|withdrawn native token value|


### togglePause

Method that stops or launches contract. Used in case of freezing (e.g hacks or
temprorary stopping contract)


```solidity
function togglePause() external;
```

### setFeeParams

Method to change fee charging rules. All ratios are Q32 values.

*Remember to always update every value as this function overrides all variables*


```solidity
function setFeeParams(
    uint64 newDeviationLimit,
    uint64 newHalfDeviationFee,
    uint64 newDepegBaseFee,
    uint64 newBaseFee,
    uint64 newDeveloperBaseFee,
    address newDeveloperAddress
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDeviationLimit`|`uint64`|curve parameter that shows maximum deviation changes that may be made by callers|
|`newHalfDeviationFee`|`uint64`|curve parameter that is a fee ratio at the half of the curve|
|`newDepegBaseFee`|`uint64`|parameter that shows ratio of value taken from deviation fee as base fee|
|`newBaseFee`|`uint64`|parameter that shows ratio of value taken from each operation quote value|
|`newDeveloperBaseFee`|`uint64`|parameter that shows ratio of value that is taken from base fee share for arcanum protocol developers and maintainers|
|`newDeveloperAddress`|`address`|address to send arcanum protocol development and maintaince fees|


### setSharePriceParams

This method allows to chenge time for wich force pushed share price is valid
and minimal number of unique signatures required for price force push

*Called only by owner. This mechanism allow you to manage price volatility by changing
valid price timeframes*


```solidity
function setSharePriceParams(uint128 newValidityDuration, uint newSignatureThershold) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newValidityDuration`|`uint128`|New interval in seconds|
|`newSignatureThershold`|`uint256`|New number of signatures that substracted by 1 (if 0 is passed 1 signature is required)|


### setAuthorityRights

Method that changes permissions of accounts

*Remember to always update every value as this function overrides all variables*


```solidity
function setAuthorityRights(
    address authority,
    bool forcePushSettlement,
    bool targetShareSettlement
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`authority`|`address`|address whos permissions change|
|`forcePushSettlement`|`bool`|allows to sign force push data if true|
|`targetShareSettlement`|`bool`|allows to change target share if true|


