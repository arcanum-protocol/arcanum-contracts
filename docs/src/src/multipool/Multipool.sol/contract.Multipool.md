# Multipool
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/275ab153e36267157a2ba5626f6cd734bad189ea/src/multipool/Multipool.sol)

**Inherits:**
[IMultipool](/src/interfaces/IMultipool.sol/interface.IMultipool.md), Initializable, ERC20Upgradeable, ERC20PermitUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable


## State Variables
### assets

```solidity
mapping(address => MpAsset) internal assets;
```


### prices

```solidity
mapping(address => FeedInfo) internal prices;
```


### deviationParam

```solidity
uint64 internal deviationParam;
```


### deviationLimit

```solidity
uint64 internal deviationLimit;
```


### depegBaseFee

```solidity
uint64 internal depegBaseFee;
```


### baseFee

```solidity
uint64 internal baseFee;
```


### totalTargetShares

```solidity
uint public totalTargetShares;
```


### totalCollectedCashbacks

```solidity
uint public totalCollectedCashbacks;
```


### collectedFees

```solidity
uint public collectedFees;
```


### initialSharePrice

```solidity
uint128 internal initialSharePrice;
```


### sharePriceValidityDuration

```solidity
uint128 internal sharePriceValidityDuration;
```


### isPriceSetter

```solidity
mapping(address => bool) public isPriceSetter;
```


### isTargetShareSetter

```solidity
mapping(address => bool) public isTargetShareSetter;
```


### developerAddress

```solidity
address internal developerAddress;
```


### developerBaseFee

```solidity
uint64 internal developerBaseFee;
```


### collectedDeveloperFees

```solidity
uint public collectedDeveloperFees;
```


### isPaused

```solidity
bool public isPaused;
```


### signatureThershold

```solidity
uint internal signatureThershold;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(
    string memory name,
    string memory symbol,
    uint128 startSharePrice
)
    public
    initializer;
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner;
```

### notPaused


```solidity
modifier notPaused();
```

### getSharePriceParams

Gets several share prive params

*Fetches data by reading a single slot*


```solidity
function getSharePriceParams()
    external
    view
    override
    returns (
        uint128 _sharePriceValidityDuration,
        uint128 _initialSharePrice,
        uint _signatureThershold
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_sharePriceValidityDuration`|`uint128`|Time in seconds for signed share price to be valid|
|`_initialSharePrice`|`uint128`|Price that is used when contract's total supply is zero|
|`_signatureThershold`|`uint256`|_signatureThreshold Minimal signature number required for force push price verification|


### getPriceFeed

Gets price feed data


```solidity
function getPriceFeed(address asset) external view override returns (FeedInfo memory priceFeed);
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
function getPrice(address asset) public view override returns (uint price);
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


```solidity
function getFeeParams()
    public
    view
    override
    returns (
        uint64 _deviationParam,
        uint64 _deviationLimit,
        uint64 _depegBaseFee,
        uint64 _baseFee,
        uint64 _developerBaseFee,
        address _developerAddress
    );
```

### getAsset

Gets asset related info

*Reads exacly two storage slots*


```solidity
function getAsset(address assetAddress) public view override returns (MpAsset memory asset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assetAddress`|`address`|address of asset wich data to provide|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`MpAsset`|asset related data structure|


### getContext

Assembles context for swappping

*tries to apply force pushed share price if provided address matches otherwhise ignores
struct*


```solidity
function getContext(ForcePushArgs calldata forcePushArgs)
    internal
    view
    returns (MpContext memory ctx);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forcePushArgs`|`ForcePushArgs`|price force push related data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ctx`|`MpContext`|state memory context used across swapping|


### getPricesAndSumQuotes

Assembles context for swappping

*Also checks that assets are unique via asserting that they are sorted and each element
address is stricly bigger*


```solidity
function getPricesAndSumQuotes(
    MpContext memory ctx,
    AssetArgs[] memory selectedAssets
)
    internal
    view
    returns (uint[] memory fetchedPrices);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ctx`|`MpContext`|Multipool calculation context|
|`selectedAssets`|`AssetArgs[]`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fetchedPrices`|`uint256[]`|Array of prices per each supplied asset|


### transferAsset

Proceeses asset transfer

*Handles multipool share with no contract calls*


```solidity
function transferAsset(address asset, uint quantity, address to) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Address of asset to send|
|`quantity`|`uint256`|Address value to send|
|`to`|`address`|Recepient address|


### receiveAsset

Asserts there is enough token balance and makes left value refund

*Handles multipool share with no contract calls*


```solidity
function receiveAsset(
    MpAsset memory asset,
    address assetAddress,
    uint requiredAmount,
    address refundAddress
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`MpAsset`|Asset data structure storing asset relative data|
|`assetAddress`|`address`|Address of asset to check and refund|
|`requiredAmount`|`uint256`|Value that is checked to present unused on contract|
|`refundAddress`|`address`|Address to receive asset refund|


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
    payable
    override
    notPaused
    nonReentrant;
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
    override
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
function increaseCashback(address assetAddress)
    external
    payable
    override
    notPaused
    nonReentrant
    returns (uint128 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assetAddress`|`address`|Address of asset selected to increase its cashback|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint128`|Native token amount that was put into cashback|


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
    external
    onlyOwner
    nonReentrant
    notPaused;
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
    external
    override
    nonReentrant
    notPaused;
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
function withdrawFees(address to) external override onlyOwner nonReentrant returns (uint fees);
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
function withdrawDeveloperFees() external override notPaused nonReentrant returns (uint fees);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fees`|`uint256`|withdrawn native token value|


### togglePause

Method that stops or launches contract. Used in case of freezing (e.g hacks or
temprorary stopping contract)


```solidity
function togglePause() external override onlyOwner;
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
    external
    override
    onlyOwner;
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
function setSharePriceParams(
    uint128 newValidityDuration,
    uint newSignatureThershold
)
    external
    override
    onlyOwner;
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
    external
    override
    onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`authority`|`address`|address whos permissions change|
|`forcePushSettlement`|`bool`|allows to sign force push data if true|
|`targetShareSettlement`|`bool`|allows to change target share if true|


