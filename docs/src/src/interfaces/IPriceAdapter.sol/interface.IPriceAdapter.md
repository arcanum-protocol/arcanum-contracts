# IPriceAdapter
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/interfaces/IPriceAdapter.sol)


## Functions
### getPrice

Common interface for extracting prices from external sources

*Used to safe multipool contract spece and to be able to easily change price logic if
needed*


```solidity
function getPrice(uint feedId) external view returns (uint price);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feedId`|`uint256`|Identifier of price feed that is used to specify price origin|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|value is represented as a Q96 value|


