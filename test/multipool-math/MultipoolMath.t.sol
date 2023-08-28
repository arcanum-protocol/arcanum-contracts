pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";

import {MpAsset, MpContext} from "../../src/multipool/MpCommonMath.sol";
import {MpComplexMath} from "../../src/multipool/MpComplexMath.sol";

//TODO: add test to burn till zero

contract MultipoolMathTest is Test {
    using {
        MpComplexMath.mintRev,
        MpComplexMath.burnRev,
        MpComplexMath.mint,
        MpComplexMath.burn,
        MpComplexMath.burnTrace
    } for MpContext;

    function setUp() public {}

    function assertContext(MpContext memory a, MpContext memory b) public {
        assertEq(a.usdCap, b.usdCap, "usd cap");
        assertEq(a.totalTargetShares, b.totalTargetShares, "target shares");
        assertEq(a.halfDeviationFee, b.halfDeviationFee, "half deviation fee");
        assertEq(a.deviationLimit, b.deviationLimit, "deviation limit");
        assertEq(a.operationBaseFee, b.operationBaseFee, "operation base fee");
        assertEq(a.userCashbackBalance, b.userCashbackBalance, "user cashback balance");
        assertEq(a.depegBaseFee, b.depegBaseFee, "depeg base fee");
    }

    function assertAsset(MpAsset memory a, MpAsset memory b) public {
        assertEq(a.quantity, b.quantity, "quantity");
        assertEq(a.price, b.price, "price");
        assertEq(a.collectedFees, b.collectedFees, "collected fees");
        assertEq(a.collectedCashbacks, b.collectedCashbacks, "collected cashbacks");
        assertEq(a.share, b.share, "share");
    }

    function test_mintWithZeroBalanceReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 0e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 0e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint utilisableQuantity = 10000000e18;

        uint suppliedQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 100000000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset =
            MpAsset({quantity: 10000000e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint resultUtilisableQuantity = 10000000e18;

        assertEq(resultUtilisableQuantity, suppliedQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithZeroBalance() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 0e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 0e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint suppliedQuantity = 10000000e18;

        uint utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 100000000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset =
            MpAsset({quantity: 10000000e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint resultUtilisableQuantity = 10000000e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint suppliedQuantity = 5.0051875e18;

        uint utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 55e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 0.0051875e18 - 0.0005e18,
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 55e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 5005187499999999999 - 5.0005e18,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5005187499999999999;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18 - 5005866126138531618 * 10,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50e18 - 5005866126138531618,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 5005866126138531618 - 5.0005e18,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5005866126138531618;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        //TODO: 397 wei difference between burn and reversed burn. This might take place bacuse
        // of square root calculation or any other heavy ops. Find out few tests to show this
        // diff won't grow with other numbers a lot
        uint suppliedQuantity = 5005866126138531618;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18 - 5005866126138531618 * 10,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50e18 - 5005866126138531618,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 5005866126138531618 - 2 - 5.0005e18,
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18 + 2;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 46e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint suppliedQuantity = 5.0005e18;

        uint utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset =
            MpAsset({quantity: 51e18, price: 10e18, collectedFees: 0.0005e18, collectedCashbacks: 0, share: 50e18});
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 46e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset =
            MpAsset({quantity: 51e18, price: 10e18, collectedFees: 0.0005e18, collectedCashbacks: 0, share: 50e18});
        uint resultSuppliableQuantity = 5.0005e18;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFeeReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 56e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 949.995e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset =
            MpAsset({quantity: 50.9995e18, price: 10e18, collectedFees: 0.0005e18, collectedCashbacks: 0, share: 50e18});
        uint resultSuppliableQuantity = 5.0005e18;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 56e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});

        uint suppliedQuantity = 5.0005e18;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 949.995e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset =
            MpAsset({quantity: 50.9995e18, price: 10e18, collectedFees: 0.0005e18, collectedCashbacks: 0, share: 50e18});
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFeeAndCashback() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 46e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint suppliedQuantity = 5.0005e18;

        uint utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 3571428571428571500
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 51e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 3571428571428571500,
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithNoDeviationFeeAndCashbackReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 46e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 3571428571428571500
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 51e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 3571428571428571500,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5.0005e18;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFeeAndCashbackReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 56e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 949.995e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 6139944596199629000
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50.9995e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 6139944596199629000,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5.0005e18;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithNoDeviationFeeAndCashback() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 56e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});

        uint suppliedQuantity = 5.0005e18;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 949.995e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 6139944596199629000
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50.9995e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 6139944596199629000,
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    //TODO: mint/burn after deviation is > deviation limit:
    // can't make deviation bigger
    //TODO: mint/burn to deviation more then deviation limit

    //TODO: if asset share == 0 - ban all actions that don't reduce value
    //TODO: if deviation old == 0 calculate cashback

    // change no deviation (from - to +)
    function test_mintWithDeviationBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 20e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint suppliedQuantity = 5.0005e18;

        uint utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 8730158730158730167
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 25e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 8730158730158730167,
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 20e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 8730158730158730167
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 25e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 8730158730158730167,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5.0005e18;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 80e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});

        uint suppliedQuantity = 5.0005e18;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18 - 50.005e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 9649085872381784434
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 80e18 - 5.0005e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 9649085872381784434,
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 80e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18 - 50.005e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 11e18 - 9649085872381784434
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 80e18 - 5.0005e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 9649085872381784434,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5.0005e18;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintTooMuch() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint suppliedQuantity = 5000.0005e18;

        uint utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18 + 249995289120819944910,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50e18 + 24999528912081994491,
            price: 10e18,
            collectedFees: 2499952891208199,
            collectedCashbacks: 10e18 + 5000.0005e18 - 2499952891208199 - 24999528912081994491,
            share: 50e18
        });
        uint resultUtilisableQuantity = 24999528912081994491;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintTooMuchReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 24999528912081994491;

        uint suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18 + 249995289120819944910,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50e18 + 24999528912081994491,
            price: 10e18,
            collectedFees: 2499952891208199,
            collectedCashbacks: 10e18 + 5000000499999989500991 - 2499952891208199 - 24999528912081994491,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5000000499999989500991;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function testFail_burnTooMuch() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 80e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 80e18});

        uint suppliedQuantity = 50e18;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function testFail_burnTooMuchReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 80e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 80e18});
        uint utilisableQuantity = 50e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }

    function testFail_mintTooMuchBeingBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 80e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 5000.0005e18;

        uint suppliedQuantity = context.mint(asset, utilisableQuantity);
    }

    function testFail_mintTooMuchBeingBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 20e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 5000e18;

        uint suppliableQuantity = context.mintRev(asset, utilisableQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimit() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 20e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});

        uint suppliedQuantity = 10e18;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimitMoreThenQuantity() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 20e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});

        uint suppliedQuantity = 100e18;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimitReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 20e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 10e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }

    function testFail_burnTooMuchBeingBiggerThanLimitMoreThenQuantityReversed() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 1e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 20e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 10e18, share: 50e18});
        uint utilisableQuantity = 5000e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);
    }

    function test_mintWithDeviationFeeAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 25e16, // 25% goes to fees
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint suppliedQuantity = 5.0051875e18;

        uint utilisableQuantity = context.mint(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 25e16, // 25% goes to fees
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 55e18,
            price: 10e18,
            collectedFees: 0.0005e18 + uint(0.0051875e18 - 0.0005e18) / uint(4),
            collectedCashbacks: (uint(0.0051875e18 - 0.0005e18) * uint(3)) / uint(4),
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_mintWithDeviationFeeReversedAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 1e18, // 100% goes to fees
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.mintRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 1e18, // 100% goes to fees
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 55e18,
            price: 10e18,
            collectedFees: 0.0005e18 + 5005187499999999999 - 5.0005e18,
            collectedCashbacks: 0,
            share: 50e18
        });
        uint resultSuppliableQuantity = 5005187499999999999;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFeeReversedAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 5e17, //50% goes to base fee
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint utilisableQuantity = 5e18;

        uint suppliableQuantity = context.burnRev(asset, utilisableQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 5e17, //50% goes to base fee
            usdCap: 1000e18 - 5005866126138531618 * 10,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50e18 - 5005866126138531618,
            price: 10e18,
            collectedFees: 0.0005e18 + uint(5005866126138531618 - 5.0005e18) / uint(2),
            collectedCashbacks: uint(5005866126138531618 - 5.0005e18) / uint(2),
            share: 50e18
        });
        uint resultSuppliableQuantity = 5005866126138531618;

        assertEq(resultSuppliableQuantity, suppliableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_burnWithDeviationFeeAndDepegBaseFee() public {
        MpContext memory context = MpContext({
            depegBaseFee: 1e17, // 10% goes to base fee
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory asset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        //TODO: 397 wei difference between burn and reversed burn. This might take place bacuse
        // of square root calculation or any other heavy ops. Find out few tests to show this
        // diff won't grow with other numbers a lot
        uint suppliedQuantity = 5005866126138531618;

        uint utilisableQuantity = context.burn(asset, suppliedQuantity);

        MpContext memory resultContext = MpContext({
            depegBaseFee: 1e17, // 10% goes to base fee
            usdCap: 1000e18 - (5005866126138531618) * 10,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory resultAsset = MpAsset({
            quantity: 50e18 - 5005866126138531618,
            price: 10e18,
            collectedFees: 0.0005e18 + (uint(5005866126138531618) - 2 - 5.0005e18) / 10,
            collectedCashbacks: (uint(5005866126138531618) - 2 - 5.0005e18) * 9 / 10 + 1,
            share: 50e18
        });
        uint resultUtilisableQuantity = 5e18 + 2;

        assertEq(resultUtilisableQuantity, utilisableQuantity);
        assertAsset(resultAsset, asset);
        assertContext(resultContext, context);
    }

    function test_Swap_prediction_in_burn() public {
        MpContext memory context = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });

        MpAsset memory mintAsset =
            MpAsset({quantity: 50e18, price: 10e18, collectedFees: 0e18, collectedCashbacks: 0e18, share: 50e18});
        uint mintAmountOut = 5e18;

        uint mintAmountIn = context.mintRev(mintAsset, mintAmountOut);

        MpContext memory expectedMintContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1050e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory expectedMintAsset = MpAsset({
            quantity: 55e18,
            price: 10e18,
            collectedFees: 0.0005e18,
            collectedCashbacks: 5005187499999999999 - 5.0005e18,
            share: 50e18
        });

        uint expectedMintAmountIn = 5005187499999999999;
        assertEq(expectedMintAmountIn, mintAmountIn);
        assertAsset(expectedMintAsset, mintAsset);
        assertContext(expectedMintContext, context);

        MpAsset memory burnAsset =
            MpAsset({quantity: 25e18, price: 20e18, collectedFees: 0, collectedCashbacks: 0, share: 50e18});

        uint burnAmountOut = context.burn(burnAsset, mintAmountOut / 2);

        MpContext memory expectedBurnContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        MpAsset memory expectedBurnAsset = MpAsset({
            quantity: 22.5e18,
            price: 20e18,
            collectedFees: 0.000249227395075266e18,
            collectedCashbacks: 2.5e18 - 0.000249227395075266e18 - 2.492273950752666733e18,
            share: 50e18
        });

        uint expectedBurnAmountOut = 2.492273950752666733e18;
        assertEq(expectedBurnAmountOut, burnAmountOut);
        assertAsset(expectedBurnAsset, burnAsset);
        assertContext(expectedBurnContext, context);

        MpAsset memory burnAssetCloned =
            MpAsset({quantity: 25e18, price: 20e18, collectedFees: 0, collectedCashbacks: 0, share: 50e18});

        MpContext memory initialContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        (uint tracedBurnAmountIn, uint traceBurnCashback, uint traceBurnFees) =
            initialContext.burnTrace(burnAssetCloned, 10e18, burnAmountOut);
        assertEq(tracedBurnAmountIn, 2.495533644017007922e18);
        assertEq(traceBurnCashback, 2.495533644017007922e18 - 0.000249227395075266e18 - 2.492273950752666733e18);
        assertEq(traceBurnFees, 0.000249227395075266e18);
        MpAsset memory expectedBurnAssetCloned =
            MpAsset({quantity: 25e18, price: 20e18, collectedFees: 0, collectedCashbacks: 0, share: 50e18});

        MpContext memory expectedInitialContext = MpContext({
            depegBaseFee: 0,
            usdCap: 1000e18,
            totalTargetShares: 100e18,
            halfDeviationFee: 0.0003e18,
            deviationLimit: 0.1e18,
            operationBaseFee: 0.0001e18,
            userCashbackBalance: 0e18
        });
        assertAsset(expectedBurnAssetCloned, burnAssetCloned);
        assertContext(expectedInitialContext, initialContext);
    }
}
