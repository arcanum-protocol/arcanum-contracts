// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/lib/MpContext.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {
    MultipoolUtils, toX96, toX32, toX16RatioTick, vec, updatePrice
} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";

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
        vm.expectRevert(abi.encodeWithSignature("FeeExceeded()"));
        mp.swap{value: 0}(op, token0, token1, 1e18, true, user0, address(0), true);
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

        (bytes32 fees1, bytes32 fees2, address _managerFeeReceiver, address _lpFeeReceiver, uint supply) = mp.getConfig();
        (,,,uint deviationLimit) = unpackMpFees2(fees2);
        (address o, uint deviationIncreaseFee, uint feeToCashbackRatio, uint baseFee, uint lpFee, uint managementFee) = unpackMpFees1(fees1);


        vm.expectRevert(); // not an owner
        mp.setFeeParams(uint24(deviationIncreaseFee), uint16(deviationLimit), uint24(feeToCashbackRatio), uint24(baseFee), uint24(managementFee), uint24(lpFee), _managerFeeReceiver, _lpFeeReceiver, address(0));

        vm.prank(owner);
        mp.setFeeParams(uint24(deviationIncreaseFee), uint16(deviationLimit), uint24(feeToCashbackRatio), uint24(baseFee), uint24(managementFee), uint24(lpFee), _managerFeeReceiver, _lpFeeReceiver, address(0));
    }

    function test_NoPrice() public {
        address[] memory p = new address[](0);
        bytes32[] memory pd = new bytes32[](0);

        vm.expectRevert();
        mp.updateAssets(
            p,pd,
            vec([token0, token1, token2, token3, token4]), vec([1000, 1000, 1000, 1000, 1000])
        );

        vm.prank(owner);
        mp.updateAssets(
            p,pd,
            vec([token0, token1, token2, token3, token4]), vec([1000, 1000, 1000, 1000, 1000])
        );

        tokens[0].mint(address(mp), 1e18);
        OraclePrice memory op;

        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.swap{value: 0}(op, token0, address(mp), 1e18, true, user0, address(0), true);

        vm.prank(owner);
        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18)))
        );

        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.swap{value: 0}(op, token0, address(mp), 1e18, true, user0, address(0), true);

        vm.prank(owner);
        updatePrice(
            address(mp),
            address(token0),
            abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18)))
        );

        mp.swap{value: 0}(op, token0, address(mp), 1e18, true, user0, address(0), true);

        tokens[1].mint(address(mp), 1e18);

        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.swap{value: 0}(op, token1, address(mp), 1e18, true, user0, address(0), true);
    }

    function test_AssetPriceGrow() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 400e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(10e18), toX96(5e18), toX96(12.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        vm.prank(owner);
        updatePrice(
            address(mp),
            address(tokens[0]),
            abi.encodePacked(FeedType.FixedValue, uint128(toX96(40e18)))
        );

        tokens[0].mint(address(mp), 100e18);

        vm.prank(owner);
        mp.setFeeParams(
            toX16RatioTick(0.15e5),
            toX16RatioTick(1e5),
            toX16RatioTick(0.6e5),
            toX16RatioTick(0.01e5),
            toX16RatioTick(0.01e5),
            toX16RatioTick(0.01e5),
            owner,
            owner,
            owner
        );

        OraclePrice memory op;

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        uint256 snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(
            address(mp),
            address(tokens[0]),
            abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18 + 1000)))
        );
        vm.prank(owner);
        mp.setFeeParams(
            toX16RatioTick(0.15e5),
            toX16RatioTick(1e5),
            toX16RatioTick(0.6e5),
            toX16RatioTick(0.01e5),
            toX16RatioTick(0.01e5),
            toX16RatioTick(0.01e5),
            owner,
            owner,
            owner
        );

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        snapMultipool("AssetPriceGrow1");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(
            address(mp),
            address(tokens[0]),
            abi.encodePacked(FeedType.FixedValue, uint128(toX96(15e18)))
        );

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        snapMultipool("AssetPriceGrow2");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(
            address(mp),
            address(tokens[0]),
            abi.encodePacked(FeedType.FixedValue, uint128(toX96(5e18)))
        );

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        snapMultipool("AssetPriceGrow3");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(
            address(mp),
            address(tokens[0]),
            abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18)))
        );

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        snapMultipool("AssetPriceGrow4");

        vm.revertTo(snapshot);

        // vm.prank(owner);
        // updatePrice(
        //     address(mp),
        //     address(tokens[2]),
        //     abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.01e18)))
        // );

        // vm.expectRevert(abi.encodeWithSignature("DeviationExceedsLimit()"));
        // mp.swap{value: 100e18}(op, token0, token1, 10e18, true, user0, address(0), true);
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
        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(1e18)))
        );

        OraclePrice memory op;

        vm.expectRevert(abi.encodeWithSignature("DeviationExceedsLimit()"));
        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(
            address(mp),
            address(mp),
            abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.001e18)))
        );

        vm.expectRevert(abi.encodeWithSignature("DeviationExceedsLimit()"));
        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.11e18)))
        );

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        snapMultipool("SharePriceChange1");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.09e18)))
        );

        mp.swap{value: 100e18}(op, token0, token1, 1e18, true, user0, address(0), true);

        snapMultipool("SharePriceChange2");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.09e18)))
        );

        op = genOraclePrice(ownerPk, owner, 1704739268, toX96(5e18));

        mp.swap{value: 1e18}(op, token0, token1, 0.005e10, true, user0, address(0), true);

        snapMultipool("SharePriceChange3");

        vm.prank(owner);
        oracle.updateParams(owner, 12500);

        op = genOraclePrice(ownerPk, address(mp), 1704739268, toX96(5.1e18));
        tokens[1].mint(address(mp), 1e18);

        vm.prank(owner);
        mp.swap{value: 1e18}(op, token1, token0, 1e10, true, user0, address(0), true);
    }
}
