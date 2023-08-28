// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

uint constant DENOMINATOR = 1e18;

struct MpAsset {
    uint quantity;
    uint price;
    uint collectedFees;
    uint collectedCashbacks;
    uint share;
}

struct MpContext {
    uint usdCap;
    uint totalTargetShares;
    uint halfDeviationFee;
    uint deviationLimit;
    uint operationBaseFee;
    uint userCashbackBalance;
    uint depegBaseFee;
}

using {MpCommonMath.evalMint, MpCommonMath.evalBurn} for MpContext global;

library MpCommonMath {
    function abs(uint a, uint b) internal pure returns (uint c) {
        c = a > b ? a - b : b - a;
    }

    function evalMint(MpContext memory context, MpAsset memory asset, uint utilisableQuantity)
        internal
        pure
        returns (uint suppliedQuantity)
    {
        if (context.usdCap == 0) {
            context.usdCap = (utilisableQuantity * asset.price) / DENOMINATOR;
            asset.quantity += utilisableQuantity;
            return utilisableQuantity;
        }

        uint shareOld = (asset.quantity * asset.price) / context.usdCap;
        uint shareNew = ((asset.quantity + utilisableQuantity) * asset.price)
            / (context.usdCap + (utilisableQuantity * asset.price) / DENOMINATOR);
        uint targetShare = (asset.share * DENOMINATOR) / context.totalTargetShares;
        uint deviationNew = abs(shareNew, targetShare);
        uint deviationOld = abs(shareOld, targetShare);

        if (deviationNew <= deviationOld) {
            if (deviationOld != 0) {
                uint cashback = (asset.collectedCashbacks * (deviationOld - deviationNew)) / deviationOld;
                asset.collectedCashbacks -= cashback;
                context.userCashbackBalance += cashback;
            }
            suppliedQuantity = (utilisableQuantity * (1e18 + context.operationBaseFee)) / DENOMINATOR;
        } else {
            require(deviationNew < context.deviationLimit, "MULTIPOOL: deviation overflow");
            uint depegFee = (context.halfDeviationFee * deviationNew * utilisableQuantity) / context.deviationLimit
                / (context.deviationLimit - deviationNew);
            uint deviationBaseFee = (context.depegBaseFee * depegFee) / DENOMINATOR;
            asset.collectedCashbacks += depegFee - deviationBaseFee;
            asset.collectedFees += deviationBaseFee;
            suppliedQuantity = ((utilisableQuantity * (1e18 + context.operationBaseFee)) / DENOMINATOR + depegFee);
        }

        require(suppliedQuantity != 0, "MULTIPOOL: insufficient share");

        asset.quantity += utilisableQuantity;
        context.usdCap += (utilisableQuantity * asset.price) / DENOMINATOR;
        asset.collectedFees += (utilisableQuantity * context.operationBaseFee) / DENOMINATOR;
    }

    function evalBurn(MpContext memory context, MpAsset memory asset, uint suppliedQuantity)
        internal
        pure
        returns (uint utilisableQuantity)
    {
        require(suppliedQuantity <= asset.quantity, "MULTIPOOL: asset quantity exceeded");

        if (context.usdCap - (suppliedQuantity * asset.price) / DENOMINATOR != 0) {
            uint shareOld = (asset.quantity * asset.price) / context.usdCap;
            uint shareNew = ((asset.quantity - suppliedQuantity) * asset.price)
                / (context.usdCap - (suppliedQuantity * asset.price) / DENOMINATOR);
            uint targetShare = (asset.share * DENOMINATOR) / context.totalTargetShares;
            uint deviationNew = abs(shareNew, targetShare);
            uint deviationOld = abs(shareOld, targetShare);

            if (deviationNew <= deviationOld) {
                if (deviationOld != 0) {
                    uint cashback = (asset.collectedCashbacks * (deviationOld - deviationNew)) / deviationOld;
                    asset.collectedCashbacks -= cashback;
                    context.userCashbackBalance += cashback;
                }
                utilisableQuantity = (suppliedQuantity * DENOMINATOR) / (1e18 + context.operationBaseFee);
            } else {
                require(deviationNew < context.deviationLimit, "MULTIPOOL: deviation overflow");
                uint feeRatio = (context.halfDeviationFee * deviationNew * DENOMINATOR) / context.deviationLimit
                    / (context.deviationLimit - deviationNew);
                utilisableQuantity = (suppliedQuantity * DENOMINATOR) / (1e18 + feeRatio + context.operationBaseFee);

                uint depegFee =
                    suppliedQuantity - (utilisableQuantity * (1e18 + context.operationBaseFee)) / DENOMINATOR;
                uint deviationBaseFee = (context.depegBaseFee * depegFee) / DENOMINATOR;
                asset.collectedCashbacks += depegFee - deviationBaseFee;
                asset.collectedFees += deviationBaseFee;
            }
        } else {
            utilisableQuantity = (suppliedQuantity * DENOMINATOR) / (1e18 + context.operationBaseFee);
        }

        asset.quantity -= suppliedQuantity;
        context.usdCap -= (suppliedQuantity * asset.price) / DENOMINATOR;
        asset.collectedFees += (utilisableQuantity * context.operationBaseFee) / DENOMINATOR;
    }
}
