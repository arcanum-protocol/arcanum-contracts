// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import "hardhat/console.sol";

struct MpAsset {
    UD60x18 quantity;
    UD60x18 price;
    UD60x18 collectedFees;
    UD60x18 collectedCashbacks;
    UD60x18 percent;
}

struct MpContext {
    UD60x18 totalCurrentUsdAmount;
    UD60x18 totalAssetPercents;
    UD60x18 curveCoef;
    UD60x18 deviationPercentLimit;
    UD60x18 operationBaseFee;
    UD60x18 userCashbackBalance;
}

library MpMath {
    function mintRev(
        MpContext memory context,
        MpAsset memory asset,
        UD60x18 utilisableQuantity
    ) internal pure returns(UD60x18 suppliedQuantity) {
        if (context.totalCurrentUsdAmount == sd(0)) {
            context.totalCurrentUsdAmount = utilisableQuantity * asset.price;
            asset.quantity = asset.quantity + utilisableQuantity; 
            return utilisableQuantity;
        }
        UD60x18 deviationNew = ((asset.quantity + utilisableQuantity) * asset.price 
                / (context.totalCurrentUsdAmount + utilisableQuantity * asset.price) - asset.percent / context.totalAssetPercents).abs();
        UD60x18 deviationOld = (asset.quantity * asset.price 
                / context.totalCurrentUsdAmount - asset.percent / context.totalAssetPercents).abs();

        if (deviationNew <= deviationOld) {
            SD59x18 cashback;
            if (deviationOld != sd(0)) {
                cashback = asset.collectedCashbacks * (deviationOld - deviationNew) / deviationOld;
            }
            asset.collectedCashbacks = asset.collectedCashbacks - cashback;
            context.userCashbackBalance = context.userCashbackBalance + cashback;
            suppliedQuantity = utilisableQuantity + utilisableQuantity * context.operationBaseFee;
        } else {
            require(deviationNew < context.deviationPercentLimit, "deviation overflows limit");

            SD59x18 collectedDeviationFee = context.curveCoef * deviationNew * utilisableQuantity 
            / context.deviationPercentLimit / (context.deviationPercentLimit - deviationNew);
            asset.collectedCashbacks = asset.collectedCashbacks + collectedDeviationFee;
            suppliedQuantity = utilisableQuantity + 
                utilisableQuantity * context.operationBaseFee + collectedDeviationFee;
        }

        asset.quantity = asset.quantity + utilisableQuantity; 
        context.totalCurrentUsdAmount = context.totalCurrentUsdAmount + utilisableQuantity * asset.price;
        asset.collectedFees = asset.collectedFees + utilisableQuantity * context.operationBaseFee;
    }

    function burnRev(
        MpContext memory context,
        MpAsset memory asset,
        SD59x18 utilisableQuantity 
    ) internal pure returns(SD59x18 suppliedQuantity) {
        require(utilisableQuantity <= asset.quantity, "can't burn more assets than exist");

        UD60x18 withFees = getSuppliableBurnQuantity(utilisableQuantity, context, asset);
        UD60x18 noFees = utilisableQuantity * (sd(1e18) + context.operationBaseFee);

        UD60x18 deviationWithFees = ((asset.quantity - withFees) * asset.price 
                / (context.totalCurrentUsdAmount - withFees * asset.price) - asset.percent / context.totalAssetPercents).abs();
        UD60x18 deviationNoFees = ((asset.quantity - noFees) * asset.price 
                / (context.totalCurrentUsdAmount - noFees * asset.price) - asset.percent / context.totalAssetPercents).abs();
        UD60x18 deviationOld = (asset.quantity * asset.price 
                / context.totalCurrentUsdAmount - asset.percent / context.totalAssetPercents).abs();

        if (deviationNoFees <= deviationOld) {
            suppliedQuantity = noFees;
            require(suppliedQuantity <= asset.quantity, "can't burn more assets than exist");

            SD59x18 cashback;
            if (deviationOld != sd(0)) {
                cashback = asset.collectedCashbacks * (deviationOld - deviationNoFees) / deviationOld;
            }

            asset.collectedCashbacks = asset.collectedCashbacks - cashback;
            context.userCashbackBalance = context.userCashbackBalance + cashback;
        } else {
            suppliedQuantity = withFees;
            require(suppliedQuantity <= asset.quantity, "can't burn more assets than exist");
            require(deviationWithFees < context.deviationPercentLimit, 
                    "deviation overflows limit");
            require(withFees != sd(0), "no curve solutions found");

            SD59x18 _operationBaseFee = context.operationBaseFee;
            asset.collectedCashbacks = asset.collectedCashbacks + 
                (suppliedQuantity - utilisableQuantity * (sd(1e18) + _operationBaseFee));
        }

        asset.quantity = asset.quantity - suppliedQuantity; 
        context.totalCurrentUsdAmount = context.totalCurrentUsdAmount - suppliedQuantity * asset.price;
        asset.collectedFees = asset.collectedFees + utilisableQuantity * context.operationBaseFee;
    }

    function mint(
        MpContext memory context,
        MpAsset memory asset,
        SD59x18 suppliedQuantity 
    ) internal pure returns(SD59x18 utilisableQuantity) {
        if (context.totalCurrentUsdAmount == sd(0)) {
            context.totalCurrentUsdAmount = suppliedQuantity * asset.price;
            asset.quantity = asset.quantity + suppliedQuantity; 
            return suppliedQuantity;
        }
        SD59x18 withFees = getUtilisableMintQuantity(suppliedQuantity, context, asset);
        SD59x18 noFees = suppliedQuantity / (sd(1e18) + context.operationBaseFee);

        SD59x18 deviationWithFees = ((asset.quantity + withFees) * asset.price 
                / (context.totalCurrentUsdAmount + withFees * asset.price) - asset.percent / context.totalAssetPercents).abs();
        SD59x18 deviationNoFees = ((asset.quantity + noFees) * asset.price 
                / (context.totalCurrentUsdAmount + noFees * asset.price) - asset.percent / context.totalAssetPercents).abs();
        SD59x18 deviationOld = (asset.quantity * asset.price 
                / context.totalCurrentUsdAmount - asset.percent / context.totalAssetPercents).abs();

        if (deviationNoFees <= deviationOld) {
            utilisableQuantity = noFees;
            require (deviationNoFees <= deviationOld, "deviation no fees should be lower than old");

            SD59x18 cashback;
            if (deviationOld != sd(0)) {
                cashback = asset.collectedCashbacks * (deviationOld - deviationNoFees) / deviationOld;
            }

            asset.collectedCashbacks = asset.collectedCashbacks - cashback;

            context.userCashbackBalance = context.userCashbackBalance + cashback;
        } else {
            require(deviationWithFees < context.deviationPercentLimit, 
                    "deviation overflows limit");
            require(withFees != sd(0), "no curve solutions found");

            utilisableQuantity = withFees;
            // straightforward form but seems like it is not so good in accuracy,
            // base fee is easy to compute bc of one multiplication so to keep
            // deviation fee + base fee + utilisable val = supplied val
            // we use substraction here
           // SD59x18 cashbacks = asset.collectedCashbacks + 
           //     context.curveCoef * deviationWithFees * utilisableQuantity 
           //     / context.deviationPercentLimit / (context.deviationPercentLimit - deviationWithFees);
           // require(cashbacks + utilisableQuantity 
           //         * (sd(1e18) + context.operationBaseFee) == suppliedQuantity, "deviation overflows limit");
           // asset.collectedCashbacks = asset.collectedCashbacks + cashbacks;
            SD59x18 _operationBaseFee = context.operationBaseFee;
            asset.collectedCashbacks = asset.collectedCashbacks + 
                (suppliedQuantity - utilisableQuantity * (sd(1e18) + _operationBaseFee));
        }

        asset.quantity = asset.quantity + utilisableQuantity; 
        context.totalCurrentUsdAmount = context.totalCurrentUsdAmount + utilisableQuantity * asset.price;
        asset.collectedFees = asset.collectedFees + utilisableQuantity * context.operationBaseFee;
    }

    function burn(
        MpContext memory context,
        MpAsset memory asset,
        SD59x18 suppliedQuantity
    ) internal pure returns(SD59x18 utilisableQuantity) {
        require(suppliedQuantity <= asset.quantity, "can't burn more assets than exist");
        SD59x18 deviationNew = ((asset.quantity - suppliedQuantity) * asset.price 
                / (context.totalCurrentUsdAmount - suppliedQuantity * asset.price) - asset.percent / context.totalAssetPercents).abs();
        SD59x18 deviationOld = (asset.quantity * asset.price 
                / context.totalCurrentUsdAmount - asset.percent / context.totalAssetPercents).abs();

        if (deviationNew <= deviationOld) {
            SD59x18 cashback;
            if (deviationOld != sd(0)) {
                cashback = asset.collectedCashbacks * (deviationOld - deviationNew) / deviationOld;
            }
            asset.collectedCashbacks = asset.collectedCashbacks - cashback;
            context.userCashbackBalance = context.userCashbackBalance + cashback;
            utilisableQuantity = suppliedQuantity / (sd(1e18) + context.operationBaseFee);
        } else {
            require(deviationNew.abs() < context.deviationPercentLimit, "deviation overflows limit");

            SD59x18 feeRatio = context.curveCoef * deviationNew 
                / context.deviationPercentLimit / (context.deviationPercentLimit - deviationNew);

            utilisableQuantity = suppliedQuantity / (sd(1e18) + feeRatio + context.operationBaseFee);

            asset.collectedCashbacks = asset.collectedCashbacks 
                + (suppliedQuantity - utilisableQuantity * (sd(1e18) + context.operationBaseFee));
        }

        asset.quantity = asset.quantity - suppliedQuantity; 
        context.totalCurrentUsdAmount = context.totalCurrentUsdAmount - suppliedQuantity * asset.price;
        asset.collectedFees = asset.collectedFees + utilisableQuantity * context.operationBaseFee;
    }

    function getUtilisableMintQuantity(
        SD59x18 suppliedQuantity,
        MpContext memory context,
        MpAsset memory asset
    ) internal pure returns(SD59x18 utilisableQuantity){
        
        SD59x18 B = (sd(1e18) + context.operationBaseFee);
        SD59x18 m = sd(1e18) - asset.percent / context.totalAssetPercents;
        SD59x18 C = context.curveCoef / context.deviationPercentLimit;

        {{
            SD59x18 a = (B * (context.deviationPercentLimit - m) + C * m) * asset.price;
            SD59x18 b = (context.deviationPercentLimit - m) 
                * (context.totalCurrentUsdAmount * B - suppliedQuantity * asset.price) 
                - (B - C) * (asset.quantity * asset.price - context.totalCurrentUsdAmount)
                + C * m * context.totalCurrentUsdAmount;
            SD59x18 c = (asset.quantity * asset.price - context.totalCurrentUsdAmount) * suppliedQuantity
                - (context.deviationPercentLimit - m) * context.totalCurrentUsdAmount * suppliedQuantity;

            SD59x18 d = b.powu(2) - sd(4e18) * a * c;
            
            SD59x18 cmp;
            {{
                cmp = - (asset.quantity * asset.price 
                    + context.totalCurrentUsdAmount * (m - sd(1e18))) / (m * asset.price);
            }}


            if (d >= sd(0)) {
                d = d.sqrt();
                SD59x18 x1 = (-b-d) / sd(2e18) / a;
                SD59x18 x2 = (-b+d) / sd(2e18) / a;

                SD59x18 _suppliedQuantity = suppliedQuantity;

                {
                    if (x1 > cmp && x1 > sd(0) && x1 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x1;
                    }
                    if (x2 > cmp && x2 > sd(0) && x2 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x2;
                    }
                }
            }
        }}

        {{
            SD59x18 a = (B * (context.deviationPercentLimit + m) - C * m) * asset.price;
            SD59x18 b = (context.deviationPercentLimit + m) 
                * (context.totalCurrentUsdAmount * B - suppliedQuantity * asset.price) 
                + (B - C) * (asset.quantity * asset.price - context.totalCurrentUsdAmount)
                - C * m * context.totalCurrentUsdAmount;
            SD59x18 c = -(asset.quantity * asset.price - context.totalCurrentUsdAmount) * suppliedQuantity
                - (context.deviationPercentLimit + m) * context.totalCurrentUsdAmount * suppliedQuantity;

            SD59x18 d = b.powu(2) - sd(4e18) * a * c;

            SD59x18 cmp;
            {{
                cmp = - (asset.quantity * asset.price 
                    + context.totalCurrentUsdAmount * (m - sd(1e18))) / (m * asset.price);
            }}


            if (d >= sd(0)) {
                d = d.sqrt();
                SD59x18 x3 = (-b-d) / sd(2e18) / a;
                SD59x18 x4 = (-b+d) / sd(2e18) / a;

                SD59x18 _suppliedQuantity = suppliedQuantity;
                {
                    if (x3 < cmp && x3 > sd(0) && x3 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x3;
                    }
                    if (x4 < cmp && x4 > sd(0) && x4 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x4;
                    }
                }
            }
        }}
    }

    function getSuppliableBurnQuantity(
        SD59x18 utilisableQuantity, 
        MpContext memory context,
        MpAsset memory asset
    ) internal pure returns(SD59x18 suppliedQuantity){

        SD59x18 B = (sd(1e18) + context.operationBaseFee);
        SD59x18 m = sd(1e18) - asset.percent / context.totalAssetPercents;
        SD59x18 C = context.curveCoef / context.deviationPercentLimit;

        {{
            SD59x18 a = - (context.deviationPercentLimit - m) * asset.price;
            SD59x18 b = ((B * asset.price * utilisableQuantity) 
                + context.totalCurrentUsdAmount)
                * (context.deviationPercentLimit - m)
                + C * m * asset.price * utilisableQuantity
                - (asset.quantity * asset.price - context.totalCurrentUsdAmount);
            SD59x18 c = - B * context.totalCurrentUsdAmount * utilisableQuantity 
                * (context.deviationPercentLimit - m)
                + (asset.quantity * asset.price - context.totalCurrentUsdAmount) * utilisableQuantity
                * (B - C) - C * m * context.totalCurrentUsdAmount * utilisableQuantity;

            SD59x18 d = b.powu(2) - sd(4e18) * a * c;

            SD59x18 q = (asset.quantity * asset.price - context.totalCurrentUsdAmount);
            SD59x18 t = context.totalCurrentUsdAmount;
            SD59x18 p = asset.price;
            SD59x18 dl = context.deviationPercentLimit;
            SD59x18 cmp = (q + m*t) / (m * p);

            if (d >= sd(0)) {
                d = d.sqrt();
                SD59x18 x1 = (-b-d) / sd(2e18) / a;
                SD59x18 x2 = (-b+d) / sd(2e18) / a;

                {{
                    if ( (m + q / (t - x1 * p)).abs() < dl && x1 < cmp) {
                        suppliedQuantity = suppliedQuantity > x1 || suppliedQuantity == sd(0) ? x1 : suppliedQuantity;
                    }
                }}
                {{
                    if ( (m + q / (t - x2 * p)).abs() < dl && x2 < cmp) {
                        suppliedQuantity = suppliedQuantity > x2 || suppliedQuantity == sd(0) ? x2 : suppliedQuantity;
                    }
                }}
            }
        }}

        {{
            SD59x18 a = (context.deviationPercentLimit + m) * asset.price;
            SD59x18 b = - ((B * asset.price * utilisableQuantity) 
                + context.totalCurrentUsdAmount)
                * (context.deviationPercentLimit + m)
                + C * m * asset.price * utilisableQuantity
                - (asset.quantity * asset.price - context.totalCurrentUsdAmount);
            SD59x18 c = B * context.totalCurrentUsdAmount * utilisableQuantity 
                * (context.deviationPercentLimit + m)
                + (asset.quantity * asset.price - context.totalCurrentUsdAmount) * utilisableQuantity
                * (B - C) - C * m * context.totalCurrentUsdAmount * utilisableQuantity;

            SD59x18 d = b.powu(2) - sd(4e18) * a * c;

            SD59x18 q = (asset.quantity * asset.price - context.totalCurrentUsdAmount);
            SD59x18 t = context.totalCurrentUsdAmount;
            SD59x18 p = asset.price;
            SD59x18 dl = context.deviationPercentLimit;
            SD59x18 cmp = (q + m*t) / (m * p);

            if (d >= sd(0)) {
                d = d.sqrt();
                SD59x18 x3 = (-b-d) / sd(2e18) / a;
                SD59x18 x4 = (-b+d) / sd(2e18) / a;

                {{
                    if ( (m + q / (t - x3 * p)).abs() < dl && x3 > cmp) {
                        suppliedQuantity = suppliedQuantity > x3 || suppliedQuantity == sd(0) ? x3 : suppliedQuantity;
                    }
                }}
                {{
                    if ( (m + q / (t - x4 * p)).abs() < dl && x4 > cmp) {
                        suppliedQuantity = suppliedQuantity > x4 || suppliedQuantity == sd(0) ? x4 : suppliedQuantity;
                    }
                }}
            }
        }}
    }
}

using {
    MpMath.mintRev, 
    MpMath.burnRev, 
    MpMath.mint, 
    MpMath.burn
} for MpContext global;
