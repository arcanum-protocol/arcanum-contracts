// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {setBits, getBits} from "../lib/Binary.sol";

struct StakeOptions {
    uint112 minStake;
    uint112 maxStake;
}

struct OracleData {
    uint88 stake;
    uint totalShares;
    bool enabled;
    bool allowedToValidate;
}

struct WithdrawRequest {
    uint share;
    uint timestamp;
}

struct Slot {
    uint16 sharePriceValidityDuration;
    uint32 rewardPerSecond;
    uint32 withdrawalDuration;
    uint88 totalSupply; // uint88 max 309,485,009,821,345,068,724,781,055 ~300M
    uint64 lastClaimedTimestamp;
    bool weArePanicking;
}

function unpackWithdrawRequest(bytes32 packedWithdrawRequest)
    pure
    returns (WithdrawRequest memory withdrawRequest)
{
    withdrawRequest.share = uint(getBits(packedWithdrawRequest, 0, 128));
    withdrawRequest.timestamp = uint(getBits(packedWithdrawRequest, 128, 64));
}

function packWithdrawRequest(WithdrawRequest memory withdrawRequest)
    pure
    returns (bytes32 packedWithdrawRequest)
{
    packedWithdrawRequest =
        setBits(packedWithdrawRequest, bytes32(uint(uint128(withdrawRequest.share))), 0, 128);
    packedWithdrawRequest =
        setBits(packedWithdrawRequest, bytes32(uint(uint64(withdrawRequest.timestamp))), 128, 64);
}

function unpackSlot(bytes32 packedSlot) pure returns (Slot memory slot) {
    // Restrict to 10 bytes
    slot.sharePriceValidityDuration = uint16(getBits(packedSlot, 0, 10));
    slot.rewardPerSecond = uint32(getBits(packedSlot, 10, 32));
    slot.withdrawalDuration = uint32(getBits(packedSlot, 42, 32));
    slot.totalSupply = uint88(getBits(packedSlot, 74, 88));
    slot.lastClaimedTimestamp = uint64(getBits(packedSlot, 162, 64));
    slot.weArePanicking = getBits(packedSlot, 226, 1) == 1;
}

function packSlot(Slot memory slot) pure returns (bytes32 packedSlot) {
    // Restrict to 10 bytes
    packedSlot = setBits(packedSlot, bytes32(uint(slot.sharePriceValidityDuration)), 0, 10);
    packedSlot = setBits(packedSlot, bytes32(uint(slot.rewardPerSecond)), 10, 32);
    packedSlot = setBits(packedSlot, bytes32(uint(slot.withdrawalDuration)), 42, 32);
    packedSlot = setBits(packedSlot, bytes32(uint(slot.totalSupply)), 74, 88);
    packedSlot = setBits(packedSlot, bytes32(uint(slot.lastClaimedTimestamp)), 162, 64);
    packedSlot = setBits(packedSlot, bytes32(slot.weArePanicking == true ? uint(1) : 0), 226, 1);
}

function unpackOracleData(bytes32 packedOracleData) pure returns (OracleData memory oracleData) {
    oracleData.stake = uint88(getBits(packedOracleData, 0, 128)); // 88
    oracleData.totalShares = getBits(packedOracleData, 128, 126); // 88
    oracleData.enabled = getBits(packedOracleData, 254, 1) == 1;
    oracleData.allowedToValidate = getBits(packedOracleData, 255, 1) == 1;
}

function packOracleData(OracleData memory oracleData) pure returns (bytes32 packedOracleData) {
    packedOracleData = setBits(packedOracleData, bytes32(uint(uint128(oracleData.stake))), 0, 128);
    packedOracleData =
        setBits(packedOracleData, bytes32(uint(uint128(oracleData.totalShares))), 128, 126);
    packedOracleData =
        setBits(packedOracleData, bytes32(oracleData.enabled == true ? uint(1) : 0), 254, 1);
    packedOracleData = setBits(
        packedOracleData, bytes32(oracleData.allowedToValidate == true ? uint(1) : 0), 255, 1
    );
}
