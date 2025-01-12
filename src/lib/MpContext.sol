// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FixedPoint96} from "./FixedPoint96.sol";
import {FixedPoint32} from "./FixedPoint32.sol";

import {IMultipoolErrors} from "../interfaces/multipool/IMultipoolErrors.sol";

struct MpAsset {
    uint128 quantity;
    uint16 targetShare;
    uint112 collectedCashbacks;
}

struct MpContext {
    uint sharePrice;
    uint oldTotalSupply;
    int totalSupplyDelta;
    uint totalTargetShares;
    uint deviationParam;
    uint deviationLimit;
    uint depegBaseFee;
    uint baseFee;
    uint managementBaseFee;

    int unusedEthBalance;
    uint collectedManagementFees;
    uint collectedOracleFees;
    uint cummulativeInAmount;
    uint cummulativeOutAmount;

    address managementFeeRecepient;
    address oracleAddress;
}

using {
    ContextMath.calculateDeviationFee,
    ContextMath.calculateBaseFee,
    ContextMath.calculateTotalSupplyDelta,
    ContextMath.applyCollected
} for MpContext global;

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

    function calculateTotalSupplyDelta(MpContext memory ctx, bool isExactInput) internal pure {
        int delta = ctx.totalSupplyDelta;
        if (delta < 0) {
            if (!isExactInput) {
                ctx.totalSupplyDelta =
                    int(ctx.cummulativeOutAmount) * delta / int(ctx.cummulativeInAmount);
            }
        } else {
            if (isExactInput) {
                ctx.totalSupplyDelta =
                    int(ctx.cummulativeInAmount) * delta / int(ctx.cummulativeOutAmount);
            }
        }
    }

    function calculateBaseFee(MpContext memory ctx, bool isExactInput) internal pure {
        uint quoteValue = isExactInput ? ctx.cummulativeInAmount : ctx.cummulativeOutAmount;
        uint newCollectedFee = (quoteValue * ctx.baseFee) >> FixedPoint32.RESOLUTION;
        ctx.unusedEthBalance -= int(newCollectedFee);
        uint newCollectedManagementFees =
            newCollectedFee * ctx.managementBaseFee >> FixedPoint32.RESOLUTION;
        ctx.collectedOracleFees += newCollectedFee - newCollectedManagementFees;
        ctx.collectedManagementFees += newCollectedManagementFees;
    }

    function calculateDeviationFee(
        MpContext memory ctx,
        MpAsset memory asset,
        int quantityDelta,
        uint price
    )
        internal
        view
    {
        uint newQuantity = addDelta(asset.quantity, quantityDelta);
        uint newTotalSupply = addDelta(ctx.oldTotalSupply, ctx.totalSupplyDelta);
        uint targetShare = (uint(asset.targetShare) << FixedPoint32.RESOLUTION) / ctx.totalTargetShares;

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
            uint deviationFee = (
                ctx.deviationParam * dNew * quotedDelta / (ctx.deviationLimit - dNew)
            ) >> FixedPoint32.RESOLUTION;
            uint basePart = (deviationFee * ctx.depegBaseFee) >> FixedPoint32.RESOLUTION;
            ctx.unusedEthBalance -= int(deviationFee);
            ctx.collectedOracleFees += basePart;

            asset.collectedCashbacks += uint112(deviationFee - basePart);
        } else if (dNew <= dOld) {
            uint cashback = dOld == 0
                ? asset.collectedCashbacks
                : (dOld - dNew) * asset.collectedCashbacks / dOld;

            ctx.unusedEthBalance += int(cashback);

            asset.collectedCashbacks -= uint112(cashback);
        }
        asset.quantity = uint128(newQuantity);
    }

    function applyCollected(MpContext memory ctx, address payable refundTo) internal {
        int balance = ctx.unusedEthBalance;
        if (balance < 0) revert IMultipoolErrors.FeeExceeded();
        if (refundTo != address(0) && balance > 0) {
            refundTo.transfer(uint(balance));
        }
    }
}
