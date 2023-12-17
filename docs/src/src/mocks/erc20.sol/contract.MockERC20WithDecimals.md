# MockERC20WithDecimals
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/mocks/erc20.sol)

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

