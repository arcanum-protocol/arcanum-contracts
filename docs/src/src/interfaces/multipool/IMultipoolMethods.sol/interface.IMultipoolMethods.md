# IMultipoolMethods
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/interfaces/multipool/IMultipoolMethods.sol)


## Functions
### getSharePriceParams

Gets several share prive params

*Fetches data by reading a single slot*


```solidity
function getSharePriceParams()
    external
    view
    returns (uint128 _sharePriceValidityDuration, uint128 _initialSharePrice);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_sharePriceValidityDuration`|`uint128`|Time in seconds for signed share price to be valid|
|`_initialSharePrice`|`uint128`|Price that is used when contract's total supply is zero|


### getPriceFeed

Gets price feed data


```solidity
function getPriceFeed(address asset) external view returns (FeedInfo memory priceFeed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset for wich to get price feed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`priceFeed`|`FeedInfo`|Returns price feed data|


### getPrice

Gets current asset price


```solidity
function getPrice(address asset) external view returns (uint price);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset for wich to get price|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Returns price data in a format of Q96 decimal value|


### getFeeParams

Gets fee params from state. All ratios are Q32 values.

*Fetches data by reading a single slot for first integers*


```solidity
function getFeeParams()
    external
    view
    returns (
        uint64 _deviationParam,
        uint64 _deviationLimit,
        uint64 _depegBaseFee,
        uint64 _baseFee,
        uint64 _developerBaseFee,
        address _developerAddress
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_deviationParam`|`uint64`|Curve parameter that is a fee ratio at the half of the curve divided by deviation limit|
|`_deviationLimit`|`uint64`|Curve parameter that shows maximum deviation changes that may be made by callers|
|`_depegBaseFee`|`uint64`|Parameter that shows ratio of value taken from deviation fee as base|
|`_baseFee`|`uint64`|Parameter that shows ratio of value taken from each operation quote value fee|
|`_developerBaseFee`|`uint64`|Parameter that shows ratio of value that is taken from base fee|
|`_developerAddress`|`address`|Address to send arcanum protocol development and maintaince fees share for arcanum protocol developers and maintainers|


### getAsset

Gets asset related info

*Reads exacly two storage slots*


```solidity
function getAsset(address assetAddress) external view returns (MpAsset memory asset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assetAddress`|`address`|address of asset wich data to provide|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`MpAsset`|asset related data structure|


### swap

Method that executes every trading in multipool

*This is a low level method that works via direct token transfer on contract and method
execution. Should be used in other contracts only
Fees are charged in native token equivalend via transferring them before invocation or in
msg.value*


```solidity
function swap(
    ForcePushArgs calldata forcePushArgs,
    AssetArgs[] calldata assetsToSwap,
    bool isExactInput,
    address receiverAddress,
    bool refundEthToReceiver,
    address refundAddress
)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forcePushArgs`|`ForcePushArgs`|Arguments for share price force push|
|`assetsToSwap`|`AssetArgs[]`|Assets that will be used as input or output and their amounts. Assets should be provided ascendingly sorted by addresses. Can't accept duplicates of assets|
|`isExactInput`|`bool`|Shows sleepage direction. If is true input amouns (that are greater than zero) will be used exactly and output amounts (less than zero) will be used as slippage checks. If false it is reversed|
|`receiverAddress`|`address`|Address that will receive output amounts|
|`refundEthToReceiver`|`bool`|If this value is true, left ether will be sent to `receiverAddress`, else, `refundAddress` will be used|
|`refundAddress`|`address`|Address that will be used to receive left input token and native token balances|


### checkSwap

Method that dry runs swap execution and provides estimated fees and amounts

*To avoid calculation errors don't provide small values to amount*


```solidity
function checkSwap(
    ForcePushArgs calldata forcePushArgs,
    AssetArgs[] calldata assetsToSwap,
    bool isExactInput
)
    external
    view
    returns (int fee, int[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forcePushArgs`|`ForcePushArgs`|Arguments for share price force push|
|`assetsToSwap`|`AssetArgs[]`|Assets that will be used as input or output and their amounts. Assets should be provided ascendingly sorted by addresses. Can't accept duplicates of assets|
|`isExactInput`|`bool`|Shows sleepage direction. If is true input amouns (that are greater than zero) will be used and the output amounts will be estmated proportionally. If false it behaves reversed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`int256`|Native token amount to cover swap fees|
|`amounts`|`int256[]`||


### increaseCashback

Method that dry runs swap execution and provides estimated fees and amounts

*Method is permissionless so anyone can boos incentives. Native token value can be
transferred directly if used iva contract or via msg.value with any method*


```solidity
function increaseCashback(address assetAddress) external payable returns (uint128 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assetAddress`|`address`|Address of asset selected to increase its cashback|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint128`|Native token amount that was put into cashback|


