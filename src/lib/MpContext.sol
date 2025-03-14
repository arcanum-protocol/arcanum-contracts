// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FixedPoint96, FixedPoint32} from "./FixedPoint.sol";
import {getBits, setBits} from "./Binary.sol";
import {IMultipoolErrors} from "../interfaces/multipool/IMultipoolErrors.sol";

struct MpAsset {
    // 1 bit
    bool isUsed;
    // 127 bit
    uint quantity;
    // 16 bit
    uint targetShare;
    // 112 bit
    uint collectedCashbacks;
}

function unpackMpAsset(bytes32 b) pure returns (MpAsset memory a) {
    a.isUsed = getBits(b, 0, 1) != 0;
    a.quantity = getBits(b, 1, 127);
    a.targetShare = getBits(b, 128, 16);
    a.collectedCashbacks = getBits(b, 144, 112);
}

function packMpAsset(MpAsset memory a) pure returns (bytes32 b) {
    b = setBits(b, bytes32(uint(a.isUsed ? 1 : 0)), 0, 1);
    b = setBits(b, bytes32(uint(a.quantity)), 1, 127);
    b = setBits(b, bytes32(uint(a.targetShare)), 128, 16);
    b = setBits(b, bytes32(uint(a.collectedCashbacks)), 144, 112);
}

struct Fees {
    uint refund;
    uint managerEarnedFee;
    uint oracleEarnedFee;
}

struct MpContext {
    uint sharePrice;
    uint oldTotalSupply;
    int totalSupplyDelta;
    uint totalTargetShares;
    uint deviationIncreaseFee;
    uint deviationLimit;
    uint feeToCashbackRatio;
    uint baseFee;
    uint managementBaseFee;
    uint deviationFees;
    uint collectedCashbacks;
    uint collectedFees;
    address managementFeeRecepient;
    address oracleAddress;
}

using {ContextMath.calculateDeviationFee, ContextMath.applyCollected} for MpContext global;

library ContextMath {
    function subAbs(uint a, uint b) internal pure returns (uint c) {
        c = a > b ? a - b : b - a;
    }

    function pos(int a) internal pure returns (uint b) {
        b = a > 0 ? uint(a) : uint(-a);
    }

    function addDelta(uint a, int b) internal pure returns (uint c) {
        if (b > 0) {
            c = a + uint(b);
        } else if (a >= uint(-b)) {
            c = a - uint(-b);
        } else {
            revert IMultipoolErrors.NotEnoughQuantityToBurn();
        }
    }

    function applyCollected(
        MpContext memory ctx,
        uint quoteTradeValue,
        uint ethDeposit
    )
        internal
        pure
        returns (Fees memory fees)
    {
        uint collectedBaseFees = (quoteTradeValue * ctx.baseFee) >> FixedPoint32.RESOLUTION;

        fees.refund = collectedBaseFees + ctx.deviationFees + ctx.collectedFees;

        if (fees.refund > ctx.collectedCashbacks + ethDeposit) {
            revert IMultipoolErrors.FeeExceeded();
        }
        fees.refund = ctx.collectedCashbacks + ethDeposit - fees.refund;

        uint totalEarnedFees = ctx.collectedFees + collectedBaseFees;
        fees.managerEarnedFee = totalEarnedFees * ctx.managementBaseFee >> FixedPoint32.RESOLUTION;
        fees.oracleEarnedFee = totalEarnedFees - fees.managerEarnedFee;
    }

    function calculateDeviationFee(
        MpContext memory ctx,
        MpAsset memory asset,
        int quantityDelta,
        uint price
    )
        internal
        pure
    {
        uint newQuantity = addDelta(asset.quantity, quantityDelta);
        uint newTotalSupply = addDelta(ctx.oldTotalSupply, ctx.totalSupplyDelta);
        uint targetShare =
            (uint(asset.targetShare) << FixedPoint32.RESOLUTION) / ctx.totalTargetShares;

        uint dOld = ctx.oldTotalSupply == 0
            ? 0
            : subAbs(
                (uint(asset.quantity) * price << FixedPoint32.RESOLUTION) / ctx.oldTotalSupply
                    / ctx.sharePrice,
                targetShare
            );
        uint dNew = newTotalSupply == 0
            ? 0
            : subAbs(
                (newQuantity * price << FixedPoint32.RESOLUTION) / newTotalSupply / ctx.sharePrice,
                targetShare
            );
        uint quotedDelta = (pos(quantityDelta) * price) >> FixedPoint96.RESOLUTION;

        if (dNew > dOld && ctx.oldTotalSupply != 0) {
            if (targetShare == 0) revert IMultipoolErrors.TargetShareIsZero();
            if (!(ctx.deviationLimit >= dNew)) revert IMultipoolErrors.DeviationExceedsLimit();
            uint fullDeviationFee =
                (ctx.deviationIncreaseFee * quotedDelta) >> FixedPoint32.RESOLUTION;
            uint collectedFees =
                (fullDeviationFee * ctx.feeToCashbackRatio) >> FixedPoint32.RESOLUTION;

            asset.collectedCashbacks += uint112(fullDeviationFee - collectedFees);
            ctx.collectedFees = collectedFees;
            ctx.deviationFees = fullDeviationFee - collectedFees;
        } else if (dNew <= dOld) {
            uint cashback = dOld == 0
                ? asset.collectedCashbacks
                : (dOld - dNew) * asset.collectedCashbacks / dOld;

            ctx.collectedCashbacks += cashback;
            asset.collectedCashbacks -= uint112(cashback);
        }
        asset.quantity = uint128(newQuantity);
    }
}
