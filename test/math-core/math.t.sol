// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {IMultipoolErrors} from "../../src/interfaces/multipool/IMultipoolErrors.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MpMath, expandFrom16,expandFrom19,expandFrom20} from "../../src/lib/MpContext.sol";
import {MultipoolUtils, toX96, toX32, toX16, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";

struct Token {
    uint targetShare;
    uint quantity;
    uint price;
    uint collectedCashbacks;
}

struct Fees {
    uint deviationIncreaseFee;
    uint deviationLimit;
    uint feeToCashbackRatio;
    uint baseFee; 
    uint lpBaseFee; 
    uint managementBaseFee;
}

struct Swap {
    Fees fees;
    Token[] tokens;
    uint totalSupply;
    int indexIn;
    int indexOut;
    uint swapAmount;
    bool isExactInput;
    bool expectRevert;
}

contract MultipoolCoreDeviationTests is Test {
    receive() external payable {}

    function calculate(Swap memory swap) internal returns 
            (
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,
            uint amountIn,
            uint amountOut,
            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        )
    {
        uint totalTargetShares = 0;
        uint tvl = 0;

        for(uint i = 0; i < swap.tokens.length; i++) {
            Token memory t = swap.tokens[i];
            totalTargetShares = totalTargetShares + t.targetShare;
            tvl = tvl + t.quantity * t.price;
        }
        uint sharePrice;
        if (swap.totalSupply != 0) {
            sharePrice = tvl / swap.totalSupply;
        } else {
            sharePrice = uint(1 << 96);
        }
        Token memory tokenIn;
        Token memory tokenOut;

        bool isMint = false;
        bool isBurn = false;

        if(swap.indexIn >= 0) {
            tokenIn = swap.tokens[uint(swap.indexIn)];
        } else {
            isBurn = true;
            tokenIn.price = sharePrice;
        }

        if(swap.indexOut >= 0) {
            tokenOut = swap.tokens[uint(swap.indexOut)];
        } else {
            isMint = true;
            tokenOut.price = sharePrice;
        }

        if (swap.expectRevert) {
            vm.expectRevert();
        }
        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = MpMath.calculateSwap(
            swap.totalSupply, 
            totalTargetShares, 
            swap.fees.deviationIncreaseFee, 
            swap.fees.deviationLimit, 
            swap.fees.feeToCashbackRatio, 
            swap.fees.baseFee, 
            swap.fees.lpBaseFee, 
            swap.fees.managementBaseFee, 
            tokenIn.quantity, 
            tokenIn.collectedCashbacks, 
            tokenIn.targetShare, 
            tokenOut.quantity, 
            tokenOut.collectedCashbacks, 
            tokenOut.targetShare, 
            isMint, 
            isBurn, 
            swap.swapAmount, 
            swap.isExactInput, 
            tokenIn.price, 
            tokenOut.price, 
            sharePrice
        );

    }

    function test_calculateSwapHappyPath() public {
        Token[] memory tokens = new Token[](3);
        tokens[0] = Token({
            quantity: 15e18,
            price: toX96(1.5e18),
            collectedCashbacks: 1e18,
            targetShare: 118
        });
        tokens[1] = Token({
            quantity: 1e18,
            price: toX96(3.2e18),
            collectedCashbacks: 1e18,
            targetShare: 250
        });
        tokens[2] = Token({
            quantity: 1e18,
            price: toX96(3.2e18),
            collectedCashbacks: 1e18,
            targetShare: 131
        });
        Fees memory fees = Fees({
            deviationIncreaseFee: expandFrom19(1e3),
            deviationLimit: expandFrom16(1e5),
            feeToCashbackRatio: expandFrom19(1e4),
            baseFee: expandFrom20(3e3),
            lpBaseFee: 0, 
            managementBaseFee: expandFrom19(1e4)
        });

        Swap memory swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: 0,
            indexOut: 1,
            swapAmount: 1e7,
            isExactInput: true,
            expectRevert: false
        });
        (
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,
            uint amountIn,
            uint amountOut,
            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 1e7);
        assertEq(amountOut, 4687500);
        assertEq(newQuantityIn, 15e18 + 1e7);
        assertEq(newQuantityOut, 999999999995312500);
        assertEq(managerEarnedFee, 899);
        assertEq(oracleEarnedFee, 44100);
        assertEq(lpEarnedFee, 0);
        assertEq(newCollectedCashbacksIn, 1e18);
        assertEq(newCollectedCashbacksOut, 1e18);
        assertEq(cashbacksRefund, 0);

       
        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: 0,
            indexOut: 1,
            swapAmount: 1e18,
            expectRevert: false,
            isExactInput: true
        });

        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 1e18);
        assertEq(amountOut, 4.6875e17);
        assertEq(newQuantityIn, 16e18);
        assertEq(newQuantityOut, 531250000000000000);
        assertEq(managerEarnedFee, 207599983494915);
        assertEq(oracleEarnedFee, 10172399302422813);
        assertEq(lpEarnedFee, 0);
        assertEq(newCollectedCashbacksIn, 1000059999995222315);
        assertEq(newCollectedCashbacksOut, 1000059999995222315);
        assertEq(cashbacksRefund, 0);

          
        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: 0,
            indexOut: 1,
            swapAmount: 4.6875e17,
            expectRevert: false,
            isExactInput: false
        });

        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 999999999999999999);
        assertEq(amountOut, 4.6875e17);
        assertEq(newQuantityIn, 15999999999999999999);
        assertEq(newQuantityOut, 531250000000000000);
        assertEq(managerEarnedFee, 207599983494915);
        assertEq(oracleEarnedFee, 10172399302422813);
        assertEq(lpEarnedFee, 0);
        assertEq(newCollectedCashbacksIn, 1000059999995222315);
        assertEq(newCollectedCashbacksOut, 1000059999995222315);
        assertEq(cashbacksRefund, 0);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_calculateMint() public {
        Token[] memory tokens = new Token[](3);
        tokens[0] = Token({
            quantity: 15e18,
            price: toX96(0.11e18),
            collectedCashbacks: 1e18,
            targetShare: 130
        });
        tokens[1] = Token({
            quantity: 1e18,
            price: toX96(1.2e18),
            collectedCashbacks: 1e18,
            targetShare: 20
        });
        tokens[2] = Token({
            quantity: 1e18,
            price: toX96(15.2e18),
            collectedCashbacks: 1e18,
            targetShare: 30
        });
        Fees memory fees = Fees({
            deviationIncreaseFee: expandFrom19(1e3),
            deviationLimit: expandFrom16(1e5),
            feeToCashbackRatio: expandFrom19(1e4),
            baseFee: expandFrom20(3e3),
            lpBaseFee: expandFrom19(3e4), 
            managementBaseFee: expandFrom19(1e4)
        });

        Swap memory swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: 0,
            indexOut: -1,
            swapAmount: 1e18,
            expectRevert: false,
            isExactInput: true
        });
        (
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,
            uint amountIn,
            uint amountOut,
            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 1e18);
        assertEq(amountOut, 6094182825484764);
        assertEq(newQuantityIn, 16e18);
        assertEq(newQuantityOut, 0);
        assertEq(managerEarnedFee, 6599999474454);
        assertEq(oracleEarnedFee, 303599979205616);
        assertEq(lpEarnedFee, 19799998577032);
        assertEq(newCollectedCashbacksIn, 990339107074223729);
        assertEq(newCollectedCashbacksOut, 0);
        assertEq(cashbacksRefund, 9660892925776271);

        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: 1,
            indexOut: -1,
            swapAmount: 1e18,
            expectRevert: false,
            isExactInput: false
        });

        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 15041666666666666665);
        assertEq(amountOut, 1e18);
        assertEq(newQuantityIn, 16041666666666666665);
        assertEq(newQuantityOut, 0);
        assertEq(managerEarnedFee, 1790559857575801);
        assertEq(oracleEarnedFee, 82365754365660733);
        assertEq(lpEarnedFee, 5371679614417125);
        assertEq(newCollectedCashbacksIn, 1000721999942508526);
        assertEq(newCollectedCashbacksOut, 0);
        assertEq(cashbacksRefund, 0);

        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: 1,
            indexOut: -1,
            swapAmount: 10e18,
            expectRevert: true,
            isExactInput: false
        });
        // vm.expectRevert(IMultipoolErrors.DeviationExceedsLimit.selector);
        calculate(swap);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_calculateBurn() public {
        Token[] memory tokens = new Token[](3);
        tokens[0] = Token({
            quantity: 13e18,
            price: toX96(0.01e18),
            collectedCashbacks: 1e18,
            targetShare: 130
        });
        tokens[1] = Token({
            quantity: 20e18,
            price: toX96(10.2e18),
            collectedCashbacks: 1e18,
            targetShare: 256
        });
        tokens[2] = Token({
            quantity: 11e18,
            price: toX96(1.2e18),
            collectedCashbacks: 1e18,
            targetShare: 83
        });
        Fees memory fees = Fees({
            deviationIncreaseFee: expandFrom19(1e3),
            deviationLimit: expandFrom16(1e5),
            feeToCashbackRatio: expandFrom19(1e4),
            baseFee: expandFrom20(3e3),
            lpBaseFee: expandFrom19(3e4), 
            managementBaseFee: expandFrom19(1e4)
        });

        Swap memory swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 110034.1234e18,
            indexIn: -1,
            indexOut: 1,
            swapAmount: 1e18,
            expectRevert: false,
            isExactInput: true
        });
        (
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,
            uint amountIn,
            uint amountOut,
            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 1e18);
        assertEq(amountOut, 193638683044191);
        assertEq(newQuantityIn, 1e18);
        assertEq(newQuantityOut, 19999806361316955809);
        assertEq(managerEarnedFee, 118506864586);
        assertEq(oracleEarnedFee, 5451315831686);
        assertEq(lpEarnedFee, 355520596518);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 999976864668304486);
        assertEq(cashbacksRefund, 23135331695514);

        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 11.16554e18,
            indexIn: -1,
            indexOut: 0,
            swapAmount: 1e18,
            expectRevert: false,
            isExactInput: false
        });

        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 513759720241107);
        assertEq(amountOut, 1e18);
        assertEq(newQuantityIn, 513759720241107);
        assertEq(newQuantityOut, 12e18);
        assertEq(managerEarnedFee, 991999921094);
        assertEq(oracleEarnedFee, 45631996878483);
        assertEq(lpEarnedFee, 2975999786380);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 1000000399999968148);
        assertEq(cashbacksRefund, 0);

        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: -1,
            indexOut: 0,
            swapAmount: 10e18,
            expectRevert: false,
            isExactInput: false
        });
        // vm.expectRevert(IMultipoolErrors.DeviationExceedsLimit.selector);

        // Can calculate necessary amount even if there is no supply for it    
        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 460129756591358);
        assertEq(amountOut, 10e18);
        assertEq(newQuantityIn, 460129756591358);
        assertEq(newQuantityOut, 3e18);
        assertEq(managerEarnedFee, 9919999210946);
        assertEq(oracleEarnedFee, 456319968784824);
        assertEq(lpEarnedFee, 29759997863806);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 1000003999999681487);
        assertEq(cashbacksRefund, 0);

        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1e18,
            indexIn: -1,
            indexOut: 1,
            swapAmount: 20e18,
            expectRevert: false,
            isExactInput: false
        });
        // TODO why?
        // vm.expectRevert(IMultipoolErrors.DeviationExceedsLimit.selector);
        calculate(swap);
    }


    /// forge-config: default.allow_internal_expect_revert = true
    function test_calculateEmptyEtf() public {
        Token[] memory tokens = new Token[](3);
        tokens[0] = Token({
            quantity: 0,
            price: toX96(0.01e18),
            collectedCashbacks: 0,
            targetShare: 130
        });
        tokens[1] = Token({
            quantity: 0,
            price: toX96(10.2e18),
            collectedCashbacks: 0,
            targetShare: 256
        });
        tokens[2] = Token({
            quantity: 0,
            price: toX96(1.2e18),
            collectedCashbacks: 0,
            targetShare: 83
        });
        Fees memory fees = Fees({
            deviationIncreaseFee: expandFrom19(1e3),
            deviationLimit: expandFrom16(1e5),
            feeToCashbackRatio: expandFrom19(1e4),
            baseFee: expandFrom20(3e3),
            lpBaseFee: expandFrom19(3e4), 
            managementBaseFee: expandFrom19(1e4)
        });

        Swap memory swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 0,
            indexIn: 1,
            indexOut: -1,
            swapAmount: 1e18,
            expectRevert: false,
            isExactInput: true
        });

        (
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,
            uint amountIn,
            uint amountOut,
            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 1e18);
        assertEq(amountOut, 10199999999999999999);
        assertEq(newQuantityIn, 1e18);
        assertEq(newQuantityOut, 0);
        assertEq(managerEarnedFee, 611999951267615);
        assertEq(oracleEarnedFee, 28151998071793467);
        assertEq(lpEarnedFee, 1835999868052080);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 0);
        assertEq(cashbacksRefund, 0);

        swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 11.16554e18,
            indexIn: 1,
            indexOut: -1,
            swapAmount: 1e18,
            expectRevert: false,
            isExactInput: false
        });

        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 0);
        assertEq(amountOut, 1e18);
        assertEq(newQuantityIn, 0);
        assertEq(newQuantityOut, 0);
        assertEq(managerEarnedFee, 0);
        assertEq(oracleEarnedFee, 0);
        assertEq(lpEarnedFee, 0);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 0);
        assertEq(cashbacksRefund, 0);

    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_calculateFees() public {
        Token[] memory tokens = new Token[](3);
        tokens[0] = Token({
            quantity: 23e18,
            price: toX96(0.01e18),
            collectedCashbacks: 0,
            targetShare: 101
        });
        tokens[1] = Token({
            quantity: 53e18,
            price: toX96(10.2e18),
            collectedCashbacks: 0,
            targetShare: 128
        });
        tokens[2] = Token({
            quantity: 7e18,
            price: toX96(1.2e18),
            collectedCashbacks: 0,
            targetShare: 10
        });
        Fees memory fees = Fees({
            deviationIncreaseFee: expandFrom19(0),
            deviationLimit: expandFrom16(1e5),
            feeToCashbackRatio: expandFrom19(0),
            baseFee: expandFrom20(0),
            lpBaseFee: expandFrom19(3e4), 
            managementBaseFee: expandFrom19(1e4)
        });

        // TODO 
        // fix `call didn't revert at a lower depth than cheatcode call depth` 
        // for `arithmetic underflow or overflow` on newQuantityOut
        // TODO add tests for errors

        // Swap memory swap = Swap({
        //     fees: fees,
        //     tokens: tokens,
        //     totalSupply: 1023e18,
        //     indexIn: 1,
        //     indexOut: 0,
        //     swapAmount: 1e18,
        //     // amount out is bigger than available quantity
        //     expectRevert: true,
        //     isExactInput: true
        // });
        // calculate(swap);

        Swap memory swap = Swap({
            fees: fees,
            tokens: tokens,
            totalSupply: 1023e18,
            indexIn: 1,
            indexOut: 0,
            swapAmount: 1e14,
            expectRevert: false,
            isExactInput: true
        });

        (
            uint managerEarnedFee,
            uint oracleEarnedFee,
            uint lpEarnedFee,
            uint cashbacksRefund,
            uint amountIn,
            uint amountOut,
            uint newQuantityIn,
            uint newCollectedCashbacksIn,
            uint newQuantityOut,
            uint newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 1e14);
        assertEq(amountOut, 101999999999999900);
        assertEq(newQuantityIn, 53000100000000000000);
        assertEq(newQuantityOut, 22898000000000000100);
        // 0 because of 0 base fee all fees are 0
        assertEq(managerEarnedFee, 0);
        assertEq(oracleEarnedFee, 0);
        assertEq(lpEarnedFee, 0);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 0);
        assertEq(cashbacksRefund, 0);


        fees = Fees({
            deviationIncreaseFee: expandFrom19(1e3),
            deviationLimit: expandFrom16(1e3),
            feeToCashbackRatio: expandFrom19(1e3),
            baseFee: expandFrom20(0),
            lpBaseFee: expandFrom19(0), 
            managementBaseFee: expandFrom19(0)
        });
    
        swap.fees = fees;
        swap.expectRevert = true;
        // too mush deviation
        // calculate(swap);
        swap.expectRevert = false;
        swap.swapAmount = 1e5;

        (
            managerEarnedFee,
            oracleEarnedFee,
            lpEarnedFee,
            cashbacksRefund,
            amountIn,
            amountOut,
            newQuantityIn,
            newCollectedCashbacksIn,
            newQuantityOut,
            newCollectedCashbacksOut
        ) = calculate(swap);

        assertEq(amountIn, 1e5);
        assertEq(amountOut, 101999900);
        assertEq(newQuantityIn, 53000000000000100000);
        assertEq(newQuantityOut, 22999999999898000100);
        // 0 because of 0 base fee all fees are 0
        assertEq(managerEarnedFee, 0);
        assertEq(oracleEarnedFee, 0);
        assertEq(lpEarnedFee, 0);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 0);
        assertEq(cashbacksRefund, 0);
    }
}
