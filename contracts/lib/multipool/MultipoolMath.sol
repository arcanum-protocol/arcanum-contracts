// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "hardhat/console.sol";

library MultipoolMath {

    struct Asset {
        SD59x18 quantity;
        SD59x18 price;
        SD59x18 collectedFees;
        SD59x18 collectedCashbacks;
        SD59x18 percent;
    }

    struct Context {
        SD59x18 totalCurrentUsdAmount;
        SD59x18 totalAssetPercents;
        SD59x18 curveCoef;
        SD59x18 deviationPercentLimit;
        SD59x18 operationBaseFee;
        SD59x18 userCashbackBalance;
    }

    function reversedEvalMintContext(
        SD59x18 utilisableQuantity, 
        Context memory context,
        Asset memory asset
    ) internal returns(SD59x18 suppliedQuantity) {
        if (context.totalCurrentUsdAmount == sd(0)) {
            return utilisableQuantity;
        }
        SD59x18 deviationNew = ((asset.quantity + utilisableQuantity) * asset.price 
                / (context.totalCurrentUsdAmount + utilisableQuantity * asset.price) - asset.percent / context.totalAssetPercents).abs();
        SD59x18 deviationOld = (asset.quantity * asset.price 
                / context.totalCurrentUsdAmount - asset.percent / context.totalAssetPercents).abs();

        if (deviationNew < deviationOld) {
            SD59x18 cashback = asset.collectedCashbacks * (deviationOld - deviationNew) / deviationOld;
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

    function reversedEvalBurnContext(
        SD59x18 utilisableQuantity, 
        Context memory context,
        Asset memory asset
    ) internal returns(SD59x18 suppliedQuantity) {
        SD59x18 deviationNew = ((asset.quantity - utilisableQuantity) * asset.price 
                / (context.totalCurrentUsdAmount - utilisableQuantity * asset.price) - asset.percent / context.totalAssetPercents).abs();
        SD59x18 deviationOld = (asset.quantity * asset.price 
                / context.totalCurrentUsdAmount - asset.percent / context.totalAssetPercents).abs();

        if (deviationNew.abs() < deviationOld.abs()) {
            SD59x18 cashback = asset.collectedCashbacks * (deviationOld - deviationNew) / deviationOld;
            asset.collectedCashbacks = asset.collectedCashbacks - cashback;
            context.userCashbackBalance = context.userCashbackBalance + cashback;
            suppliedQuantity = utilisableQuantity + utilisableQuantity * context.operationBaseFee;
        } else {
            require(deviationNew.abs() < context.deviationPercentLimit, "deviation overflows limit");

            SD59x18 collectedDeviationFee = context.curveCoef * deviationNew * utilisableQuantity 
            / context.deviationPercentLimit / (context.deviationPercentLimit - deviationNew);
            asset.collectedCashbacks = asset.collectedCashbacks + collectedDeviationFee;
            suppliedQuantity = utilisableQuantity + 
                utilisableQuantity * context.operationBaseFee + collectedDeviationFee;
        }

        asset.quantity = asset.quantity - suppliedQuantity; 
        context.totalCurrentUsdAmount = context.totalCurrentUsdAmount - suppliedQuantity * asset.price;
        asset.collectedFees = asset.collectedFees + utilisableQuantity * context.operationBaseFee;
    }

    function evalMintContext(
        SD59x18 suppliedQuantity, 
        Context memory context,
        Asset memory asset
    ) internal returns(SD59x18 utilisableQuantity) {
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

        if (deviationNoFees < deviationOld) {
            utilisableQuantity = noFees;
            require (deviationNoFees <= deviationOld, "deviation no fees should be lower than old");
            SD59x18 cashback = asset.collectedCashbacks * (deviationOld - deviationNoFees) / deviationOld;
           // // deviation old may be zero if previous action made it so, then no cashback is left anyway
           // // anyway, due to price dynamics, we will just send all cashback to user 
           // if (deviationOld != 0) {
           //     SD59x18 cashback = asset.collectedCashbacks *  deviationOld - deviationNoFees / deviationOld;
           // } else {
           //     SD59x18 cashback = asset.collectedCashbacks;
           // }
            asset.collectedCashbacks = asset.collectedCashbacks - cashback;

            context.userCashbackBalance = context.userCashbackBalance + cashback;
        } else {
            require(deviationWithFees < context.deviationPercentLimit, 
                    "deviation can't be made bigger than limit with action");
            require(withFees != sd(0), "no curve solutions found");

            utilisableQuantity = withFees;
            // straightforward form but seems like it is not so good in accuracy,
            // base fee is easy to compute bc of one multiplication so to keep
            // deviation fee + base fee + utilisable val = supplied val
            // we use substraction here
            //asset.collectedCashbacks = asset.collectedCashbacks + 
            //    context.curveCoef * deviationWithFees * utilisableQuantity 
            /// context.deviationPercentLimit / (context.deviationPercentLimit - deviationWithFees);
            asset.collectedCashbacks = asset.collectedCashbacks + 
                (suppliedQuantity - utilisableQuantity * (sd(1e18) + context.operationBaseFee));
        }

        asset.quantity = asset.quantity + utilisableQuantity; 
        context.totalCurrentUsdAmount = context.totalCurrentUsdAmount + utilisableQuantity * asset.price;
        asset.collectedFees = asset.collectedFees + utilisableQuantity * context.operationBaseFee;
    }

    function evalBurnContext(
        SD59x18 suppliedQuantity, 
        Context memory context,
        Asset memory asset
    ) internal returns(SD59x18 utilisableQuantity) {
        SD59x18 withFees = getUtilisableBurnQuantity(suppliedQuantity, context, asset);
        SD59x18 noFees = suppliedQuantity / (sd(1e18) + context.operationBaseFee);

        SD59x18 deviationWithFees = ((asset.quantity - withFees) * asset.price 
                / (context.totalCurrentUsdAmount - withFees * asset.price) - asset.percent / context.totalAssetPercents).abs();
        SD59x18 deviationNoFees = ((asset.quantity - noFees) * asset.price 
                / (context.totalCurrentUsdAmount - noFees * asset.price) - asset.percent / context.totalAssetPercents).abs();
        SD59x18 deviationOld = (asset.quantity * asset.price 
                / context.totalCurrentUsdAmount - asset.percent / context.totalAssetPercents).abs();

        if (deviationNoFees < deviationOld) {
            utilisableQuantity = noFees;
            require (deviationNoFees <= deviationOld, "deviation no fees should be lower than old");
            SD59x18 cashback = asset.collectedCashbacks * (deviationOld - deviationNoFees) / deviationOld;
            asset.collectedCashbacks = asset.collectedCashbacks - cashback;

            context.userCashbackBalance = context.userCashbackBalance + cashback;
        } else {
            require(deviationWithFees < context.deviationPercentLimit, 
                    "deviation can't be made bigger than limit with action");
            require(withFees != sd(0), "no curve solutions found");
            utilisableQuantity = withFees;
            //asset.collectedCashbacks = asset.collectedCashbacks + 
            //    context.curveCoef * deviationWithFees * utilisableQuantity 
            /// context.deviationPercentLimit / (context.deviationPercentLimit - deviationWithFees);
            asset.collectedCashbacks = asset.collectedCashbacks + 
                (suppliedQuantity - utilisableQuantity * (sd(1e18) + context.operationBaseFee));
        }

        asset.quantity = asset.quantity - suppliedQuantity; 
        context.totalCurrentUsdAmount = context.totalCurrentUsdAmount - suppliedQuantity * asset.price;
        asset.collectedFees = asset.collectedFees + utilisableQuantity * context.operationBaseFee;
    }

    function getUtilisableMintQuantity(
        SD59x18 suppliedQuantity, 
        Context memory context,
        Asset memory asset
    ) internal returns(SD59x18 utilisableQuantity){
        
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


            if (d > sd(0)) {
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


            if (d > sd(0)) {
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

    function getUtilisableBurnQuantity(
        SD59x18 suppliedQuantity, 
        Context memory context,
        Asset memory asset
    ) internal returns(SD59x18 utilisableQuantity){

        SD59x18 B = (sd(1e18) + context.operationBaseFee);
        SD59x18 m = sd(1e18) - asset.percent / context.totalAssetPercents;
        SD59x18 C = context.curveCoef / context.deviationPercentLimit;

        {{
            SD59x18 a = (B * (context.deviationPercentLimit - m) + C * m) * asset.price;
            SD59x18 b = - (context.deviationPercentLimit - m) 
                * (context.totalCurrentUsdAmount * B + suppliedQuantity * asset.price) 
                + (B - C) * (asset.quantity * asset.price - context.totalCurrentUsdAmount)
                - C * m * context.totalCurrentUsdAmount;
            SD59x18 c = - (asset.quantity * asset.price - context.totalCurrentUsdAmount) * suppliedQuantity
                + (context.deviationPercentLimit - m) * context.totalCurrentUsdAmount * suppliedQuantity;

            SD59x18 d = b.powu(2) - sd(4e18) * a * c;

            SD59x18 cmp;
            {{
                cmp = (asset.quantity * asset.price 
                    + context.totalCurrentUsdAmount * (m - sd(1e18))) / (m * asset.price);
            }}

            if (d > sd(0)) {
                d = d.sqrt();
                SD59x18 x1 = (-b-d) / sd(2e18) / a;
                SD59x18 x2 = (-b+d) / sd(2e18) / a;

                SD59x18 _suppliedQuantity = suppliedQuantity;
                {
                    if (x1 < cmp && x1 > sd(0) && x1 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x1;
                    }
                    if (x2 < cmp && x2 > sd(0) && x2 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x2;
                    }
                }
            }
        }}

        {{
            SD59x18 a = (B * (context.deviationPercentLimit + m) - C * m) * asset.price;
            SD59x18 b = - (context.deviationPercentLimit + m) 
                * (context.totalCurrentUsdAmount * B + suppliedQuantity * asset.price) 
                - (B - C) * (asset.quantity * asset.price - context.totalCurrentUsdAmount)
                + C * m * context.totalCurrentUsdAmount;
            SD59x18 c = (asset.quantity * asset.price - context.totalCurrentUsdAmount) * suppliedQuantity
                + (context.deviationPercentLimit + m) * context.totalCurrentUsdAmount * suppliedQuantity;

            SD59x18 d = b.powu(2) - sd(4e18) * a * c;

            SD59x18 cmp;
            {{
                cmp = (asset.quantity * asset.price 
                    + context.totalCurrentUsdAmount * (m - sd(1e18))) / (m * asset.price);
            }}

            if (d > sd(0)) {
                d = d.sqrt();
                SD59x18 x3 = (-b-d) / (sd(2e18) * a);
                SD59x18 x4 = (-b+d) / (sd(2e18) * a);

                SD59x18 _suppliedQuantity = suppliedQuantity;
                {
                    if (x3 > cmp && x3 > sd(0) && x3 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x3;
                    }
                    if (x4 > cmp && x4 > sd(0) && x4 < _suppliedQuantity) {
                        utilisableQuantity = utilisableQuantity + x4;
                    }
                }
            }
        }}
    }
}
