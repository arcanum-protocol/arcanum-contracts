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
            totalCurrentUsdAmount:  sd(1000e18) - sd(5005866126138531618) * sd(10e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        //TODO: 397 wei difference between burn and reversed burn. This might take place bacuse 
        // of square root calculation or any other heavy ops. Find out few tests to show this
        // diff won't grow with other numbers a lot
        SD59x18 suppliedQuantity = sd(5005866126138531618 - 397);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18) - sd(5005866126138531618 - 397) * sd(10e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(46e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0005e18);

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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(46e18),
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalBurnContext(utilisableQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(0e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(0e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(46e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalMintContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-3571428571428571500)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(46e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
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
            userCashbackBalance:    sd(11e18-3571428571428571500)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalBurnContext(utilisableQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18 - 6139944596199629000)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(56e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(949.995e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18 - 6139944596199629000)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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

    //TODO: mint/burn after deviation is > deviation limit:
    // can't make deviation bigger
    //TODO: mint/burn to deviation more then deviation limit

    //TODO: if asset percent == 0 - ban all actions that don't reduce value
    //TODO: if deviation old == 0 calculate cashback

    // change no deviation (from - to +)
    function mintWithDeviationBiggerThanLimit() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalMintContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1050e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-8730158730158730167)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
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
            userCashbackBalance:    sd(11e18-8730158730158730167)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(5.0005e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18 - 50.005e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-9649085872381784434)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalBurnContext(utilisableQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18 - 50.005e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(11e18-9649085872381784434)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 suppliedQuantity = sd(5000.0005e18);
        
        SD59x18 utilisableQuantity = MultipoolMath.evalMintContext(suppliedQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18 + 249995289120819944910),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(50e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(24999528912081994491);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalMintContext(utilisableQuantity, context, asset);

        MultipoolMath.Context memory resultContext = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18 + 249995289120819944910),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory resultAsset = MultipoolMath.Asset({
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
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(80e18)
        });

        SD59x18 suppliedQuantity = sd(50e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);
    }

    function burnTooMuchReversed() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(80e18)
        });
        SD59x18 utilisableQuantity = sd(50e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalBurnContext(utilisableQuantity, context, asset);
    }
    function mintTooMuchBeingBiggerThanLimit() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(80e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5000.0005e18);

        SD59x18 suppliedQuantity = MultipoolMath.evalMintContext(utilisableQuantity, context, asset);
    }

    function mintTooMuchBeingBiggerThanLimitReversed() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5000e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalMintContext(utilisableQuantity, context, asset);
    }

    function burnTooMuchBeingBiggerThanLimit() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(10e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);
    }

    function burnTooMuchBeingBiggerThanLimitMoreThenQuantity() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });

        SD59x18 suppliedQuantity = sd(100e18);

        SD59x18 utilisableQuantity = MultipoolMath.evalBurnContext(suppliedQuantity, context, asset);
    }

    function burnTooMuchBeingBiggerThanLimitReversed() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(10e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalBurnContext(utilisableQuantity, context, asset);
    }

    function burnTooMuchBeingBiggerThanLimitMoreThenQuantityReversed() public {
        MultipoolMath.Context memory context = MultipoolMath.Context({
            totalCurrentUsdAmount:  sd(1000e18),
            totalAssetPercents:     sd(100e18),
            curveCoef:              sd(0.0003e18),
            deviationPercentLimit:  sd(0.1e18),
            operationBaseFee:       sd(0.0001e18),
            userCashbackBalance:    sd(1e18)
        });
        MultipoolMath.Asset memory asset = MultipoolMath.Asset({
            quantity:           sd(20e18),
            price:              sd(10e18),
            collectedFees:      sd(0e18),
            collectedCashbacks: sd(10e18),
            percent:            sd(50e18)
        });
        SD59x18 utilisableQuantity = sd(5000e18);

        SD59x18 suppliableQuantity = MultipoolMath.reversedEvalBurnContext(utilisableQuantity, context, asset);
    }
}
