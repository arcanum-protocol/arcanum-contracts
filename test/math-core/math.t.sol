// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MpMath} from "../../src/lib/MpContext.sol";
import {MultipoolUtils, toX96, toX32, toX16, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";


contract MultipoolCoreDeviationTests is Test {
    receive() external payable {}

    function test_deviation() public {
        uint q = 12e18;
        uint p = toX96(115e18);
        // q1 300 * p1 100 + q2 500 * p2 101 
        uint tvl = 300 * toX96(100e18) + 500 * toX96(101e18);
        // t1 150 + t2 100 = totalShares 250
        uint t = 100;

        uint d = MpMath.deviation(q, p, tvl, t);
        assertEq(d, 73628010788571428571428471);

        q = 110e18;
        p = toX96(104e18);
        d = MpMath.deviation(q, p, tvl, t);
        assertEq(d, 610365538711055900621117912);
    }

    function test_calculateSwap() public {
        // 3 tokens
        // prices
        // 18 + 20 + 12
        // quantities
        // 
        // shares
        // 150 + 120 + 207
        uint _totalSupply = 1e18;
        uint _totalTargetShares = 477;
        uint _deviationIncreaseFee = 1e2;
        uint _deviationLimit = 1e5;
        uint _feeToCashbackRatio = 1e3; 
        uint _baseFee = 30000;
        uint _lpBaseFee = 0;
        uint _managementBaseFee = 1e3; 
        // token3
        uint _quantityIn = 65e18;
        uint _collectedCashbacksIn = 1e10;
        uint _targetShareIn = 206;
        // token1
        uint _quantityOut = 47e18; // _quantityIn * priceIn / priceOut
        uint _collectedCashbacksOut = 1e10;
        uint _targetShareOut = 150; 

        bool _isMint = false; 
        bool _isBurn = false;
        uint _swapAmount = 1e18;
        bool _isExactInput = true;
        uint _priceIn = toX96(12e18);
        uint _priceOut = toX96(18e18);
        uint _sharePrice = toX96(150);
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
        ) = MpMath.calculateSwap(
            _totalSupply, 
            _totalTargetShares, 
            _deviationIncreaseFee, 
            _deviationLimit, 
            _feeToCashbackRatio, 
            _baseFee, 
            _lpBaseFee, 
            _managementBaseFee, 
            _quantityIn, 
            _collectedCashbacksIn, 
            _targetShareIn, 
            _quantityOut, 
            _collectedCashbacksOut, 
            _targetShareOut, 
            _isMint, 
            _isBurn, 
            _swapAmount, 
            _isExactInput, 
            _priceIn, 
            _priceOut, 
            _sharePrice
        );

        assertEq(amountIn, 1e18);
        assertEq(amountOut, 666666666666666666);
        assertEq(newQuantityIn, 66e18);
        assertEq(newQuantityOut, 46333333333333333334);
        assertEq(managerEarnedFee, 19515639);
        assertEq(oracleEarnedFee, 83819012199754);
        assertEq(lpEarnedFee, 0);
        assertEq(newCollectedCashbacksIn, 0);
        assertEq(newCollectedCashbacksOut, 0);
    }
}
