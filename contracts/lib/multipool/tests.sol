// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "hardhat/console.sol";

import "./MultipoolMath.sol";

contract TestMultipoolMath {

    using MultipoolMath for *;

    function assertContext(MultipoolMath.Context memory a, MultipoolMath.Context memory b) public {
        require(a.totalCurrentUsdAmount == b.totalCurrentUsdAmount, "totalCurrentUsdAmount not equal");
        require(a.totalAssetPercents == b.totalAssetPercents, "totalAssetPercents not equal");
        require(a.curveCoef == b.curveCoef, "curveCoef not equal");
        require(a.deviationPercentLimit == b.deviationPercentLimit, "deviationPercentLimit not equal");
        require(a.operationBaseFee == b.operationBaseFee, "operationBaseFee not equal");
        require(a.userCashbackBalance == b.userCashbackBalance, "userCashbackBalance not equal");
    }

    function assertAsset(MultipoolMath.Asset memory a, MultipoolMath.Asset memory b) public {
        require(a.quantity == b.quantity, "quantity not equal");
        require(a.price == b.price, "price not equal");
        require(a.collectedFees == b.collectedFees, "collectedFees not equal");
        require(a.collectedCashbacks == b.collectedCashbacks, "collectedCashbacks not equal");
        require(a.percent == b.percent, "percent not equal");
    }

    function mintWithZeroBalance() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(0e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(0e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(10000000e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalMintContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(100000000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
            quantity:           sd(10000000e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(10000000e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithDeviationFee() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0051875e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalMintContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
            quantity:           sd(55e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(0.0051875e18 - 0.0005e18),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithDeviationFeeReversed() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalMintContext(utilisableQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
            quantity:           sd(55e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(5005187499999999906 - 5.0005e18),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5005187499999999906);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);

    }

    function burnWithDeviationFeeReversed() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalBurnContext(utilisableQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18) - sd(5005857142857142678) * sd(10e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
            quantity:           sd(50e18) - sd(5005857142857142678),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(5005857142857142678 - 5.0005e18),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5005857142857142678);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);

    }

    function burnWithDeviationFee() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        //TODO: 180 wei difference between burn and reversed burn. This might take place bacuse 
        // of square root calculation or any other heavy ops. Find out few tests to show this
        // diff won't grow with other numbers a lot
        SD59x18 suppliedQuantity = sd(5005857142857142678+180);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18) - sd(5005857142857142678+180) * sd(10e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
            quantity:           sd(50e18) - sd(5005857142857142678+180),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(5005857142857142678+180 - 5.0005e18),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }
}
