pragma solidity ^0.8.0;

/// @title FixedPoint16
/// @notice A library for handling binary fixed point numbers, see
/// https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in calculations
library FixedPoint16 {
    uint8 internal constant RESOLUTION = 16;
    uint256 internal constant Q16 = 0x10000;
}

library FixedPoint32 {
    uint8 internal constant RESOLUTION = 32;
    uint256 internal constant Q32 = 0x100000000;
}

library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
