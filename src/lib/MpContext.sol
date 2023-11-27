// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {FixedPoint96} from "./FixedPoint96.sol";
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
    ContextMath.calculateFees, ContextMath.calculateFeesShareToken, ContextMath.applyCollected
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

    function calculateFeesShareToken(MpContext memory ctx, int quantityDelta) internal view {
        uint fee = ((pos(quantityDelta) * ctx.sharePrice * ctx.baseFee) >> 32) >> FixedPoint96.RESOLUTION;
        console.log("AM: ", pos(quantityDelta));
        ctx.unusedEthBalance -= int(fee);
        ctx.collectedFees += fee;
    }

    function calculateFees(MpContext memory ctx, MpAsset memory asset, int quantityDelta, uint price) internal view {
        uint newQuantity = addDelta(asset.quantity, quantityDelta);
        uint newTotalSupply = addDelta(ctx.oldTotalSupply, ctx.totalSupplyDelta);
        uint targetShare = (asset.share << 32) / ctx.totalTargetShares;

        uint dOld = subAbs(
            ctx.oldTotalSupply == 0 ? 0 : (asset.quantity * price << 32) / ctx.oldTotalSupply / ctx.sharePrice,
            targetShare
        );
        uint dNew =
            subAbs(newTotalSupply == 0 ? 0 : (newQuantity * price << 32) / newTotalSupply / ctx.sharePrice, targetShare);
        uint quotedDelta = (pos(quantityDelta) * price) >> FixedPoint96.RESOLUTION;

        uint bf = (ctx.baseFee * quotedDelta) >> 32;
        ctx.collectedFees += bf;
        ctx.unusedEthBalance -= int(bf);
        if (dNew > dOld) {
            if (!(ctx.deviationLimit >= dNew)) revert DeviationExceedsLimit();
            uint deviationFee = (ctx.deviationParam * dNew * quotedDelta / (ctx.deviationLimit - dNew)) >> 32;
            uint basePart = (deviationFee * ctx.depegBaseFee) >> 32;
            ctx.unusedEthBalance -= int(deviationFee);
            ctx.collectedFees += basePart;
            ctx.totalCollectedCashbacks += (deviationFee - basePart);

            asset.collectedCashbacks += uint128(deviationFee - basePart);
        } else {
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
