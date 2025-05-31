// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FixedPoint96, FixedPoint32} from "./FixedPoint.sol";
import {getBits, setBits} from "./Binary.sol";
import {IMultipoolErrors} from "../interfaces/multipool/IMultipoolErrors.sol";
import "forge-std/Script.sol";

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

function unpackMpAsset(bytes32 b)
    pure
    returns (bool isUsed, uint quantity, uint collectedCashbacks, uint targetShare)
{
    isUsed = getBits(b, 0, 1) != 0;
    quantity = getBits(b, 1, 127);
    targetShare = getBits(b, 128, 16);
    collectedCashbacks = getBits(b, 144, 112);
}

function packMpAsset(
    bool isUsed,
    uint quantity,
    uint targetShare,
    uint collectedCashbacks
)
    pure
    returns (bytes32 b)
{
    b = setBits(b, bytes32(uint(isUsed ? 1 : 0)), 0, 1);
    b = setBits(b, bytes32(uint(quantity)), 1, 127);
    b = setBits(b, bytes32(uint(targetShare)), 128, 16);
    b = setBits(b, bytes32(uint(collectedCashbacks)), 144, 112);
}

function expandFrom20(uint val) pure returns (uint res) {
    unchecked {
        res = val * (1 << 32) / 1e6;
    }
}

function expandFrom19(uint val) pure returns (uint res) {
    unchecked {
        res = val * (2 << 32) / 1e6;
    }
}

function expandFrom16(uint val) pure returns (uint res) {
    unchecked {
        res = val * (5 << 32) / 1e5;
    }
}

function unpackMpFees1(bytes32 b)
    pure
    returns (
        address oracleAddress,
        uint deviationIncreaseFee,
        uint feeToCashbackRatio,
        uint baseFee,
        uint lpFee,
        uint managementFee
    )
{
    //address internal oracleAddress;
    //uint19 internal deviationIncreaseFee;
    //uint19 internal feeToCashbackRatio;
    //uint20 internal baseFee;
    //uint19 internal lpFee;
    //uint19 internal managementFee;
    oracleAddress = address(uint160(getBits(b, 0, 160)));
    deviationIncreaseFee = getBits(b, 160, 19);
    feeToCashbackRatio = expandFrom19(getBits(b, 179, 19));
    baseFee = getBits(b, 198, 20);
    lpFee = expandFrom19(getBits(b, 218, 19));
    managementFee = expandFrom19(getBits(b, 237, 19));
}

function packMpFees1(
    address oracleAddress,
    uint deviationIncreaseFee,
    uint feeToCashbackRatio,
    uint baseFee,
    uint lpFee,
    uint managerFee
)
    pure
    returns (bytes32 slot)
{
    slot = setBits(slot, bytes32(uint(uint160(oracleAddress))), 0, 160);
    slot = setBits(slot, bytes32(uint(deviationIncreaseFee)), 160, 19);
    slot = setBits(slot, bytes32(uint(feeToCashbackRatio)), 179, 19);
    slot = setBits(slot, bytes32(uint(baseFee)), 198, 20);
    slot = setBits(slot, bytes32(uint(lpFee)), 218, 19);
    slot = setBits(slot, bytes32(uint(managerFee)), 237, 19);
}

function unpackMpFees2(bytes32 b)
    pure
    returns (
        uint _collectedLpFee,
        uint _collectedManagementFee,
        uint _totalTargetShares,
        uint _deviationLimit
    )
{
    _collectedLpFee = getBits(b, 0, 112);
    _collectedManagementFee = getBits(b, 112, 112);
    _totalTargetShares = getBits(b, 224, 16);
    _deviationLimit = getBits(b, 240, 16);
}

function packMpFees2(
    uint collectedLpFee,
    uint collectedManagerFee,
    uint totalTargetShares,
    uint deviationLimit
)
    pure
    returns (bytes32 slot)
{
    slot = setBits(slot, bytes32(collectedLpFee), 0, 112);
    slot = setBits(slot, bytes32(collectedManagerFee), 112, 112);
    slot = setBits(slot, bytes32(totalTargetShares), 224, 16);
    slot = setBits(slot, bytes32(deviationLimit), 240, 16);
}

library MpMath {
    
    function subAbs(uint a, uint b) internal pure returns (uint c) {
        unchecked {
            c = a > b ? a - b : b - a;
        }
    }

    function cashback(uint dOld, uint dNew, uint collectedCb) internal pure returns (uint c) {
        unchecked {
            if (dOld == 0) return collectedCb;
            c = (dOld - dNew) * collectedCb / dOld;
        }
    }

    function mul32(uint a, uint b) internal pure returns (uint c) {
        unchecked {
            c = (a * b) >> 32;
        }
    }

    function div32(uint a, uint b) internal pure returns (uint c) {
        unchecked {
            c = (a << 32) / b;
        }
    }

    function mul96(uint a, uint b) internal pure returns (uint c) {
        unchecked {
            c = (a * b) >> 96;
        }
    }

    function div96(uint a, uint b) internal pure returns (uint c) {
        unchecked {
            c = (a << 96) / b;
        }
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
        unchecked {
            if (tvl == 0) return 0;
            d = subAbs((quantity * price << FixedPoint32.RESOLUTION) / tvl, targetShare);
        }
    }

    function calculateSwap(
        uint totalSupply,
        uint totalTargetShares,
        uint deviationIncreaseFee,
        uint deviationLimit,
        uint feeToCashbackRatio,
        uint baseFee,
        uint lpBaseFee,
        uint managementBaseFee,
        //Asset in
        uint quantityIn,
        uint collectedCashbacksIn,
        uint targetShareIn,
        //Asset out
        uint quantityOut,
        uint collectedCashbacksOut,
        uint targetShareOut,
        bool isMint,
        bool isBurn,
        uint swapAmount,
        bool isExactInput,
        uint priceIn,
        uint priceOut,
        uint sharePrice
    )
        internal
        pure
        returns (
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,
            uint amountIn,
            uint amountOut,
            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        )
    {
        if (isMint && targetShareIn == 0) revert IMultipoolErrors.TargetShareIsZero();

        uint quoteDelta;

        if (isExactInput) {
            quoteDelta = mul96(swapAmount, priceIn);
            // quoteDelta = swapAmount.mul96(priceIn);
            amountIn = swapAmount;
            amountOut = div96(quoteDelta, priceOut);
            // amountOut = quoteDelta.div96(priceOut);
        } else {
            quoteDelta = mul96(swapAmount, priceOut);
            amountIn = div96(quoteDelta, priceIn);
            amountOut = swapAmount;
        }
        
        newQuantityIn = quantityIn + amountIn;
        if (!isMint) {
            newQuantityOut = quantityOut - amountOut;
        }
        // uint totalEarnedFees = mul32(quoteDelta, baseFee);
        uint totalEarnedFees = mul32(quoteDelta, baseFee);
        // uint totalEarnedFees = quoteDelta * baseFee;
        console2.log(totalEarnedFees);
        console2.log(quoteDelta);
        console2.log(baseFee);

        uint tvl = totalSupply * sharePrice;
        if (tvl == 0 || (deviationIncreaseFee == 0 && deviationLimit == 0)) {
            managerEarnedFee = mul32(totalEarnedFees, managementBaseFee);
            lpEarnedFee = mul32(totalEarnedFees, lpBaseFee);
            oracleEarnedFee = totalEarnedFees - managerEarnedFee - lpEarnedFee;
        }

        uint dOldIn;
        uint dNewIn;
        if (isMint) {
            targetShareIn = div32(uint(targetShareIn), totalTargetShares);
            dOldIn = deviation(quantityIn, priceIn, tvl, targetShareIn);
            dNewIn = deviation(newQuantityIn, priceIn, tvl, targetShareIn);
        }

        uint dOldOut;
        uint dNewOut;
        if (isBurn) {
            targetShareOut = div32(uint(targetShareOut), totalTargetShares);
            dOldOut = deviation(quantityOut, priceOut, tvl, targetShareOut);
            dNewOut = deviation(newQuantityOut, priceOut, tvl, targetShareOut);
        }

        if (!isMint && !isBurn && dNewIn > dOldIn && dNewOut > dOldOut) {
            if (deviationLimit < dNewIn || deviationLimit < dNewOut) {
                revert IMultipoolErrors.DeviationExceedsLimit();
            }

            uint fullDeviationFee = mul32(deviationIncreaseFee, quoteDelta);
            uint collectedCashback = mul32(fullDeviationFee, feeToCashbackRatio);

            unchecked {
                totalEarnedFees += (fullDeviationFee - collectedCashback) * 2;
            }
            newCollectedCashbacksIn = collectedCashbacksIn + collectedCashback;
            newCollectedCashbacksOut = collectedCashbacksOut + collectedCashback;
        } else {
            if (!isMint) {
                if (dNewIn > dOldIn) {
                    if (deviationLimit < dNewIn) revert IMultipoolErrors.DeviationExceedsLimit();

                    uint fullDeviationFee = mul32(deviationIncreaseFee, quoteDelta);
                    uint collectedCashback = mul32(fullDeviationFee, feeToCashbackRatio);

                    unchecked {
                        totalEarnedFees += (fullDeviationFee - collectedCashback);
                    }
                    newCollectedCashbacksIn = collectedCashbacksIn + collectedCashback;
                } else {
                    uint cb = cashback(dOldIn, dNewIn, collectedCashbacksIn);
                    cashbacksRefund += cb;
                    newCollectedCashbacksIn = collectedCashbacksIn - cb;
                }
            }
            if (!isBurn) {
                if (dNewOut > dOldOut) {
                    if (deviationLimit < dNewOut) revert IMultipoolErrors.DeviationExceedsLimit();

                    uint fullDeviationFee = mul32(deviationIncreaseFee, quoteDelta);
                    uint collectedCashback = mul32(fullDeviationFee, feeToCashbackRatio);

                    unchecked {
                        totalEarnedFees += (fullDeviationFee - collectedCashback);
                    }
                    newCollectedCashbacksOut = collectedCashbacksOut + collectedCashback;
                } else {
                    uint cb = cashback(dOldOut, dNewOut, collectedCashbacksOut);
                    cashbacksRefund += cb;
                    newCollectedCashbacksOut = collectedCashbacksOut - cb;
                }
            }
        }

        managerEarnedFee = mul32(totalEarnedFees, managementBaseFee);
        lpEarnedFee = mul32(totalEarnedFees, lpBaseFee);
        oracleEarnedFee = totalEarnedFees - managerEarnedFee - lpEarnedFee;
    }
}
