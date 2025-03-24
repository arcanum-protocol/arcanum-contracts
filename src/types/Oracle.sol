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
    address tokenAddress;
    uint sharePriceValidityDuration;
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
    slot.tokenAddress = address(uint160(getBits(packedSlot, 0, 160)));
    slot.sharePriceValidityDuration = uint(getBits(packedSlot, 160, 31));
    slot.weArePanicking = getBits(packedSlot, 191, 1) == 1;
    slot.lastClaimedTimestamp = uint(getBits(packedSlot, 192, 64));
}

function packFraudSlot(FraudSlot memory slot) pure returns (bytes32 packedSlot) {
    packedSlot = setBits(packedSlot, bytes32(uint(uint160(slot.tokenAddress))), 0, 160);
    packedSlot = setBits(packedSlot, bytes32(uint(slot.sharePriceValidityDuration)), 160, 31);
    packedSlot = setBits(packedSlot, bytes32(slot.weArePanicking == true ? uint(1) : 0), 191, 1);
    packedSlot = setBits(packedSlot, bytes32(uint(uint64(slot.lastClaimedTimestamp))), 192, 64);
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
