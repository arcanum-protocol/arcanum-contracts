// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {SD59x18, sd} from "@prb/math/src/SD59x18.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
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
    UD60x18 depegBaseFeeRatio;
}

library MpMath {
    struct MpAssetSigned {
        SD59x18 quantity;
        SD59x18 price;
        SD59x18 collectedFees;
        SD59x18 collectedCashbacks;
        SD59x18 percent;
    }

    struct MpContextSigned {
        SD59x18 totalCurrentUsdAmount;
        SD59x18 totalAssetPercents;
        SD59x18 curveCoef;
        SD59x18 deviationPercentLimit;
        SD59x18 operationBaseFee;
        SD59x18 userCashbackBalance;
        SD59x18 depegBaseFeeRatio;
    }

    function sign(
        MpContext memory c
    ) internal pure returns (MpContextSigned memory) {
        return
            MpContextSigned({
                totalCurrentUsdAmount: sign(c.totalCurrentUsdAmount),
                totalAssetPercents: sign(c.totalAssetPercents),
                curveCoef: sign(c.curveCoef),
                deviationPercentLimit: sign(c.deviationPercentLimit),
                operationBaseFee: sign(c.operationBaseFee),
                userCashbackBalance: sign(c.userCashbackBalance),
                depegBaseFeeRatio: sign(c.depegBaseFeeRatio)
            });
    }

    function sign(
        MpAsset memory asset
    ) internal pure returns (MpAssetSigned memory) {
        return
            MpAssetSigned({
                quantity: sign(asset.quantity),
                price: sign(asset.price),
                collectedFees: sign(asset.collectedFees),
                collectedCashbacks: sign(asset.collectedCashbacks),
                percent: sign(asset.percent)
            });
    }

    function sign(UD60x18 a) internal pure returns (SD59x18 b) {
        b = sd(int(a.unwrap()));
    }

    function unsign(SD59x18 a) internal pure returns (UD60x18 b) {
        b = ud(uint(a.unwrap()));
    }

    function calculateDeviationMint(
        MpContext memory context,
        MpAsset memory asset,
        UD60x18 utilisableQuantity
    ) internal pure returns (UD60x18 deviation) {
        SD59x18 share = sign(
            ((asset.quantity + utilisableQuantity) * asset.price) /
                (context.totalCurrentUsdAmount +
                    utilisableQuantity *
                    asset.price)
        );
        SD59x18 idealShare = sign(asset.percent / context.totalAssetPercents);
        deviation = unsign((share - idealShare).abs());
    }

    function calculateDeviationBurn(
        MpContext memory context,
        MpAsset memory asset,
        UD60x18 suppliedQuantity
    ) internal pure returns (UD60x18 deviation) {
        SD59x18 share = sign(
            ((asset.quantity - suppliedQuantity) * asset.price) /
                (context.totalCurrentUsdAmount - suppliedQuantity * asset.price)
        );
        SD59x18 idealShare = sign(asset.percent / context.totalAssetPercents);
        deviation = unsign((share - idealShare).abs());
    }

    function mintRev(
        MpContext memory context,
        MpAsset memory asset,
        UD60x18 utilisableQuantity
    ) internal pure returns (UD60x18 suppliedQuantity) {
        if (context.totalCurrentUsdAmount == ud(0)) {
            context.totalCurrentUsdAmount = utilisableQuantity * asset.price;
            asset.quantity = asset.quantity + utilisableQuantity;
            return utilisableQuantity;
        }
        UD60x18 deviationNew = calculateDeviationMint(
            context,
            asset,
            utilisableQuantity
        );
        UD60x18 deviationOld = calculateDeviationMint(context, asset, ud(0));

        if (deviationNew <= deviationOld) {
            UD60x18 cashback;
            if (deviationOld != ud(0)) {
                cashback =
                    (asset.collectedCashbacks * (deviationOld - deviationNew)) /
                    deviationOld;
            }
            asset.collectedCashbacks = asset.collectedCashbacks - cashback;
            context.userCashbackBalance =
                context.userCashbackBalance +
                cashback;
            suppliedQuantity =
                utilisableQuantity +
                utilisableQuantity *
                context.operationBaseFee;
        } else {
            require(
                deviationNew < context.deviationPercentLimit,
                "deviation overflows limit"
            );

            UD60x18 collectedDeviationFee = (context.curveCoef *
                deviationNew *
                utilisableQuantity) /
                context.deviationPercentLimit /
                (context.deviationPercentLimit - deviationNew);
            UD60x18 collectedBaseDepegFee = collectedDeviationFee *
                context.depegBaseFeeRatio;
            asset.collectedCashbacks =
                asset.collectedCashbacks +
                collectedDeviationFee -
                collectedBaseDepegFee;
            asset.collectedFees = asset.collectedFees + collectedBaseDepegFee;
            suppliedQuantity =
                utilisableQuantity +
                utilisableQuantity *
                context.operationBaseFee +
                collectedDeviationFee;
        }

        asset.quantity = asset.quantity + utilisableQuantity;
        context.totalCurrentUsdAmount =
            context.totalCurrentUsdAmount +
            utilisableQuantity *
            asset.price;
        asset.collectedFees =
            asset.collectedFees +
            utilisableQuantity *
            context.operationBaseFee;
    }

    function burnRev(
        MpContext memory context,
        MpAsset memory asset,
        UD60x18 utilisableQuantity
    ) internal pure returns (UD60x18 suppliedQuantity) {
        require(
            utilisableQuantity <= asset.quantity,
            "can't burn more assets than exist"
        );

        UD60x18 withFees = unsign(
            getSuppliableBurnQuantity(
                sign(utilisableQuantity),
                sign(context),
                sign(asset)
            )
        );
        UD60x18 noFees = utilisableQuantity *
            (ud(1e18) + context.operationBaseFee);

        UD60x18 deviationWithFees = calculateDeviationBurn(
            context,
            asset,
            withFees
        );
        UD60x18 deviationNoFees = calculateDeviationBurn(
            context,
            asset,
            noFees
        );
        UD60x18 deviationOld = calculateDeviationBurn(context, asset, ud(0));

        if (deviationNoFees <= deviationOld) {
            suppliedQuantity = noFees;
            require(
                suppliedQuantity <= asset.quantity,
                "can't burn more assets than exist"
            );

            UD60x18 cashback;
            if (deviationOld != ud(0)) {
                cashback =
                    (asset.collectedCashbacks *
                        (deviationOld - deviationNoFees)) /
                    deviationOld;
            }

            asset.collectedCashbacks = asset.collectedCashbacks - cashback;
            context.userCashbackBalance =
                context.userCashbackBalance +
                cashback;
        } else {
            suppliedQuantity = withFees;
            require(
                suppliedQuantity <= asset.quantity,
                "can't burn more assets than exist"
            );
            require(
                deviationWithFees < context.deviationPercentLimit,
                "deviation overflows limit"
            );
            require(withFees != ud(0), "no curve solutions found");

            UD60x18 _operationBaseFee = context.operationBaseFee;
            UD60x18 collectedCashbacks = (suppliedQuantity -
                utilisableQuantity *
                (ud(1e18) + _operationBaseFee));
            UD60x18 collectedBaseDepegFee = collectedCashbacks *
                context.depegBaseFeeRatio;
            asset.collectedCashbacks =
                asset.collectedCashbacks +
                collectedCashbacks -
                collectedBaseDepegFee;
            asset.collectedFees = asset.collectedFees + collectedBaseDepegFee;
        }

        asset.quantity = asset.quantity - suppliedQuantity;
        context.totalCurrentUsdAmount =
            context.totalCurrentUsdAmount -
            suppliedQuantity *
            asset.price;
        asset.collectedFees =
            asset.collectedFees +
            utilisableQuantity *
            context.operationBaseFee;
    }

    function mint(
        MpContext memory context,
        MpAsset memory asset,
        UD60x18 suppliedQuantity
    ) internal pure returns (UD60x18 utilisableQuantity) {
        if (context.totalCurrentUsdAmount == ud(0)) {
            context.totalCurrentUsdAmount = suppliedQuantity * asset.price;
            asset.quantity = asset.quantity + suppliedQuantity;
            return suppliedQuantity;
        }
        UD60x18 withFees = unsign(
            getUtilisableMintQuantity(
                sign(suppliedQuantity),
                sign(context),
                sign(asset)
            )
        );
        UD60x18 noFees = suppliedQuantity /
            (ud(1e18) + context.operationBaseFee);

        UD60x18 deviationWithFees = calculateDeviationMint(
            context,
            asset,
            withFees
        );
        UD60x18 deviationNoFees = calculateDeviationMint(
            context,
            asset,
            noFees
        );
        UD60x18 deviationOld = calculateDeviationMint(context, asset, ud(0));

        if (deviationNoFees <= deviationOld) {
            utilisableQuantity = noFees;
            require(
                deviationNoFees <= deviationOld,
                "deviation no fees should be lower than old"
            );

            UD60x18 cashback;
            if (deviationOld != ud(0)) {
                cashback =
                    (asset.collectedCashbacks *
                        (deviationOld - deviationNoFees)) /
                    deviationOld;
            }

            asset.collectedCashbacks = asset.collectedCashbacks - cashback;

            context.userCashbackBalance =
                context.userCashbackBalance +
                cashback;
        } else {
            require(
                deviationWithFees < context.deviationPercentLimit,
                "deviation overflows limit"
            );
            require(withFees != ud(0), "no curve solutions found");

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
            UD60x18 _operationBaseFee = context.operationBaseFee;
            UD60x18 collectedCashbacks = (suppliedQuantity -
                utilisableQuantity *
                (ud(1e18) + _operationBaseFee));
            UD60x18 collectedBaseDepegFee = collectedCashbacks *
                context.depegBaseFeeRatio;
            asset.collectedCashbacks =
                asset.collectedCashbacks +
                collectedCashbacks -
                collectedBaseDepegFee;
            asset.collectedFees = asset.collectedFees + collectedBaseDepegFee;
        }

        asset.quantity = asset.quantity + utilisableQuantity;
        context.totalCurrentUsdAmount =
            context.totalCurrentUsdAmount +
            utilisableQuantity *
            asset.price;
        asset.collectedFees =
            asset.collectedFees +
            utilisableQuantity *
            context.operationBaseFee;
    }

    function burn(
        MpContext memory context,
        MpAsset memory asset,
        UD60x18 suppliedQuantity
    ) internal pure returns (UD60x18 utilisableQuantity) {
        require(
            suppliedQuantity <= asset.quantity,
            "can't burn more assets than exist"
        );

        if (context.totalCurrentUsdAmount > suppliedQuantity * asset.price) {
            UD60x18 deviationNew = calculateDeviationBurn(
                context,
                asset,
                suppliedQuantity
            );
            UD60x18 deviationOld = calculateDeviationBurn(
                context,
                asset,
                ud(0)
            );

            if (deviationNew <= deviationOld) {
                UD60x18 cashback;
                if (deviationOld != ud(0)) {
                    cashback =
                        (asset.collectedCashbacks *
                            (deviationOld - deviationNew)) /
                        deviationOld;
                }
                asset.collectedCashbacks = asset.collectedCashbacks - cashback;
                context.userCashbackBalance =
                    context.userCashbackBalance +
                    cashback;
                utilisableQuantity =
                    suppliedQuantity /
                    (ud(1e18) + context.operationBaseFee);
            } else {
                require(
                    deviationNew < context.deviationPercentLimit,
                    "deviation overflows limit"
                );

                UD60x18 feeRatio = (context.curveCoef * deviationNew) /
                    context.deviationPercentLimit /
                    (context.deviationPercentLimit - deviationNew);

                utilisableQuantity =
                    suppliedQuantity /
                    (ud(1e18) + feeRatio + context.operationBaseFee);

                UD60x18 collectedCashbacks = (suppliedQuantity -
                    utilisableQuantity *
                    (ud(1e18) + context.operationBaseFee));
                UD60x18 collectedBaseDepegFee = collectedCashbacks *
                    context.depegBaseFeeRatio;
                asset.collectedCashbacks =
                    asset.collectedCashbacks +
                    collectedCashbacks -
                    collectedBaseDepegFee;
                asset.collectedFees =
                    asset.collectedFees +
                    collectedBaseDepegFee;
            }
        } else {
            utilisableQuantity =
                suppliedQuantity /
                (ud(1e18) + context.operationBaseFee);
        }

        asset.quantity = asset.quantity - suppliedQuantity;
        context.totalCurrentUsdAmount =
            context.totalCurrentUsdAmount -
            suppliedQuantity *
            asset.price;
        asset.collectedFees =
            asset.collectedFees +
            utilisableQuantity *
            context.operationBaseFee;
    }

    function getUtilisableMintQuantity(
        SD59x18 suppliedQuantity,
        MpContextSigned memory context,
        MpAssetSigned memory asset
    ) internal pure returns (SD59x18 utilisableQuantity) {
        SD59x18 B = (sd(1e18) + context.operationBaseFee);
        SD59x18 m = sd(1e18) - asset.percent / context.totalAssetPercents;
        SD59x18 C = context.curveCoef / context.deviationPercentLimit;

        {
            {
                SD59x18 a = (B * (context.deviationPercentLimit - m) + C * m) *
                    asset.price;
                SD59x18 b = (context.deviationPercentLimit - m) *
                    (context.totalCurrentUsdAmount *
                        B -
                        suppliedQuantity *
                        asset.price) -
                    (B - C) *
                    (asset.quantity *
                        asset.price -
                        context.totalCurrentUsdAmount) +
                    C *
                    m *
                    context.totalCurrentUsdAmount;
                SD59x18 c = (asset.quantity *
                    asset.price -
                    context.totalCurrentUsdAmount) *
                    suppliedQuantity -
                    (context.deviationPercentLimit - m) *
                    context.totalCurrentUsdAmount *
                    suppliedQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 cmp;
                {
                    {
                        cmp =
                            -(asset.quantity *
                                asset.price +
                                context.totalCurrentUsdAmount *
                                (m - sd(1e18))) /
                            (m * asset.price);
                    }
                }

                if (d >= sd(0)) {
                    d = d.sqrt();
                    SD59x18 x1 = (-b - d) / sd(2e18) / a;
                    SD59x18 x2 = (-b + d) / sd(2e18) / a;

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
            }
        }

        {
            {
                SD59x18 a = (B * (context.deviationPercentLimit + m) - C * m) *
                    asset.price;
                SD59x18 b = (context.deviationPercentLimit + m) *
                    (context.totalCurrentUsdAmount *
                        B -
                        suppliedQuantity *
                        asset.price) +
                    (B - C) *
                    (asset.quantity *
                        asset.price -
                        context.totalCurrentUsdAmount) -
                    C *
                    m *
                    context.totalCurrentUsdAmount;
                SD59x18 c = -(asset.quantity *
                    asset.price -
                    context.totalCurrentUsdAmount) *
                    suppliedQuantity -
                    (context.deviationPercentLimit + m) *
                    context.totalCurrentUsdAmount *
                    suppliedQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 cmp;
                {
                    {
                        cmp =
                            -(asset.quantity *
                                asset.price +
                                context.totalCurrentUsdAmount *
                                (m - sd(1e18))) /
                            (m * asset.price);
                    }
                }

                if (d >= sd(0)) {
                    d = d.sqrt();
                    SD59x18 x3 = (-b - d) / sd(2e18) / a;
                    SD59x18 x4 = (-b + d) / sd(2e18) / a;

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
            }
        }
    }

    function getSuppliableBurnQuantity(
        SD59x18 utilisableQuantity,
        MpContextSigned memory context,
        MpAssetSigned memory asset
    ) internal pure returns (SD59x18 suppliedQuantity) {
        SD59x18 B = (sd(1e18) + context.operationBaseFee);
        SD59x18 m = sd(1e18) - asset.percent / context.totalAssetPercents;
        SD59x18 C = context.curveCoef / context.deviationPercentLimit;

        {
            {
                SD59x18 a = -(context.deviationPercentLimit - m) * asset.price;
                SD59x18 b = ((B * asset.price * utilisableQuantity) +
                    context.totalCurrentUsdAmount) *
                    (context.deviationPercentLimit - m) +
                    C *
                    m *
                    asset.price *
                    utilisableQuantity -
                    (asset.quantity *
                        asset.price -
                        context.totalCurrentUsdAmount);
                SD59x18 c = -B *
                    context.totalCurrentUsdAmount *
                    utilisableQuantity *
                    (context.deviationPercentLimit - m) +
                    (asset.quantity *
                        asset.price -
                        context.totalCurrentUsdAmount) *
                    utilisableQuantity *
                    (B - C) -
                    C *
                    m *
                    context.totalCurrentUsdAmount *
                    utilisableQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 q = (asset.quantity *
                    asset.price -
                    context.totalCurrentUsdAmount);
                SD59x18 t = context.totalCurrentUsdAmount;
                SD59x18 p = asset.price;
                SD59x18 dl = context.deviationPercentLimit;
                SD59x18 cmp = (q + m * t) / (m * p);

                if (d >= sd(0)) {
                    d = d.sqrt();
                    SD59x18 x1 = (-b - d) / sd(2e18) / a;
                    SD59x18 x2 = (-b + d) / sd(2e18) / a;

                    {
                        {
                            if (t - x1 * p != sd(0)) {
                                if (
                                    (m + q / (t - x1 * p)).abs() < dl &&
                                    x1 < cmp
                                ) {
                                    suppliedQuantity = suppliedQuantity > x1 ||
                                        suppliedQuantity == sd(0)
                                        ? x1
                                        : suppliedQuantity;
                                }
                            }
                        }
                    }
                    {
                        {
                            if (t - x2 * p != sd(0)) {
                                if (
                                    (m + q / (t - x2 * p)).abs() < dl &&
                                    x2 < cmp
                                ) {
                                    suppliedQuantity = suppliedQuantity > x2 ||
                                        suppliedQuantity == sd(0)
                                        ? x2
                                        : suppliedQuantity;
                                }
                            }
                        }
                    }
                }
            }
        }

        {
            {
                SD59x18 a = (context.deviationPercentLimit + m) * asset.price;
                SD59x18 b = -((B * asset.price * utilisableQuantity) +
                    context.totalCurrentUsdAmount) *
                    (context.deviationPercentLimit + m) +
                    C *
                    m *
                    asset.price *
                    utilisableQuantity -
                    (asset.quantity *
                        asset.price -
                        context.totalCurrentUsdAmount);
                SD59x18 c = B *
                    context.totalCurrentUsdAmount *
                    utilisableQuantity *
                    (context.deviationPercentLimit + m) +
                    (asset.quantity *
                        asset.price -
                        context.totalCurrentUsdAmount) *
                    utilisableQuantity *
                    (B - C) -
                    C *
                    m *
                    context.totalCurrentUsdAmount *
                    utilisableQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 q = (asset.quantity *
                    asset.price -
                    context.totalCurrentUsdAmount);
                SD59x18 t = context.totalCurrentUsdAmount;
                SD59x18 p = asset.price;
                SD59x18 dl = context.deviationPercentLimit;
                SD59x18 cmp = (q + m * t) / (m * p);

                if (d >= sd(0)) {
                    d = d.sqrt();
                    SD59x18 x3 = (-b - d) / sd(2e18) / a;
                    SD59x18 x4 = (-b + d) / sd(2e18) / a;

                    {
                        {
                            if (t - x3 * p != sd(0)) {
                                if (
                                    (m + q / (t - x3 * p)).abs() < dl &&
                                    x3 > cmp
                                ) {
                                    suppliedQuantity = suppliedQuantity > x3 ||
                                        suppliedQuantity == sd(0)
                                        ? x3
                                        : suppliedQuantity;
                                }
                            }
                        }
                    }
                    {
                        {
                            if (t - x4 * p != sd(0)) {
                                if (
                                    (m + q / (t - x4 * p)).abs() < dl &&
                                    x4 > cmp
                                ) {
                                    suppliedQuantity = suppliedQuantity > x4 ||
                                        suppliedQuantity == sd(0)
                                        ? x4
                                        : suppliedQuantity;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

using {
    MpMath.mintRev,
    MpMath.burnRev,
    MpMath.mint,
    MpMath.burn
} for MpContext global;
