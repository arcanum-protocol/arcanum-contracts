// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FixedPoint96, FixedPoint32} from "./FixedPoint.sol";
import {getBits, setBits} from "./Binary.sol";
import {expandFrom20, expandFrom19} from "./MpContext.sol";
import {IMultipoolErrors} from "../interfaces/multipool/IMultipoolErrors.sol";
import "forge-std/Script.sol";

library MpMath {
    uint public constant ONE = 1<<96;

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function calculateSwap(
        uint totalSupply,
        uint sharePrice,
        uint totalTargetShares,

        uint deviationMultiplier, // K
        uint deviationOffset, // B
        uint deviationLimit,
        uint cashbackMax,
        uint cashbackFeeShare,
        uint baseFee,

        uint protocolFee,
        uint managementFee,

        bool isMint,
        bool isBurn,

        //Asset in
        uint reserveIn,
        uint priceIn,
        uint collectedCashbacksIn,
        uint targetShareIn,
        uint deltaIn,
        //Asset out
        uint reserveOut,
        uint priceOut,
        uint collectedCashbacksOut,
        uint targetShareOut,
        uint deltaOut
    )
        internal
        pure
        returns (
            uint managerEarnedFee,
            uint protocolEarnedFee,
            uint newCollectedCashbacksIn,
            uint newCollectedCashbacksOut
        )
    {
        uint tvl = totalSupply * sharePrice;
        
        // baseFee logic
        (
            uint quoteLeft,
            uint cashbackIn,
            uint feeIn
        ) = calculateX(totalSupply, tvl, sharePrice, deviationMultiplier, deviationOffset, cashbackMax, cashbackFeeShare, baseFee, reserveIn, priceIn, collectedCashbacksIn, targetShareIn, deltaIn);
        
        (
            uint quoteRight,
            uint cashbackOut,
            uint feeOut
        ) = calculateY(totalSupply, tvl, sharePrice, deviationMultiplier, deviationOffset, cashbackMax, cashbackFeeShare, baseFee, reserveOut, priceOut, collectedCashbacksOut, targetShareOut, deltaOut);
        
        // assert(quoteLeft >= quoteRight, "Incorrect invariant");

    }

    function calculateX(
        uint totalSupply,
        uint tvl, // no offset
        uint sharePrice,
        uint deviationMultiplier, // K
        uint deviationOffset, // B
        uint cashbackMax,
        uint cashbackFeeShare,
        uint baseFee,

        //Asset in
        uint reserveIn,
        uint priceIn,
        uint collectedCashbacksIn,
        uint targetShareIn,
        uint deltaIn

    )   internal
        pure
        returns (
            uint quoteOut,
            uint cashback,
            uint fee
        )
    {
        uint shareOld = reserveIn * priceIn / tvl; // << 96
        uint targetShare = targetShareIn; // 96
        uint quote = deltaIn * priceIn; // << 96
        uint deviationDelta = quote / tvl; // << 96
        uint noFee = ((quote >> 96) * (ONE - baseFee)) >> 96; // no offset
        uint deviationOld;
        uint deviationFee;

        if (shareOld > targetShare) { // both << 96
            deviationOld = shareOld - targetShare; // << 96

        // deviationMultiplier * (deviationOld + deviationDelta * (1 - cashbackFeeShare) )
        // FdIn(∆Din) = K · (|DoIn + ∆Din · [1 − rd · FdIn(∆Din)]| − |DoIn|) + B
            // (K*(D_oin-|D_oin|+D_delta)+B)/(1+r*k*D_delta)
            deviationFee = // <<96
                ((((deviationMultiplier * deviationDelta) >> 96) + deviationOffset) << 96) // (96 * 96 + 96) === 96*2
                / (ONE + ((((deviationMultiplier * deviationDelta) >> 96) * cashbackFeeShare) >> 96)); // << 96 - (96 * 96 >> 96 * 96 >> 96) === 96
            return ((noFee * (ONE - deviationFee)) >> 96, 0, (noFee * deviationFee) >> 96);
        }
        deviationOld = targetShare - shareOld; // << 96
        if (deviationDelta < deviationOld) { // deviation old < 0 and d_o + d_delta < 0
            console2.log("here2");
            cashback = min(
                min(
                    deviationDelta * collectedCashbacksIn / (deviationOld), // no off
                    deltaIn * cashbackMax >> 96 // no off
                ),
                (deviationOld - deviationDelta) * totalSupply * sharePrice / priceIn >> 96 // (96 - 96) * no off * 96 / 96 >> 96 == no off
            );
            return (noFee + (cashback * priceIn >> 96), (cashback * priceIn >> 96), 0);
        } else if (deviationDelta > 2 * deviationOld) { // 96 > 96
            console2.log("here3");
            deviationFee = // 96
                (deviationMultiplier * (deviationDelta - 2 * deviationOld) >> 96 + deviationOffset) << 96 // 96 * (96 - 2 * 96) >> 96 + 96 == 96*2
                 / (ONE + deviationMultiplier * deviationDelta >> 96 * cashbackFeeShare >> 96); // (96 - 96 * 96 >> 96 * 96 >> 96) == 96
            return (noFee * (ONE - deviationFee) >> 96, 0, noFee * deviationFee >> 96);
        } else {
            return (noFee, 0, 0);
        }
    }

    function calculateY(
        uint totalSupply,
        uint tvl,
        uint sharePrice,
        uint deviationMultiplier, // K
        uint deviationOffset, // B
        uint cashbackMax,
        uint cashbackFeeShare,
        uint baseFee,

        //Asset in
        uint reserveOut,
        uint priceOut,
        uint collectedCashbacksOut,
        uint targetShareOut,
        uint deltaOut

    )   internal
        pure
        returns (
            uint quoteOut,
            uint cashback,
            uint fee
        )
    {
        uint shareOld = reserveOut * priceOut / tvl; // << 96
        uint targetShare = targetShareOut; // 96
        uint quote = deltaOut * priceOut; // << 96
        uint deviationDelta = quote / tvl; // << 96
        uint noFee = ((quote >> 96) * (ONE - baseFee)) >> 96; // no offset
        uint deviationOld;
        uint deviationFee;

        if (targetShareOut > shareOld) { // deviation old > 0
            deviationFee = // <<96
                ((((deviationMultiplier * deviationDelta) >> 96) + deviationOffset) << 96) // (96 * 96 + 96) === 96*2
                / (ONE - ((((deviationMultiplier * deviationDelta) >> 96) * cashbackFeeShare) >> 96)); // << 96 - (96 * 96 >> 96 * 96 >> 96) === 96
            return ((noFee * (ONE - deviationFee)) >> 96, 0, (noFee * deviationFee) >> 96);
        }
        deviationOld = shareOld - targetShareOut;
        if (deviationDelta < deviationOld) { // deviation old < 0 and d_o + d_delta < 0
            console2.log("here2");
            cashback = min(
                    deviationDelta * collectedCashbacksOut / (deviationOld), // no off
                    deltaOut * cashbackMax >> 96 // no off
                );
            return (noFee + (cashback * priceOut >> 96), (cashback * priceOut >> 96), 0);
        } else if (deviationDelta > 2 * deviationOld) { // 96 > 96
            console2.log("here3");
            deviationFee = // 96
                (deviationMultiplier * (deviationDelta - 2 * deviationOld) >> 96 + deviationOffset) << 96 // 96 * (96 - 2 * 96) >> 96 + 96 == 96*2
                 / (ONE - deviationMultiplier * deviationDelta >> 96 * cashbackFeeShare >> 96); // (96 - 96 * 96 >> 96 * 96 >> 96) == 96
            return (noFee * (ONE - deviationFee) >> 96, 0, noFee * deviationFee >> 96);
        } else {
            return (noFee, 0, 0);
        }
    }

    function calculateLp(
        uint sharePrice,
        uint delta

    )   internal
        pure
        returns (
            uint quote
        )
    {
        quote = delta * sharePrice >> 96;
    }
}  
