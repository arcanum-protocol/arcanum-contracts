// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

    function testRevert_DeviationOverflowFeeWhenIsCloseToDeviationLimit() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        uint price = toX96(10e18);
        uint quoteSum = 246.153846e18;
        uint val = (quoteSum << 96) / price;

        tokens[0].mint(address(mp), val);

        OraclePrice memory op;

        vm.expectRevert();
        mp.swap{value: 100e15}(op, address(token0), address(mp), val, true, user0, address(0), true);
    }

    function test_MintWithDeviation() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );
        // 15 250 = p1*q1 + ...
        // quote value = 400 * 10 / 15250 = 0,262295082
        snapMultipool("MintFromSignleAssetWithDeviation0");

        uint newPrice = toX96(10e18);
        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / newPrice;
        console.log("val   ", val);

        changePrice(address(tokens[0]), newPrice);
        tokens[0].mint(address(mp), val);

        vm.prank(owner);
        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.09e18)))
        );
        // SharePriceParams memory sp;
        // sp.ts = uint128(block.timestamp);
        // sp.value = uint128(toX96(0.1e18));
        // sp.send = true;
        // 100.000000000000000000
        // 7,922,816,351.323433762029153469
        mp.increaseCashback{value: 1}(address(0));

        OraclePrice memory op;

        mp.swap{value: 0.2e18}(op, address(token0), address(mp), val, true, user0, address(0), false);

        snapMultipool("MintFromSignleAssetWithDeviation1");
    }

    function test_SwapHappyPath() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        tokens[0].mint(address(mp), 1e18);

        OraclePrice memory op;

        mp.swap{value: 0.2e18}(op, token0, token1, 1e18, true, user0, address(0), true);
        snapMultipool("SwapHappyPath1");
    }

    function test_RemoveOldToken() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        changeShare(address(tokens[1]), 0);

        tokens[1].mint(address(mp), 1e18);

        OraclePrice memory op;

        vm.expectRevert(abi.encodeWithSignature("TargetShareIsZero()"));
        mp.swap{value: uint128(toX96(0.1e18))}(op, address(token1), address(token0), 1e18, true, user0, address(0), true);

        tokens[0].mint(address(mp), 1e18);
        mp.swap{value: uint128(toX96(0.1e18))}(op, address(token0), address(token1), 1e18, true, user0, address(0), true);

        // swapExt(
        //     sort(
        //         dynamic(
        //             [
        //                 AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
        //                 AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
        //                 AssetArgs({assetAddress: address(tokens[2]), amount: int(-2e18)}),
        //                 AssetArgs({assetAddress: address(tokens[3]), amount: int(-4e18)})
        //             ]
        //         )
        //     ),
        //     100e18,
        //     users[0],
        //     sp,
        //     users[3],
        //     true,
        //     false,
        //     abi.encodeWithSignature("TargetShareIsZero()")
        // );

        // swapExt(
        //     sort(
        //         dynamic(
        //             [
        //                 AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
        //                 AssetArgs({assetAddress: address(tokens[1]), amount: int(-0.1e18)}),
        //                 AssetArgs({assetAddress: address(tokens[2]), amount: int(-0.1e18)})
        //             ]
        //         )
        //     ),
        //     100e18,
        //     users[0],
        //     sp,
        //     users[3],
        //     true,
        //     false,
        //     abi.encode(0)
        // );

        snapMultipool("RemoveOldToken");
    }

    function test_AddNewTokenAndTryToBurnWithIt() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        MockERC20 newOne = new MockERC20("NEW", "NEW", 0);

        changeShare(address(newOne), 1000);

        //uint newPrice = toX96(10e18);
        //uint quoteSum = 10e18;
        //uint val = (quoteSum << 96) / newPrice;

        //changePrice(address(tokens[0]), newPrice);
        tokens[0].mint(address(mp), 1e18);

        OraclePrice memory op;

        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.swap{value: uint128(toX96(0.1e18))}(op, address(token0), address(newOne), 1e18, true, user0, address(0), true);

        uint newPrice = toX96(10e18);
        changePrice(address(newOne), newPrice);

        vm.expectRevert(abi.encodePacked("ERC20: transfer amount exceeds balance"));
        mp.swap{value: uint128(toX96(0.1e18))}(op, address(token0), address(newOne), 1e18, true, user0, address(0), true);

        newOne.mint(address(mp), 1e18);

        vm.expectRevert(abi.encodeWithSignature("NotEnoughQuantityToBurn()"));
        mp.swap{value: uint128(toX96(0.1e18))}(op, address(token0), address(newOne), 1e18, true, user0, address(0), true);

        mp.swap{value: uint128(toX96(0.1e18))}(op, address(newOne), address(token0), 1e18, true, user0, address(0), true);

        snapMultipool("AddNewTokenAndTryToBurnWithIt");
        (bool isUsed, uint quantity, uint cashback, uint targetShare) = mp.getAsset(address(newOne));
        assertEq(isUsed,true);
        assertEq(quantity,1e18); 
        assertEq(cashback,0); 
        assertEq(targetShare,1000); 
        assertEq(newOne.balanceOf(address(mp)), 1e18);

        newOne.mint(address(mp), 25e18);

        mp.swap{value: uint128(toX96(0.1e18))}(
            op, address(newOne), address(tokens[0]), 25e18, true, user0, address(0), true
        );

        snapMultipool("AddNewTokenAndTryToBurnWithIt2");
        (isUsed, quantity, cashback, targetShare) = mp.getAsset(address(newOne));
        assertEq(isUsed,true);
        assertEq(quantity,28e18); 
        assertEq(cashback,0); 
        assertEq(targetShare,1000); 
        assertEq(newOne.balanceOf(address(mp)), 26e18);
    }

    function test_BurnValue() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        vm.prank(owner);
        mp.transfer(address(mp), 1000000005587935455499);
        OraclePrice memory op;

        mp.swap{value: uint128(toX96(0.1e18))}(op, address(mp), address(tokens[0]), 1e21, true, user0, address(0), true);

        snapMultipool("BurnValue");
    }

    function test_BurnWhenDeviationExceedsAccuracy() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        OraclePrice memory op;

        // removing token 0
        changeShare(address(tokens[0]), 0);
        snapMultipool("BurnWhenDeviationExceedsAccuracy0");

        vm.prank(owner);
        mp.transfer(address(mp), 100000000000000000010);
        mp.swap{value: uint128(toX96(0.1e18))}(
            op, address(mp), address(tokens[0]), 100000000000000000010, true, user0, address(0), true
        );

        snapMultipool("BurnWhenDeviationExceedsAccuracy1");

        uint balance = mp.balanceOf(owner);
        vm.prank(owner);
        mp.transfer(address(mp), balance);
        mp.swap{value: uint128(toX96(0.1e18))}(
            op, address(mp), address(tokens[0]), 1000000000000000000010, true, user0, address(0), true
        );

        snapMultipool("BurnWhenDeviationExceedsAccuracy2");
    }

    function testRevert_SwapHappyPathWithLowOutput() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        tokens[0].mint(address(mp), 2e18);

        changePrice(address(tokens[2]), toX96(0.000001e18));

        OraclePrice memory op;

        vm.expectRevert();
        mp.swap{value: uint128(toX96(0.1e18))}(
            op, address(tokens[0]), address(tokens[2]), 1e18, true, address(0), address(0), true
        );
    }

    function test_MintFromZeroTargetShareToken() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        OraclePrice memory op;

        changeShare(address(token0), 0);

        vm.prank(owner);
        mp.transfer(address(mp), 400e19);

        mp.swap{value: uint128(toX96(0.1e18))}(op, address(mp), address(token0), 40e18, false, user0, address(0), true);

        tokens[0].mint(address(mp), 1e18);

        vm.expectRevert(abi.encodeWithSignature("TargetShareIsZero()"));
        mp.swap{value: uint128(toX96(0.1e18))}(op, address(token0), address(mp), 1e18, false, user0, address(0), true);
    }

    function test_CheckRefundFee() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        OraclePrice memory op;

        vm.prank(user0);
        tokens[0].transfer(address(mp), 100e18);

        assertEq(tokens[0].balanceOf(user0), 0);

        mp.swap{value: 0.2e18}(op, address(token0), address(token1), 1e18, true, user0, user0, true);

        assertEq(tokens[0].balanceOf(user0), 99e18);

        vm.prank(owner);
        mp.transfer(address(mp), 100e18);

        assertEq(mp.balanceOf(user1), 0);

        mp.swap{value: 0.2e18}(op, address(mp), address(token0), 1e18, true, user0, user1, true);

        assertEq(mp.balanceOf(user1), 99e18);
    }
}
