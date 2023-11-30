// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {FixedPoint96} from "./FixedPoint96.sol";
import {FixedPoint32} from "./FixedPoint32.sol";
import "../multipool/Multipool.sol";

struct MpAsset {
    uint quantity;
    uint128 share;
    uint128 collectedCashbacks;
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
    int unusedEthBalance;
    uint totalCollectedCashbacks;
    uint collectedFees;
    uint cummulativeInAmount;
    uint cummulativeOutAmount;
}

using {
    ContextMath.calculateDeviationFee,
    ContextMath.calculateBaseFee,
    ContextMath.calculateTotalSupplyDelta,
    ContextMath.applyCollected
} for MpContext global;

library ContextMath {
    error FeeExceeded();
    error DeviationExceedsLimit();

    function subAbs(uint a, uint b) internal pure returns (uint c) {
        c = a > b ? a - b : b - a;
    }

    function pos(int a) internal pure returns (uint b) {
        b = a > 0 ? uint(a) : uint(-a);
    }

    function addDelta(uint a, int b) internal pure returns (uint c) {
        c = b > 0 ? a + uint(b) : a - uint(-b);
    }

    function calculateTotalSupplyDelta(MpContext memory ctx, bool isExactInput) internal view {
        int delta = ctx.totalSupplyDelta;
        if (delta < 0) {
            if (!isExactInput) {
                ctx.totalSupplyDelta = int(ctx.cummulativeOutAmount) * delta / int(ctx.cummulativeInAmount);
            }
        } else {
            if (isExactInput) {
                ctx.totalSupplyDelta = int(ctx.cummulativeInAmount) * delta / int(ctx.cummulativeOutAmount);
            }
        }
    }

    function calculateBaseFee(MpContext memory ctx, bool isExactInput) internal view {
        uint quoteValue = isExactInput ? ctx.cummulativeInAmount : ctx.cummulativeOutAmount;
        uint fee = (quoteValue * ctx.baseFee) >> FixedPoint32.RESOLUTION;
        ctx.unusedEthBalance -= int(fee);
        ctx.collectedFees += fee;
    }

    function calculateDeviationFee(MpContext memory ctx, MpAsset memory asset, int quantityDelta, uint price)
        internal
        view
    {
        uint newQuantity = addDelta(asset.quantity, quantityDelta);
        uint newTotalSupply = addDelta(ctx.oldTotalSupply, ctx.totalSupplyDelta);
        uint targetShare = (asset.share << FixedPoint32.RESOLUTION) / ctx.totalTargetShares;

        uint dOld = ctx.oldTotalSupply == 0
            ? 0
            : subAbs((asset.quantity * price << FixedPoint32.RESOLUTION) / ctx.oldTotalSupply / ctx.sharePrice, targetShare);
        uint dNew = newTotalSupply == 0
            ? 0
            : subAbs((newQuantity * price << FixedPoint32.RESOLUTION) / newTotalSupply / ctx.sharePrice, targetShare);
        uint quotedDelta = (pos(quantityDelta) * price) >> FixedPoint96.RESOLUTION;

        if (dNew > dOld && ctx.oldTotalSupply != 0) {
            if (!(ctx.deviationLimit >= dNew)) revert DeviationExceedsLimit();
            uint deviationFee =
                (ctx.deviationParam * dNew * quotedDelta / (ctx.deviationLimit - dNew)) >> FixedPoint32.RESOLUTION;
            uint basePart = (deviationFee * ctx.depegBaseFee) >> FixedPoint32.RESOLUTION;
            ctx.unusedEthBalance -= int(deviationFee);
            ctx.collectedFees += basePart;
            ctx.totalCollectedCashbacks += (deviationFee - basePart);

            asset.collectedCashbacks += uint128(deviationFee - basePart);
        } else if (dNew <= dOld) {
            uint cashback = (dOld - dNew) * asset.collectedCashbacks / dOld;

            ctx.unusedEthBalance += int(cashback);
            ctx.totalCollectedCashbacks -= cashback;

            asset.collectedCashbacks -= uint128(cashback);
        }
        asset.quantity = newQuantity;
    }

    function applyCollected(MpContext memory ctx, address payable refundTo) internal {
        int balance = ctx.unusedEthBalance;
        if (!(balance >= 0)) revert FeeExceeded();
        if (balance > 0) {
            refundTo.transfer(uint(balance));
        }
    }
}
