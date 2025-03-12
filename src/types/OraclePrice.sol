// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Struct that provides overriding of price called force push
struct OraclePrice {
    // Address of this contract
    address contractAddress;
    // Signing timestamp
    uint128 timestamp;
    // Share price of this contract
    uint128 sharePrice;
    // Force push authoirty's sign
    bytes signature;
}
