pragma solidity ^0.8.0;

/// @title FixedPoint32
/// @notice A library for handling binary fixed point numbers, see
/// https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in calculations
library FixedPoint32 {
    uint8 internal constant RESOLUTION = 32;
    uint256 internal constant Q32 = 0x100000000;
}
