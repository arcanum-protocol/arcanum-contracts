// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { FixedPoint96 } from "uniswapv3/libraries/FixedPoint96.sol";
uint constant DENOMINATOR = 1e18;

struct MpAsset {
    uint quantity;
    uint share;
    uint collectedCashbacks;
    uint decimals;
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

    int  feeToPay;
    int  cashbackDelta;
    int  feeDelta;
    uint totalCollectedCashbacks;
    uint collectedFees;
    
    uint cummulativeInAmount;
    uint cummulativeOutAmount;
}

using {ContextMath.calculateFees, ContextMath.calculateFeesShareToken, ContextMath.applyCollected} for MpContext global;

library ContextMath {
    function subAbs(uint a, uint b) internal pure returns (uint c) {
        c = a > b ? a - b : b - a;
    }

    function pos(int a) internal pure returns (uint b) {
        b = a > 0 ? uint(a) : uint(-a);
    }

    function addDelta(uint a, int b) internal pure returns (uint c) {
        c = b > 0 ? a + uint(b) : a - uint(-b);
    }

    function calculateFeesShareToken(MpContext memory ctx, int quantityDelta) internal pure {
        uint fee = pos(quantityDelta) * ctx.sharePrice / FixedPoint96.Q96 * ctx.baseFee / DENOMINATOR;
        ctx.feeDelta += int(fee); 
        ctx.feeToPay += int(fee);
    }

    function calculateFees(MpContext memory ctx, MpAsset memory asset, int quantityDelta, uint price) internal view {
        uint newQuantity = addDelta(asset.quantity, quantityDelta);
        uint newTotalSupply = addDelta(ctx.oldTotalSupply, ctx.totalSupplyDelta);
        uint targetShare = asset.share * DENOMINATOR / ctx.totalTargetShares;

        uint dOld = subAbs(ctx.oldTotalSupply == 0 ? 0 : asset.quantity * price * DENOMINATOR / ctx.oldTotalSupply / ctx.sharePrice, targetShare);
        uint dNew = subAbs(newTotalSupply == 0 ? 0 : newQuantity * price * DENOMINATOR / newTotalSupply / ctx.sharePrice, targetShare);
        uint quotedDelta = pos(quantityDelta) * price / FixedPoint96.Q96;

        ctx.collectedFees += ctx.baseFee * quotedDelta / DENOMINATOR;
        if (dNew > dOld) {
            uint deviationFee = ctx.deviationParam * dNew * quotedDelta / (ctx.deviationLimit - dNew);
            uint basePart = deviationFee * ctx.depegBaseFee / DENOMINATOR;
            ctx.feeToPay += int(deviationFee);
            ctx.feeDelta += int(basePart);
            ctx.cashbackDelta += int(deviationFee - basePart);

            asset.collectedCashbacks += (deviationFee - basePart);
        } else {
           uint cashback = (dOld - dNew) * asset.collectedCashbacks / dOld;
            ctx.feeToPay -= int(cashback);
            ctx.cashbackDelta -= int(cashback);

            asset.collectedCashbacks -= cashback;
        }
        asset.quantity = newQuantity;
    }

    function applyCollected(MpContext memory ctx) internal view {
        uint availableAmount = address(this).balance - ctx.totalCollectedCashbacks - ctx.collectedFees;
        require(int(availableAmount) + ctx.feeToPay >= 0, "CAN'T PAY FEE");
        ctx.totalCollectedCashbacks = addDelta(ctx.totalCollectedCashbacks, ctx.cashbackDelta);
        ctx.collectedFees = addDelta(ctx.collectedFees, ctx.feeDelta);
    }
}

