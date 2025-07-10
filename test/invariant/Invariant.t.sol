// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MpMath} from "../../src/lib/MpMath.sol";
import {expandFrom19, expandFrom20} from "../../src/lib/MpContext.sol";


contract InvariantTests is Test {

    // function setUp() public {
    //     (bobby,) = makeAddrAndKey("Bobby");
    //     (bobbysFriend,) = makeAddrAndKey("bobbysFriend");

    //     protocolToken = new MockERC20("protocolToken", "protocolToken", 0);
    //     mockMp = new MockMp("MP", "MP", 0);

    //     Farm impl = new Farm();
    //     ERC1967Proxy proxy = new ERC1967Proxy(
    //         address(impl), abi.encodeWithSignature("initialize(address,address)", 
    //         address(this), address(protocolToken))
    //     );
    //     farm = Farm(payable(address(proxy)));

    //     protocolToken.mint(address(this), 100e18);
    //     mockMp.mint(address(this), 100e18);
    // }

    function test_quote() public {
        uint sharePrice = (uint(1654000) << 96) / 10e6;
        console2.log(sharePrice);
        console2.log(sharePrice * 10e6 >> 96);
        console2.log(uint(1 << 96));
        uint delta = 5e17;
        uint quote = MpMath.calculateLp(sharePrice, delta);
        assertEq(quote, 82699999999999999);
    }

    function test_happy() public {
        uint totalSupply = 10e18;
        uint sharePrice = (uint(1654000) << 96) / 10e6;
        uint tvl = totalSupply * sharePrice >> 96;
        uint deviationMultiplier = uint(10 << 96) / 100;
        uint deviationOffset = uint(20 << 96) / 100;
        uint cashbackMax = uint(50 << 96) / 100;
        uint cashbackFeeShare = expandFrom19(1e3);
        uint baseFee = expandFrom20(1e4);
        uint reserveIn = 1e16;
        uint priceIn = uint(143000000 << 96) / 10e6;
        uint collectedCashbacksIn = 10e18;
        uint targetShareIn = uint(10e18 << 96) / 30e18; // targetShare / totalTargetShares
        uint deltaIn = 1e16;
        (uint quoteIn, uint cashbackIn, uint feesIn) = MpMath.calculateX(
            totalSupply, 
            tvl, 
            sharePrice, 
            deviationMultiplier, 
            deviationOffset, 
            cashbackMax, 
            cashbackFeeShare, 
            baseFee, 
            reserveIn, 
            priceIn, 
            collectedCashbacksIn, 
            targetShareIn, 
            deltaIn
        );
        console2.log("------");
        console2.log(quoteIn);
        console2.log(cashbackIn);
        console2.log(feesIn);

        uint reserveOut = 1e16;
        uint priceOut = uint(221000000 << 96) / 10e6;
        uint collectedCashbacksOut = 10e18;
        uint targetShareOut = uint(10e18 << 96) / 30e18; // targetShare / totalTargetShares
        uint deltaOut = 1e10;

        (uint quoteOut, uint cashbackOut, uint feesOut) = MpMath.calculateY(
            totalSupply, 
            tvl, 
            sharePrice, 
            deviationMultiplier, 
            deviationOffset, 
            cashbackMax, 
            cashbackFeeShare, 
            baseFee, 
            reserveIn, 
            priceIn, 
            collectedCashbacksIn, 
            targetShareIn, 
            deltaIn
        );
        console2.log("------");

        console2.log(quoteOut);
        console2.log(cashbackOut);
        console2.log(feesOut);
    }
}