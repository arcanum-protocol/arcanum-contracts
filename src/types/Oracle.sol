// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {setBits, getBits} from "../lib/Binary.sol";

struct OracleData {
    uint stake;
    uint totalShares;
    bool enabled;
}

struct WithdrawRequest {
    uint amount;
    uint timestamp;
}

struct FraudSlot {
    uint16 sharePriceValidityDuration;
    bool weArePanicking;
    uint lastClaimedTimestamp;
}

function unpackWithdrawRequest(bytes32 packedWithdrawRequest)
    pure
    returns (WithdrawRequest memory withdrawRequest)
{
    withdrawRequest.amount = uint(getBits(packedWithdrawRequest, 0, 128));
    withdrawRequest.timestamp = uint(getBits(packedWithdrawRequest, 128, 64));
}

function packWithdrawRequest(WithdrawRequest memory withdrawRequest)
    pure
    returns (bytes32 packedWithdrawRequest)
{
    packedWithdrawRequest =
        setBits(packedWithdrawRequest, bytes32(uint(uint128(withdrawRequest.amount))), 0, 128);
    packedWithdrawRequest =
        setBits(packedWithdrawRequest, bytes32(uint(uint64(withdrawRequest.timestamp))), 128, 64);
}

function unpackFraudSlot(bytes32 packedSlot) pure returns (FraudSlot memory slot) {
    slot.sharePriceValidityDuration = uint16(getBits(packedSlot, 0, 16));
    slot.weArePanicking = getBits(packedSlot, 16, 1) == 1;
    slot.lastClaimedTimestamp = uint(getBits(packedSlot, 17, 64));
}

function packFraudSlot(FraudSlot memory slot) pure returns (bytes32 packedSlot) {
    packedSlot = setBits(packedSlot, bytes32(uint(slot.sharePriceValidityDuration)), 0, 16);
    packedSlot = setBits(packedSlot, bytes32(slot.weArePanicking == true ? uint(1) : 0), 16, 1);
    packedSlot = setBits(packedSlot, bytes32(uint(uint64(slot.lastClaimedTimestamp))), 17, 64);
}

function unpackOracleData(bytes32 packedOracleData) pure returns (OracleData memory oracleData) {
    oracleData.stake = getBits(packedOracleData, 0, 128);
    oracleData.totalShares = getBits(packedOracleData, 128, 127);
    oracleData.enabled = getBits(packedOracleData, 255, 1) == 1;
}

function packOracleData(OracleData memory oracleData) pure returns (bytes32 packedOracleData) {
    packedOracleData = setBits(packedOracleData, bytes32(uint(uint128(oracleData.stake))), 0, 128);
    packedOracleData =
        setBits(packedOracleData, bytes32(uint(uint128(oracleData.totalShares))), 128, 127);
    packedOracleData =
        setBits(packedOracleData, bytes32(oracleData.enabled == true ? uint(1) : 0), 255, 1);
}
