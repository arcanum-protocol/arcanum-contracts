// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {SD59x18, sd} from "prb-math/SD59x18.sol";
import {MpAsset, MpContext} from "./Multipool.sol";

uint constant DENOMINATOR = 1e18;

library MpComplexMath {
    struct MpAssetSigned {
        SD59x18 quantity;
        SD59x18 price;
        SD59x18 collectedFees;
        SD59x18 collectedCashbacks;
        SD59x18 share;
    }

    struct MpContextSigned {
        SD59x18 usdCap;
        SD59x18 totalTargetShares;
        SD59x18 halfDeviationFee;
        SD59x18 deviationLimit;
        SD59x18 operationBaseFee;
        SD59x18 userCashbackBalance;
        SD59x18 depegBaseFee;
    }

    function sign(
        MpContext memory c
    ) internal pure returns (MpContextSigned memory) {
        return
            MpContextSigned({
                usdCap: sign(c.usdCap),
                totalTargetShares: sign(c.totalTargetShares),
                halfDeviationFee: sign(c.halfDeviationFee),
                deviationLimit: sign(c.deviationLimit),
                operationBaseFee: sign(c.operationBaseFee),
                userCashbackBalance: sign(c.userCashbackBalance),
                depegBaseFee: sign(c.depegBaseFee)
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
                share: sign(asset.share)
            });
    }

    function sign(uint a) internal pure returns (SD59x18 b) {
        b = sd(int(a));
    }

    function unsign(SD59x18 a) internal pure returns (uint b) {
        b = uint(a.unwrap());
    }

    function mintRev(
        MpContext memory context,
        MpAsset memory asset,
        uint utilisableQuantity
    ) internal pure returns (uint suppliedQuantity) {
        suppliedQuantity = context.evalMint(asset, utilisableQuantity);
    }

    function burn(
        MpContext memory context,
        MpAsset memory asset,
        uint suppliedQuantity
    ) internal pure returns (uint utilisableQuantity) {
        utilisableQuantity = context.evalBurn(asset, suppliedQuantity);
    }

    function calculateDeviationMint(
        MpContext memory context,
        MpAsset memory asset,
        uint utilisableQuantity
    ) internal pure returns (uint deviation) {
        SD59x18 share = sign(
            ((asset.quantity + utilisableQuantity) * asset.price) /
                (context.usdCap +
                    utilisableQuantity *
                    asset.price / DENOMINATOR)
        );
        SD59x18 targetShare = sign(asset.share * DENOMINATOR / context.totalTargetShares);
        deviation = unsign((share - targetShare).abs());
    }

    function calculateDeviationBurn(
        MpContext memory context,
        MpAsset memory asset,
        uint suppliedQuantity
    ) internal pure returns (uint deviation) {
        SD59x18 share = sign(
            ((asset.quantity - suppliedQuantity) * asset.price) /
                (context.usdCap - suppliedQuantity * asset.price / DENOMINATOR)
        );
        SD59x18 targetShare = sign(asset.share * DENOMINATOR / context.totalTargetShares);
        deviation = unsign((share - targetShare).abs());
    }


    function burnRev(
        MpContext memory context,
        MpAsset memory asset,
        uint utilisableQuantity
    ) internal pure returns (uint suppliedQuantity) {
        require(
            utilisableQuantity <= asset.quantity,
            "can't burn more assets than exist"
        );

        uint withFees = unsign(
            getSuppliableBurnQuantity(
                sign(utilisableQuantity),
                sign(context),
                sign(asset)
            )
        );
        uint noFees = utilisableQuantity *
            (1e18 + context.operationBaseFee) / DENOMINATOR;

        uint deviationWithFees = calculateDeviationBurn(
            context,
            asset,
            withFees
        );
        uint deviationNoFees = calculateDeviationBurn(
            context,
            asset,
            noFees
        );
        uint deviationOld = calculateDeviationBurn(context, asset, 0);

        if (deviationNoFees <= deviationOld) {
            suppliedQuantity = noFees;
            require(
                suppliedQuantity <= asset.quantity,
                "can't burn more assets than exist"
            );

            uint cashback;
            if (deviationOld != 0) {
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
                deviationWithFees < context.deviationLimit,
                "deviation overflows limit"
            );
            require(withFees != 0, "no curve solutions found");

            uint _operationBaseFee = context.operationBaseFee;
            uint collectedCashbacks = suppliedQuantity -
                utilisableQuantity *
                (1e18 + _operationBaseFee) / DENOMINATOR;
            uint collectedBaseDepegFee = (collectedCashbacks *
                context.depegBaseFee) / DENOMINATOR;
            asset.collectedCashbacks =
                asset.collectedCashbacks +
                collectedCashbacks -
                collectedBaseDepegFee;
            asset.collectedFees = asset.collectedFees + collectedBaseDepegFee;
        }

        asset.quantity = asset.quantity - suppliedQuantity;
        context.usdCap =
            context.usdCap -
            suppliedQuantity *
            asset.price / DENOMINATOR;
        asset.collectedFees =
            asset.collectedFees +
            utilisableQuantity *
            context.operationBaseFee / DENOMINATOR;
    }

    function mint(
        MpContext memory context,
        MpAsset memory asset,
        uint suppliedQuantity
    ) internal pure returns (uint utilisableQuantity) {
        if (context.usdCap == 0) {
            context.usdCap = suppliedQuantity * asset.price / DENOMINATOR;
            asset.quantity = asset.quantity + suppliedQuantity;
            return suppliedQuantity;
        }
        uint withFees = unsign(
            getUtilisableMintQuantity(
                sign(suppliedQuantity),
                sign(context),
                sign(asset)
            )
        );
        uint noFees = suppliedQuantity * DENOMINATOR /
            (1e18 + context.operationBaseFee);

        uint deviationWithFees = calculateDeviationMint(
            context,
            asset,
            withFees
        );
        uint deviationNoFees = calculateDeviationMint(
            context,
            asset,
            noFees
        );
        uint deviationOld = calculateDeviationMint(context, asset, 0);

        if (deviationNoFees <= deviationOld) {
            utilisableQuantity = noFees;
            require(
                deviationNoFees <= deviationOld,
                "deviation no fees should be lower than old"
            );

            uint cashback;
            if (deviationOld != 0) {
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
                deviationWithFees < context.deviationLimit,
                "deviation overflows limit"
            );
            require(withFees != 0, "no curve solutions found");

            utilisableQuantity = withFees;
            // straightforward form but seems like it is not so good in accuracy,
            // base fee is easy to compute bc of one multiplication so to keep
            // deviation fee + base fee + utilisable val = supplied val
            // we use substraction here
            uint _operationBaseFee = context.operationBaseFee;
            uint collectedCashbacks = suppliedQuantity -
                utilisableQuantity *
                (1e18 + _operationBaseFee) / DENOMINATOR;
            uint collectedBaseDepegFee = collectedCashbacks *
                context.depegBaseFee / DENOMINATOR;
            asset.collectedCashbacks =
                asset.collectedCashbacks +
                collectedCashbacks -
                collectedBaseDepegFee;
            asset.collectedFees = asset.collectedFees + collectedBaseDepegFee;
        }

        asset.quantity = asset.quantity + utilisableQuantity;
        context.usdCap =
            context.usdCap +
            utilisableQuantity *
            asset.price / DENOMINATOR;
        asset.collectedFees =
            asset.collectedFees +
            utilisableQuantity *
            context.operationBaseFee / DENOMINATOR;
    }

    function getUtilisableMintQuantity(
        SD59x18 suppliedQuantity,
        MpContextSigned memory context,
        MpAssetSigned memory asset
    ) internal pure returns (SD59x18 utilisableQuantity) {
        SD59x18 B = (sd(1e18) + context.operationBaseFee);
        SD59x18 m = sd(1e18) - asset.share / context.totalTargetShares;
        SD59x18 C = context.halfDeviationFee / context.deviationLimit;

        {
            {
                SD59x18 a = (B * (context.deviationLimit - m) + C * m) *
                    asset.price;
                SD59x18 b = (context.deviationLimit - m) *
                    (context.usdCap *
                        B -
                        suppliedQuantity *
                        asset.price) -
                    (B - C) *
                    (asset.quantity *
                        asset.price -
                        context.usdCap) +
                    C *
                    m *
                    context.usdCap;
                SD59x18 c = (asset.quantity *
                    asset.price -
                    context.usdCap) *
                    suppliedQuantity -
                    (context.deviationLimit - m) *
                    context.usdCap *
                    suppliedQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 cmp;
                {
                    {
                        cmp =
                            -(asset.quantity *
                                asset.price +
                                context.usdCap *
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
                SD59x18 a = (B * (context.deviationLimit + m) - C * m) *
                    asset.price;
                SD59x18 b = (context.deviationLimit + m) *
                    (context.usdCap *
                        B -
                        suppliedQuantity *
                        asset.price) +
                    (B - C) *
                    (asset.quantity *
                        asset.price -
                        context.usdCap) -
                    C *
                    m *
                    context.usdCap;
                SD59x18 c = -(asset.quantity *
                    asset.price -
                    context.usdCap) *
                    suppliedQuantity -
                    (context.deviationLimit + m) *
                    context.usdCap *
                    suppliedQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 cmp;
                {
                    {
                        cmp =
                            -(asset.quantity *
                                asset.price +
                                context.usdCap *
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
        SD59x18 m = sd(1e18) - asset.share / context.totalTargetShares;
        SD59x18 C = context.halfDeviationFee / context.deviationLimit;

        {
            {
                SD59x18 a = -(context.deviationLimit - m) * asset.price;
                SD59x18 b = ((B * asset.price * utilisableQuantity) +
                    context.usdCap) *
                    (context.deviationLimit - m) +
                    C *
                    m *
                    asset.price *
                    utilisableQuantity -
                    (asset.quantity *
                        asset.price -
                        context.usdCap);
                SD59x18 c = -B *
                    context.usdCap *
                    utilisableQuantity *
                    (context.deviationLimit - m) +
                    (asset.quantity *
                        asset.price -
                        context.usdCap) *
                    utilisableQuantity *
                    (B - C) -
                    C *
                    m *
                    context.usdCap *
                    utilisableQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 q = (asset.quantity *
                    asset.price -
                    context.usdCap);
                SD59x18 t = context.usdCap;
                SD59x18 p = asset.price;
                SD59x18 dl = context.deviationLimit;
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
                SD59x18 a = (context.deviationLimit + m) * asset.price;
                SD59x18 b = -((B * asset.price * utilisableQuantity) +
                    context.usdCap) *
                    (context.deviationLimit + m) +
                    C *
                    m *
                    asset.price *
                    utilisableQuantity -
                    (asset.quantity *
                        asset.price -
                        context.usdCap);
                SD59x18 c = B *
                    context.usdCap *
                    utilisableQuantity *
                    (context.deviationLimit + m) +
                    (asset.quantity *
                        asset.price -
                        context.usdCap) *
                    utilisableQuantity *
                    (B - C) -
                    C *
                    m *
                    context.usdCap *
                    utilisableQuantity;

                SD59x18 d = b.powu(2) - sd(4e18) * a * c;

                SD59x18 q = (asset.quantity *
                    asset.price -
                    context.usdCap);
                SD59x18 t = context.usdCap;
                SD59x18 p = asset.price;
                SD59x18 dl = context.deviationLimit;
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

