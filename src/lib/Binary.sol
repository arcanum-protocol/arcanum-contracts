// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

function setBytes(
    bytes32 data,
    bytes32 bytesToSet,
    uint offset,
    uint size
)
    pure
    returns (bytes32 updatedData)
{
    updatedData = setBits(data, bytesToSet, offset * 8, size * 8);
}

function getBytes(bytes32 data, uint offset, uint size) pure returns (uint part) {
    part = getBits(data, offset * 8, size * 8);
}

function setBits(
    bytes32 data,
    bytes32 bitsToSet,
    uint offset,
    uint size
)
    pure
    returns (bytes32 updatedData)
{
    bytes32 mask = bytes32((1 << (size)) - 1) << (256 - offset - size);
    updatedData = (data & ~mask) | (bitsToSet << (256 - offset - size) & mask);
}

function getBits(bytes32 data, uint offset, uint size) pure returns (uint part) {
    part = (uint(data) >> (256 - offset - size)) & ((1 << (size)) - 1);
}
