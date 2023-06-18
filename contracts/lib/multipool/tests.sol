// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import "hardhat/console.sol";

import {MpAsset, MpContext} from "./MultipoolMath.sol";
import "./MultipoolMath.sol";

contract TestMultipoolMath {

    function assertContext(MpContext memory a, MpContext memory b) public {
        require(a.totalCurrentUsdAmount == b.totalCurrentUsdAmount, "totalCurrentUsdAmount not equal");
        require(a.totalAssetPercents == b.totalAssetPercents, "totalAssetPercents not equal");
        require(a.curveCoef == b.curveCoef, "curveCoef not equal");
        require(a.deviationPercentLimit == b.deviationPercentLimit, "deviationPercentLimit not equal");
        require(a.operationBaseFee == b.operationBaseFee, "operationBaseFee not equal");
        require(a.userCashbackBalance == b.userCashbackBalance, "userCashbackBalance not equal");
    }

    function assertAsset(MpAsset memory a, MpAsset memory b) public {
        require(a.quantity == b.quantity, "quantity not equal");
        require(a.price == b.price, "price not equal");
        require(a.collectedFees == b.collectedFees, "collectedFees not equal");
        require(a.collectedCashbacks == b.collectedCashbacks, "collectedCashbacks not equal");
        require(a.percent == b.percent, "percent not equal");
    }

    //TODO: reversed mint with zero balance
    function mintWithZeroBalanceReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(0e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(0e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(10000000e18);

        SD59x18 suppliedQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(100000000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(10000000e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(10000000e18);

        require(resultUtilisableQuantity == suppliedQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithZeroBalance() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(0e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(0e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(10000000e18);

        SD59x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(100000000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
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
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0051875e18);

        SD59x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
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
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
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
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1000e18) - sd(5005866126138531618) * sd(10e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50e18) - sd(5005866126138531618),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(5005866126138531618 - 5.0005e18),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5005866126138531618);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);

    }

    function burnWithDeviationFee() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        //TODO: 397 wei difference between burn and reversed burn. This might take place bacuse 
        // of square root calculation or any other heavy ops. Find out few tests to show this
        // diff won't grow with other numbers a lot
        SD59x18 suppliedQuantity = sd(5005866126138531618 - 397);

        SD59x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1000e18) - sd(5005866126138531618 - 397) * sd(10e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50e18) - sd(5005866126138531618 - 397),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(5005866126138531618 - 397 - 5.0005e18),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithNoDeviationFee() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(46e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(51e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(0),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithNoDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(46e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(51e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(0),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5.0005e18);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function burnWithNoDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50.9995e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(0),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5.0005e18);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);

    }

    function burnWithNoDeviationFee() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50.9995e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(0),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithNoDeviationFeeAndCashback() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(46e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-3571428571428571500)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(51e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(3571428571428571500),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithNoDeviationFeeAndCashbackReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(46e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-3571428571428571500)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(51e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(3571428571428571500),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5.0005e18);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function burnWithNoDeviationFeeAndCashbackReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18 - 6139944596199629000)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50.9995e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(6139944596199629000),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5.0005e18);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);

    }

    function burnWithNoDeviationFeeAndCashback() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18 - 6139944596199629000)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50.9995e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(6139944596199629000),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }
}

contract TestMultipoolMathCorner {

    function assertContext(MpContext memory a, MpContext memory b) public {
        require(a.totalCurrentUsdAmount == b.totalCurrentUsdAmount, "totalCurrentUsdAmount not equal");
        require(a.totalAssetPercents == b.totalAssetPercents, "totalAssetPercents not equal");
        require(a.curveCoef == b.curveCoef, "curveCoef not equal");
        require(a.deviationPercentLimit == b.deviationPercentLimit, "deviationPercentLimit not equal");
        require(a.operationBaseFee == b.operationBaseFee, "operationBaseFee not equal");
        require(a.userCashbackBalance == b.userCashbackBalance, "userCashbackBalance not equal");
    }

    function assertAsset(MpAsset memory a, MpAsset memory b) public {
        require(a.quantity == b.quantity, "quantity not equal");
        require(a.price == b.price, "price not equal");
        require(a.collectedFees == b.collectedFees, "collectedFees not equal");
        require(a.collectedCashbacks == b.collectedCashbacks, "collectedCashbacks not equal");
        require(a.percent == b.percent, "percent not equal");
    }

    //TODO: mint/burn after deviation is > deviation limit:
    // can't make deviation bigger
    //TODO: mint/burn to deviation more then deviation limit

    //TODO: if asset percent == 0 - ban all actions that don't reduce value
    //TODO: if deviation old == 0 calculate cashback

    // change no deviation (from - to +)
    function mintWithDeviationBiggerThanLimit() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-8730158730158730167)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(25e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(8730158730158730167),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintWithDeviationBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-8730158730158730167)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(25e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(8730158730158730167),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5.0005e18);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function burnWithDeviationBiggerThanLimit() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1000e18 - 50.005e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-9649085872381784434)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(80e18-5.0005e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(9649085872381784434),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(5e18);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function burnWithDeviationBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1000e18 - 50.005e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-9649085872381784434)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(80e18-5.0005e18),
            price:              sd(10e18),
            collectedFees:      sd(0.0005e18),
            collectedCashbacks: sd(9649085872381784434),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5.0005e18);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);

    }
    function mintTooMuch() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5000.0005e18);
        
        SD59x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1000e18 + 249995289120819944910),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50e18 + 24999528912081994491),
            price:              sd(10e18),
            collectedFees:      sd(2499952891208199),
            collectedCashbacks: sd(10e18+5000.0005e18 - 2499952891208199 - 24999528912081994491),
            percent:            sd(50e18)
        });
        SD59x18 resultUtilisableQuantity = sd(24999528912081994491);

        require(resultUtilisableQuantity == utilisableQuantity, "utilisable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function mintTooMuchReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(24999528912081994491);

        SD59x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            totalCurrentUsdAmount:  sd(1000e18 + 249995289120819944910),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity:           sd(50e18 + 24999528912081994491),
            price:              sd(10e18),
            collectedFees:      sd(2499952891208199),
            collectedCashbacks: sd(10e18 + 5000000499999930836640 - 2499952891208199 - 24999528912081994491),
            percent:            sd(50e18)
        });
        SD59x18 resultSuppliableQuantity = sd(5000000499999930836640);

        require(resultSuppliableQuantity == suppliableQuantity, "suppliable quantity not match");
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function burnTooMuch() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(80e18)
        });

        SD59x18 suppliedQuantity = sd(50e18);

        SD59x18 utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function burnTooMuchReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(80e18)
        });
        SD59x18 utilisableQuantity = sd(50e18);

        SD59x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }
    function mintTooMuchBeingBiggerThanLimit() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5000.0005e18);

        SD59x18 suppliedQuantity = context.mint(asset, utilisableQuantity);
    }

    function mintTooMuchBeingBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5000e18);

        SD59x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);
    }

    function burnTooMuchBeingBiggerThanLimit() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(10e18);

        SD59x18 utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function burnTooMuchBeingBiggerThanLimitMoreThenQuantity() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(100e18);

        SD59x18 utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function burnTooMuchBeingBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(10e18);

        SD59x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }

    function burnTooMuchBeingBiggerThanLimitMoreThenQuantityReversed() public {
        MpContext memory context = MpContext({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5000e18);

        SD59x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }
}
