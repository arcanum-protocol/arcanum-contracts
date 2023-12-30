# FixedPoint96
[Git Source](https://github.com/provisorDAO/arcanum-contracts/blob/275ab153e36267157a2ba5626f6cd734bad189ea/src/lib/FixedPoint96.sol)

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


