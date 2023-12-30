# MultipoolRouter
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/275ab153e36267157a2ba5626f6cd734bad189ea/src/multipool/MultipoolRouter.sol)

**Inherits:**
Ownable


## State Variables
### isContractAllowedToCall

```solidity
mapping(address => bool) isContractAllowedToCall;
```


## Functions
### toggleContract


```solidity
function toggleContract(address contractAddress) public onlyOwner;
```

### processCall


```solidity
function processCall(Call memory call, uint index, bool isPredecessing) internal;
```

### swap


```solidity
function swap(
    address poolAddress,
    SwapArgs calldata swapArgs,
    Call[] calldata paramsBefore,
    Call[] calldata paramsAfter
)
    external
    payable;
```

## Errors
### CallFailed

```solidity
error CallFailed(uint callNumber, bool isPredecessing);
```

### InsufficientEthBalance

```solidity
error InsufficientEthBalance(uint callNumber, bool isPredecessing);
```

### InsufficientEthBalanceCallingSwap

```solidity
error InsufficientEthBalanceCallingSwap();
```

### ContractCallNotAllowed

```solidity
error ContractCallNotAllowed(address target);
```

## Structs
### TokenTransferParams

```solidity
struct TokenTransferParams {
    address token;
    address targetOrOrigin;
    uint amount;
}
```

### RouterApproveParams

```solidity
struct RouterApproveParams {
    address token;
    address target;
    uint amount;
}
```

### WrapParams

```solidity
struct WrapParams {
    address weth;
    bool wrap;
    uint ethValue;
}
```

### Call

```solidity
struct Call {
    CallType callType;
    bytes data;
}
```

### SwapArgs

```solidity
struct SwapArgs {
    ForcePushArgs forcePushArgs;
    AssetArgs[] assetsToSwap;
    bool isExactInput;
    address receiverAddress;
    bool refundEthToReceiver;
    address refundAddress;
    uint ethValue;
}
```

## Enums
### CallType

```solidity
enum CallType {
    ERC20Transfer,
    ERC20Approve,
    Any,
    Wrap
}
```

