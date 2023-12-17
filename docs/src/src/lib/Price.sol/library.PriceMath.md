# PriceMath
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/lib/Price.sol)


## Functions
### getPrice

Extracts current price from origin

*Processed the provided `prceFeed` to get it's current price value.*


```solidity
function getPrice(FeedInfo memory priceFeed) internal view returns (uint price);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priceFeed`|`FeedInfo`|struct with data of supplied price feed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|value is represented as a Q96 value|


### getTwapX96

Reversed parameter serves to determine wether price needs to be flipped. This happens because
uniswap
pools have single pool per asset pair and sort assets addresses.

Extracts current price from origin

*This function is used to extract TWAP price from uniswap v3 pool*


```solidity
function getTwapX96(
    address uniswapV3Pool,
    bool reversed,
    uint256 twapInterval
)
    internal
    view
    returns (uint256 priceX96);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uniswapV3Pool`|`address`|address of target uniswap v3 pool|
|`reversed`|`bool`|parameter serves to determine wether price needs to be flipped.|
|`twapInterval`|`uint256`|price aggregation interval in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`priceX96`|`uint256`|value is represented as a Q96 value|


