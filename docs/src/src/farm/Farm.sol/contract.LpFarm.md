# LpFarm
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/farm/Farm.sol)

**Inherits:**
Ownable


## State Variables
### rewardToken

```solidity
IERC20 public rewardToken;
```


### poolInfo

```solidity
mapping(uint => PoolInfo) public poolInfo;
```


### userInfo

```solidity
mapping(uint => mapping(address => UserInfo)) public userInfo;
```


### poolNumber

```solidity
uint public poolNumber;
```


## Functions
### constructor


```solidity
constructor(IERC20 _rewardToken);
```

### calculateReward


```solidity
function calculateReward(
    PoolInfo memory pool,
    uint blockNumber
)
    internal
    pure
    returns (uint rewards);
```

### updatePool


```solidity
function updatePool(uint _pid) public;
```

### pendingRewards


```solidity
function pendingRewards(uint _pid, address _user) external view returns (uint amount);
```

### deposit


```solidity
function deposit(uint256 _pid, uint256 _amount) public;
```

### withdraw


```solidity
function withdraw(uint256 _pid, uint256 _amount) public;
```

### setDistribution


```solidity
function setDistribution(uint _pid, uint _amount, uint _distributionTime) public onlyOwner;
```

### add


```solidity
function add(IERC20 _lpToken) public onlyOwner;
```

## Events
### Deposit

```solidity
event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
```

### Withdraw

```solidity
event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
```

## Structs
### UserInfo

```solidity
struct UserInfo {
    uint amount;
    uint rewardDebt;
}
```

### PoolInfo

```solidity
struct PoolInfo {
    IERC20 lpToken;
    uint lastRewardBlock;
    uint distributeTill;
    uint distributionAmountLeft;
    uint arps;
    uint totalLpSupply;
}
```

