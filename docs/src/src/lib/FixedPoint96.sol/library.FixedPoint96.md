# FixedPoint96
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/3dfff3148182d4dfe6804e525ac556b83c05da71/src/lib/FixedPoint96.sol)

A library for handling binary fixed point numbers, see
https://en.wikipedia.org/wiki/Q_(number_format)

*Used in price calculations*


## State Variables
### RESOLUTION

```solidity
uint8 internal constant RESOLUTION = 96;
```


### Q96

```solidity
uint256 internal constant Q96 = 0x1000000000000000000000000;
```


