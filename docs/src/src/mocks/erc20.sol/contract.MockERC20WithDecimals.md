# MockERC20WithDecimals
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/275ab153e36267157a2ba5626f6cd734bad189ea/src/mocks/erc20.sol)

**Inherits:**
ERC20, Ownable


## State Variables
### decimalsOverride

```solidity
uint8 decimalsOverride;
```


## Functions
### constructor


```solidity
constructor(string memory name, string memory symbol, uint8 _decimals) ERC20(name, symbol);
```

### decimals


```solidity
function decimals() public view virtual override returns (uint8);
```

### mint


```solidity
function mint(address _to, uint _amount) public;
```

