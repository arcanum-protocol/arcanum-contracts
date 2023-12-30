// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Asset args that are provided to swap methods
struct AssetArgs {
    // Multipool asset address
    address assetAddress;
    // Negative for token out, positive for token in
    int amount;
}

// Struct that provides overriding of price called force push
struct ForcePushArgs {
    // Address of this contract
    address contractAddress;
    // Signing timestamp
    uint128 timestamp;
    // Share price of this contract
    uint128 sharePrice;
    // Force push authoirty's sign
    bytes[] signatures;
}
