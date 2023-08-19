// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import "hardhat/console.sol";

import {MpAsset, MpContext} from "./MultipoolMath.sol";
import "./MultipoolMath.sol";

//TODO: add test to burn till zero

contract TestMultipoolMath {

}

contract TestMultipoolMathCorner {
    function assertContext(MpContext memory a, MpContext memory b) public {
        require(
            a.totalCurrentUsdAmount == b.totalCurrentUsdAmount,
            "totalCurrentUsdAmount not equal"
        );
        require(
            a.totalAssetPercents == b.totalAssetPercents,
            "totalAssetPercents not equal"
        );
        require(a.curveCoef == b.curveCoef, "curveCoef not equal");
        require(
            a.deviationPercentLimit == b.deviationPercentLimit,
            "deviationPercentLimit not equal"
        );
        require(
            a.operationBaseFee == b.operationBaseFee,
            "operationBaseFee not equal"
        );
        require(
            a.userCashbackBalance == b.userCashbackBalance,
            "userCashbackBalance not equal"
        );
        require(
            a.depegBaseFeeRatio == b.depegBaseFeeRatio,
            "depegBaseFeeRatio not equal"
        );
    }

    function assertAsset(MpAsset memory a, MpAsset memory b) public {
        require(a.quantity == b.quantity, "quantity not equal");
        require(a.price == b.price, "price not equal");
        require(a.collectedFees == b.collectedFees, "collectedFees not equal");
        require(
            a.collectedCashbacks == b.collectedCashbacks,
            "collectedCashbacks not equal"
        );
        require(a.percent == b.percent, "percent not equal");
    }


}
