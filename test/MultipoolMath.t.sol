pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {UD60x18, ud} from "prb-math/UD60x18.sol";

import {MpAsset, MpContext} from "../src/multipool/MpCommonMath.sol";
//import "../src/multipool/MultipoolMath.sol";

//TODO: add test to burn till zero

contract MultipoolMathTest is Test {

    function setUp() public {
    }

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

    function test_mintWithZeroBalanceReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(0e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(0e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(10000000e18);

        UD60x18 suppliedQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(100000000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(10000000e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(10000000e18);

        require(
            resultUtilisableQuantity == suppliedQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithZeroBalance() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(0e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(0e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 suppliedQuantity = ud(10000000e18);

        UD60x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(100000000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(10000000e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(10000000e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 suppliedQuantity = ud(5.0051875e18);

        UD60x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(55e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(0.0051875e18 - 0.0005e18),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(55e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(5005187499999999906 - 5.0005e18),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5005187499999999906);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18) -
                ud(5005866126138531618) *
                ud(10e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50e18) - ud(5005866126138531618),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(5005866126138531618 - 5.0005e18),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5005866126138531618);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        //TODO: 397 wei difference between burn and reversed burn. This might take place bacuse
        // of square root calculation or any other heavy ops. Find out few tests to show this
        // diff won't grow with other numbers a lot
        UD60x18 suppliedQuantity = ud(5005866126138531618 - 397);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18) -
                ud(5005866126138531618 - 397) *
                ud(10e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50e18) - ud(5005866126138531618 - 397),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(5005866126138531618 - 397 - 5.0005e18),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(46e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 suppliedQuantity = ud(5.0005e18);

        UD60x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(51e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(0),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(46e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(51e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(0),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5.0005e18);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(56e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(949.995e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50.9995e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(0),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5.0005e18);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(56e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });

        UD60x18 suppliedQuantity = ud(5.0005e18);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(949.995e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50.9995e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(0),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFeeAndCashback() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(46e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 suppliedQuantity = ud(5.0005e18);

        UD60x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 3571428571428571500)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(51e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(3571428571428571500),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFeeAndCashbackReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(46e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 3571428571428571500)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(51e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(3571428571428571500),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5.0005e18);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFeeAndCashbackReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(56e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(949.995e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 6139944596199629000)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50.9995e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(6139944596199629000),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5.0005e18);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFeeAndCashback() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(56e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });

        UD60x18 suppliedQuantity = ud(5.0005e18);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(949.995e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 6139944596199629000)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50.9995e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(6139944596199629000),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        console.log(asset.collectedCashbacks.unwrap());
        console.log(resultAsset.collectedCashbacks.unwrap());
        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    //TODO: mint/burn after deviation is > deviation limit:
    // can't make deviation bigger
    //TODO: mint/burn to deviation more then deviation limit

    //TODO: if asset percent == 0 - ban all actions that don't reduce value
    //TODO: if deviation old == 0 calculate cashback

    // change no deviation (from - to +)
    function test_mintWithDeviationBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(20e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 suppliedQuantity = ud(5.0005e18);

        UD60x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 8730158730158730167)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(25e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(8730158730158730167),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(20e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 8730158730158730167)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(25e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(8730158730158730167),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5.0005e18);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(80e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });

        UD60x18 suppliedQuantity = ud(5.0005e18);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18 - 50.005e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 9649085872381784434)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(80e18 - 5.0005e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(9649085872381784434),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(80e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18 - 50.005e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(11e18 - 9649085872381784434)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(80e18 - 5.0005e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18),
            collectedCashbacks: ud(9649085872381784434),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5.0005e18);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintTooMuch() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 suppliedQuantity = ud(5000.0005e18);

        UD60x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18 + 249995289120819944910),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50e18 + 24999528912081994491),
            price: ud(10e18),
            collectedFees: ud(2499952891208199),
            collectedCashbacks: ud(
                10e18 + 5000.0005e18 - 2499952891208199 - 24999528912081994491
            ),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(24999528912081994491);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintTooMuchReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(24999528912081994491);

        UD60x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18 + 249995289120819944910),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50e18 + 24999528912081994491),
            price: ud(10e18),
            collectedFees: ud(2499952891208199),
            collectedCashbacks: ud(
                10e18 +
                    5000000499999930836640 -
                    2499952891208199 -
                    24999528912081994491
            ),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5000000499999930836640);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function testFail_burnTooMuch() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(80e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(80e18)
        });

        UD60x18 suppliedQuantity = ud(50e18);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function testFail_burnTooMuchReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(80e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(80e18)
        });
        UD60x18 utilisableQuantity = ud(50e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }

    function testFail_mintTooMuchBeingBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(80e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5000.0005e18);

        UD60x18 suppliedQuantity = context.mint(asset, utilisableQuantity);
    }

    function testFail_mintTooMuchBeingBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(20e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5000e18);

        UD60x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(20e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });

        UD60x18 suppliedQuantity = ud(10e18);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimitMoreThenQuantity() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(20e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });

        UD60x18 suppliedQuantity = ud(100e18);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(20e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(10e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimitMoreThenQuantityReversed() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(0),
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(1e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(20e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(10e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5000e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }

    function test_mintWithDeviationFeeAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(25e16), // 25% goes to fees
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 suppliedQuantity = ud(5.0051875e18);

        UD60x18 utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(25e16), // 25% goes to fees
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(55e18),
            price: ud(10e18),
            collectedFees: ud(
                0.0005e18 + uint(0.0051875e18 - 0.0005e18) / uint(4)
            ),
            collectedCashbacks: ud(
                (uint(0.0051875e18 - 0.0005e18) * uint(3)) / uint(4)
            ),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationFeeReversedAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(1e18), // 100% goes to fees
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(1e18), // 100% goes to fees
            totalCurrentUsdAmount: ud(1050e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(55e18),
            price: ud(10e18),
            collectedFees: ud(0.0005e18 + 5005187499999999906 - 5.0005e18),
            collectedCashbacks: ud(0),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5005187499999999906);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFeeReversedAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(5e17), //50% goes to base fee
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        UD60x18 utilisableQuantity = ud(5e18);

        UD60x18 suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(5e17), //50% goes to base fee
            totalCurrentUsdAmount: ud(1000e18) -
                ud(5005866126138531618) *
                ud(10e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50e18) - ud(5005866126138531618),
            price: ud(10e18),
            collectedFees: ud(
                0.0005e18 + uint(5005866126138531618 - 5.0005e18) / uint(2)
            ),
            collectedCashbacks: ud(
                uint(5005866126138531618 - 5.0005e18) / uint(2)
            ),
            percent: ud(50e18)
        });
        UD60x18 resultSuppliableQuantity = ud(5005866126138531618);

        require(
            resultSuppliableQuantity == suppliableQuantity,
            "suppliable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFeeAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFeeRatio: ud(1e17), // 10% goes to base fee
            totalCurrentUsdAmount: ud(1000e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory asset = MpAsset({
            quantity: ud(50e18),
            price: ud(10e18),
            collectedFees: ud(0e18),
            collectedCashbacks: ud(0e18),
            percent: ud(50e18)
        });
        //TODO: 397 wei difference between burn and reversed burn. This might take place bacuse
        // of square root calculation or any other heavy ops. Find out few tests to show this
        // diff won't grow with other numbers a lot
        UD60x18 suppliedQuantity = ud(5005866126138531618 - 397);

        UD60x18 utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFeeRatio: ud(1e17), // 10% goes to base fee
            totalCurrentUsdAmount: ud(1000e18) -
                ud(5005866126138531618 - 397) *
                ud(10e18),
            totalAssetPercents: ud(100e18),
            curveCoef: ud(0.0003e18),
            deviationPercentLimit: ud(0.1e18),
            operationBaseFee: ud(0.0001e18),
            userCashbackBalance: ud(0e18)
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: ud(50e18) - ud(5005866126138531618 - 397),
            price: ud(10e18),
            collectedFees: ud(
                0.0005e18 +
                    uint(5005866126138531618 - 397 - 5.0005e18) /
                    uint(10)
            ),
            collectedCashbacks: ud(
                (uint(5005866126138531618 - 397 - 5.0005e18) * uint(9)) /
                    uint(10) +
                    1
            ),
            percent: ud(50e18)
        });
        UD60x18 resultUtilisableQuantity = ud(5e18);

        require(
            resultUtilisableQuantity == utilisableQuantity,
            "utilisable quantity not match"
        );
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }
}
