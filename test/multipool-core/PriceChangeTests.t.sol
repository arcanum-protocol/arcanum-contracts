// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, toX16RatioTick, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";
import {ReceiverData} from "../../src/types/ReceiverData.sol";

contract MultipoolPriceChangeTest is Test, MultipoolUtils {
    receive() external payable {}

    function test_FeedExceed() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        tokens[0].mint(address(mp), 1e18);
        OraclePrice memory op;
        ReceiverData memory rd;
        rd.receiverAddress = user0;
        rd.refundAddress = address(0);
        rd.refundEthToReceiver = true;
        vm.expectRevert(abi.encodeWithSignature("FeeExceeded()"));
        mp.swap{value: 0}(op, token0, token1, 1e18, true, rd);
    }

    function test_CheckPriceGetters() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        assertEq(mp.getPrice(token0), toX96(10e18));
        assertEq(mp.getPrice(token3), toX96(12.5e18));

        vm.expectRevert(); // not an owner
        mp.updateOracleAddress(address(0));
        
        vm.prank(owner);
        mp.updateOracleAddress(address(0));
    }


    function test_NoPrice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidTargetShareAuthority()"));
        mp.updateTargetShares(vec([token0, token1, token2, token3, token4]), vec([1000, 1000, 1000, 1000, 1000]));

        vm.prank(owner);
        mp.updateTargetShares(vec([token0, token1, token2, token3, token4]), vec([1000, 1000, 1000, 1000, 1000]));
        
        tokens[0].mint(address(mp), 1e18);
        OraclePrice memory op;

        ReceiverData memory rd;
        rd.receiverAddress = user0;
        rd.refundAddress = address(0);
        rd.refundEthToReceiver = true;

        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.swap{value: 0}(op, token0, address(mp), 1e18, true, rd);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18))));
        
        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.swap{value: 0}(op, token0, address(mp), 1e18, true, rd);

        vm.prank(owner);
        updatePrice(address(mp), address(token0), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18))));

        mp.swap{value: 0}(op, token0, address(mp), 1e18, true, rd);

        tokens[1].mint(address(mp), 1e18);

        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.swap{value: 0}(op, token1, address(mp), 1e18, true, rd);

    }

    function test_AssetPriceGrow() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 400e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), abi.encodePacked(FeedType.FixedValue, uint128(toX96(40e18))));

        tokens[0].mint(address(mp), 100e18);

        // vm.prank(owner);
        // mp.setFeeParams(
        //     toX16RatioTick(0.0003e5), 
        //     toX16RatioTick(0.01e5), 
        //     toX16RatioTick(0.6e5), 
        //     toX16RatioTick(0.01e5), 
        //     owner,
        //     toX16RatioTick(0.1e5)
        // );

        OraclePrice memory op;
        ReceiverData memory rd;
        rd.receiverAddress = user0;
        rd.refundAddress = address(0);
        rd.refundEthToReceiver = true;

        vm.expectRevert(abi.encodeWithSignature("DeviationExceedsLimit()"));
        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        uint256 snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(
            address(mp), address(tokens[0]), abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18 + 1000)))
        );
        vm.prank(owner);
        mp.setFeeParams(
            toX16RatioTick(0.15e5), 
            toX16RatioTick(1e5), 
            toX16RatioTick(0.6e5), 
            toX16RatioTick(0.01e5), 
            owner,
            toX16RatioTick(0.1e5)
        );

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        snapMultipool("AssetPriceGrow1");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), abi.encodePacked(FeedType.FixedValue, uint128(toX96(15e18))));
        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.11e18))));

        console.log("asadsaddsa");
        mp.swap{value: 100e18}(op, token0, token1, 0.5e18, true, rd);

        snapMultipool("AssetPriceGrow2");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();
        
        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), abi.encodePacked(FeedType.FixedValue, uint128(toX96(5e18))));

        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.09e18))));

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        snapMultipool("AssetPriceGrow3");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18))));

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        snapMultipool("AssetPriceGrow4");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(
            address(mp), address(tokens[2]), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.01e18)))
        );

        vm.expectRevert(abi.encodeWithSignature("DeviationExceedsLimit()"));
        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

    }

    function test_SharePriceChange() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 400e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

        uint256 snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(1e18))));

        OraclePrice memory op;

        ReceiverData memory rd;
        rd.receiverAddress = user0;
        rd.refundAddress = address(0);
        rd.refundEthToReceiver = true;

        vm.expectRevert(abi.encodeWithSignature("DeviationExceedsLimit()"));
        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.001e18))));

        vm.expectRevert(abi.encodeWithSignature("DeviationExceedsLimit()"));
        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.11e18))));

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        snapMultipool("SharePriceChange1");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.09e18))));

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, rd);

        snapMultipool("SharePriceChange2");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.09e18))));

        op = genOraclePrice(ownerPk, owner, 1704739268, toX96(5e18));
        
        mp.swap{value: 1e18}(op, token0, token1, 0.005e10, true, rd);

        snapMultipool("SharePriceChange3");

        vm.prank(owner);
        oracle.updateParams(owner, 12500);

        op = genOraclePrice(ownerPk, address(mp), 1704739268, toX96(5.1e18));
        tokens[1].mint(address(mp), 1e18);

        vm.prank(owner);
        mp.swap{value: 1e18}(op, token1, token0, 1e10, true, rd);
    }
}
