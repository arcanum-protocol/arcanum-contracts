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

struct MpContext {
    uint totalSupply;
    uint totalTargetShares;

    uint deviationIncreaseFee;
    uint deviationLimit;
    uint feeToCashbackRatio;
    uint baseFee;
    uint lpBaseFee;
    uint managementBaseFee;

    uint deviationFees;

    uint collectedManagementFee;
    uint collectedLpFee;

    address oracleAddress;
}

struct MpOutcome {
   uint managerEarnedFee;
   uint oracleEarnedFee;
   uint lpEarnedFee;
   uint cashbacksRefund;

   uint amountIn;
   uint amountOut;
}

using {ContextMath.calculateMintFees, ContextMath.calculateBurnFees, ContextMath.calculateSwapFees} for MpContext global;

library ContextMath {
    function subAbs(uint a, uint b) internal pure returns (uint c) {
        unchecked {
            c = a > b ? a - b : b - a;
        }
    }

    function cashback(
        uint dOld,
        uint dNew,
        uint collectedCb
    )
        internal
        pure
        returns (uint c)
    {
        //TODO: is it safe?
        unchecked {
            if (dOld == 0) return collectedCb;
            c = (dOld - dNew) * collectedCb / dOld;
        }
    }

    function mul32(uint a, uint b)
        internal
        pure
        returns (uint c)
    {
        //TODO: is it safe?
        unchecked {
            c = (a * b) >> 32;
        }
    }

    function div32(uint a, uint b)
        internal
        pure
        returns (uint c)
    {
        //TODO: is it safe?
        unchecked {
            c = (a << 32) / b;
        }
    }

    function mul96(uint a, uint b)
        internal
        pure
        returns (uint c)
    {
        //TODO: is it safe?
        unchecked {
            c = (a * b) >> 96;
        }
    }

    function div96(uint a, uint b)
        internal
        pure
        returns (uint c)
    {
        //TODO: is it safe?
        unchecked {
            c = (a << 96) / b;
        }
    }

    function distributeFees(
        MpContext memory ctx,
        MpOutcome memory r,
        uint totalEarnedFees,
        uint refund
    )
        internal
        pure
    {
           uint managerEarnedFee = mul32(totalEarnedFees, ctx.managementBaseFee);
           uint lpEarnedFee = mul32(totalEarnedFees, ctx.lpBaseFee);
           r.oracleEarnedFee = totalEarnedFees - managerEarnedFee - lpEarnedFee;
           r.managerEarnedFee = managerEarnedFee;
           r.lpEarnedFee = lpEarnedFee;
           r.cashbacksRefund = refund;
    }

    function deviation(
        uint quantity,
        uint price,
        uint tvl,
        uint targetShare
    )
        internal
        pure
        returns (uint d)
    {
        //TODO: is it safe?
        unchecked {
            if (tvl == 0) return 0;
            d = subAbs((quantity * price << FixedPoint32.RESOLUTION) / tvl, targetShare);
        }
    }

    function calculateSwapFees(
        MpContext memory ctx,
        MpAsset memory assetIn,
        MpAsset memory assetOut,
        uint swapAmount,
        bool isExactInput,
        uint priceIn,
        uint priceOut,
        uint sharePrice
    )
        internal
        pure
        returns (MpOutcome memory r)
    {
        if (assetIn.targetShare == 0) revert IMultipoolErrors.TargetShareIsZero();

        uint quoteDelta;
        uint amountIn;
        uint amountOut;

        if (isExactInput) {
            quoteDelta = mul96(swapAmount, priceIn);
            amountIn = swapAmount;
            amountOut = div96(quoteDelta, priceOut);

        } else {
            quoteDelta = mul96(swapAmount, priceOut);
            amountIn = div96(quoteDelta, priceIn);
            amountOut = swapAmount;
        }

        uint newQuantityIn = assetIn.quantity + amountIn;
        uint newQuantityOut = assetOut.quantity - amountOut;

        r.amountIn = amountIn;
        r.amountOut = amountOut;

        assetIn.quantity = uint128(newQuantityIn);
        assetOut.quantity = uint128(newQuantityOut);

        uint totalEarnedFees = mul32(quoteDelta, ctx.baseFee);

        uint tvl = ctx.totalSupply * sharePrice;
        if (tvl == 0 || (ctx.deviationIncreaseFee == 0 && ctx.deviationLimit == 0)) {
            distributeFees(ctx, r, totalEarnedFees, 0);
            return r;
        }

        uint dNewIn;
        uint dNewOut;
        uint dOldIn;
        uint dOldOut;

        {{
            uint targetShareIn = div32(uint(assetIn.targetShare), ctx.totalTargetShares);
            dOldIn = deviation(assetIn.quantity, priceIn, tvl, targetShareIn);
            dNewIn = deviation(newQuantityIn, priceIn, tvl, targetShareIn);
        }}

        {{
            uint targetShareOut = div32(uint(assetOut.targetShare), ctx.totalTargetShares);
            dOldOut = deviation(assetOut.quantity, priceOut, tvl, targetShareOut);
            dNewOut = deviation(newQuantityOut, priceOut, tvl, targetShareOut);
        }}

        uint refund;

        if (dNewIn > dOldIn && dNewOut > dOldOut) {
            if (ctx.deviationLimit < dNewIn || ctx.deviationLimit < dNewOut) revert IMultipoolErrors.DeviationExceedsLimit();

            uint fullDeviationFee = mul32(ctx.deviationIncreaseFee, quoteDelta);
            uint collectedCashback = mul32(fullDeviationFee, ctx.feeToCashbackRatio);

            //TODO: is this safe?
            unchecked { totalEarnedFees += (fullDeviationFee - collectedCashback) * 2; }
            assetIn.collectedCashbacks += uint112(collectedCashback);
            assetOut.collectedCashbacks += uint112(collectedCashback);
        } else {
            if (dNewIn > dOldIn) {
                if (ctx.deviationLimit < dNewIn) revert IMultipoolErrors.DeviationExceedsLimit();

                uint fullDeviationFee = mul32(ctx.deviationIncreaseFee, quoteDelta);
                uint collectedCashback = mul32(fullDeviationFee, ctx.feeToCashbackRatio);

                //TODO: is this safe?
                unchecked { totalEarnedFees += (fullDeviationFee - collectedCashback); }
                assetIn.collectedCashbacks += uint112(collectedCashback);
            } else {
                uint cb = cashback(dOldIn, dNewIn, assetIn.collectedCashbacks);
                refund += cb;
                assetIn.collectedCashbacks -= uint112(cb);
            }
            if (dNewOut > dOldOut) {
                if (ctx.deviationLimit < dNewOut) revert IMultipoolErrors.DeviationExceedsLimit();

                uint fullDeviationFee = mul32(ctx.deviationIncreaseFee, quoteDelta);
                uint collectedCashback = mul32(fullDeviationFee, ctx.feeToCashbackRatio);

                unchecked { totalEarnedFees += (fullDeviationFee - collectedCashback); }
                assetIn.collectedCashbacks += uint112(collectedCashback);
            } else {
                uint cb = cashback(dOldOut, dNewOut, assetOut.collectedCashbacks);
                refund += cb;
                assetIn.collectedCashbacks -= uint112(cb);
            }
        }

        distributeFees(ctx, r, totalEarnedFees, refund);
    }

    function calculateMintFees(
        MpContext memory ctx,
        MpAsset memory assetIn,
        uint swapAmount,
        bool isExactInput,
        uint priceIn,
        uint sharePrice
    )
        internal
        pure
        returns (MpOutcome memory r)
    {
        if (assetIn.targetShare == 0) revert IMultipoolErrors.TargetShareIsZero();

        uint quoteDelta;
        uint amountIn;
        uint amountOut;

        if (isExactInput) {
            quoteDelta = mul96(swapAmount, priceIn);
            amountIn = swapAmount;
            amountOut = div96(quoteDelta, sharePrice);

        } else {
            quoteDelta = mul96(swapAmount, sharePrice);
            amountIn = div96(quoteDelta, priceIn);
            amountOut = swapAmount;
        }

        uint newQuantityIn = assetIn.quantity + amountIn;
        assetIn.quantity = uint128(newQuantityIn);

        r.amountIn = amountIn;
        r.amountOut = amountOut;

        uint totalEarnedFees = mul32(quoteDelta, ctx.baseFee);

        uint tvl = ctx.totalSupply * sharePrice;
        if (tvl == 0 || (ctx.deviationIncreaseFee == 0 && ctx.deviationLimit == 0)) {
            distributeFees(ctx, r, totalEarnedFees, 0);
            return r;
        }

        uint dNewIn;
        uint dOldIn;

        {{
            uint targetShareIn = div32(uint(assetIn.targetShare), ctx.totalTargetShares);
            dOldIn = deviation(assetIn.quantity, priceIn, tvl, targetShareIn);
            dNewIn = deviation(newQuantityIn, priceIn, tvl + quoteDelta, targetShareIn);
        }}

        uint refund;

        if (dNewIn > dOldIn) {
            if (ctx.deviationLimit < dNewIn) revert IMultipoolErrors.DeviationExceedsLimit();

            uint fullDeviationFee = mul32(ctx.deviationIncreaseFee, quoteDelta);
            uint collectedCashback = mul32(fullDeviationFee, ctx.feeToCashbackRatio);

            //TODO: is this safe?
            unchecked { totalEarnedFees += (fullDeviationFee - collectedCashback); }
            assetIn.collectedCashbacks += uint112(collectedCashback);
        } else {
            uint cb = cashback(dOldIn, dNewIn, assetIn.collectedCashbacks);
            refund += cb;
            assetIn.collectedCashbacks -= uint112(cb);
        }

        distributeFees(ctx, r, totalEarnedFees, refund);
    }

    function calculateBurnFees(
        MpContext memory ctx,
        MpAsset memory assetOut,
        uint swapAmount,
        bool isExactInput,
        uint priceOut,
        uint sharePrice
    )
        internal
        pure
        returns (MpOutcome memory r)
    {
        uint quoteDelta;
        uint amountIn;
        uint amountOut;

        if (isExactInput) {
            quoteDelta = mul96(swapAmount, sharePrice);
            amountIn = swapAmount;
            amountOut = div96(quoteDelta, priceOut);

        } else {
            quoteDelta = mul96(swapAmount, priceOut);
            amountIn = div96(quoteDelta, sharePrice);
            amountOut = swapAmount;
        }

        uint newQuantityOut = assetOut.quantity + amountIn;
        assetOut.quantity = uint128(newQuantityOut);

        r.amountIn = amountIn;
        r.amountOut = amountOut;

        uint totalEarnedFees = mul32(quoteDelta, ctx.baseFee);

        uint tvl = ctx.totalSupply * sharePrice;
        if (tvl == 0 || (ctx.deviationIncreaseFee == 0 && ctx.deviationLimit == 0)) {
            distributeFees(ctx, r, totalEarnedFees, 0);
            return r;
        }

        uint dNewOut;
        uint dOldOut;

        {{
            uint targetShareIn = div32(uint(assetOut.targetShare), ctx.totalTargetShares);
            dOldOut = deviation(assetOut.quantity, priceOut, tvl, targetShareIn);
            dNewOut = deviation(newQuantityOut, priceOut, tvl - quoteDelta, targetShareIn);
        }}

        uint refund;

        if (dNewOut > dOldOut) {
            if (ctx.deviationLimit < dNewOut) revert IMultipoolErrors.DeviationExceedsLimit();

            uint fullDeviationFee = mul32(ctx.deviationIncreaseFee, quoteDelta);
            uint collectedCashback = mul32(fullDeviationFee, ctx.feeToCashbackRatio);

            //TODO: is this safe?
            unchecked { totalEarnedFees += (fullDeviationFee - collectedCashback); }
            assetOut.collectedCashbacks += uint112(collectedCashback);
        } else {
            uint cb = cashback(dOldOut, dNewOut, assetOut.collectedCashbacks);
            refund += cb;
            assetOut.collectedCashbacks -= uint112(cb);
        }

        distributeFees(ctx, r, totalEarnedFees, refund);
    }
}
