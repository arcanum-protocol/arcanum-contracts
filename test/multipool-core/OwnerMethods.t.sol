// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/lib/MpContext.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, toX16, updatePrice, vec} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

    function test_MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        uint price = toX96(10e18);
        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / price;

        tokens[0].mint(address(mp), val);
        OraclePrice memory oraclePrice;

        mp.swap{value: uint128(toX96(0.1e18))}(
            oraclePrice, address(tokens[0]), address(mp), val, true, user0, address(0), true
        );
        // swapExt(
        //     sort(
        //         dynamic(
        //             [
        //                 AssetArgs({assetAddress: address(tokens[0]), amount: int(val)}),
        //                 AssetArgs({
        //                     assetAddress: address(mp),
        //                     amount: -int((quoteSum << 96) / toX96(0.1e18))
        //                 })
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

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt1");

        vm.prank(owner);

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt2");

        mp.increaseCashback{value: 1e18}(address(tokens[0]));

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt3");

        mp.increaseCashback{value: 0e18}(address(tokens[0]));

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt3");

        vm.prank(users[0]);
        mp.transfer(address(mp), (quoteSum << 96) / toX96(0.1e18) / 2);

        mp.swap{value: 1e13}(oraclePrice, address(mp), address(tokens[0]), 10000, true, user2, address(0), false);
        // swapExt(
        //     sort(
        //         dynamic(
        //             [
        //                 AssetArgs({assetAddress: address(tokens[0]), amount: -int(10000)}),
        //                 AssetArgs({
        //                     assetAddress: address(mp),
        //                     amount: int((quoteSum << 96) / toX96(0.1e18) / 2)
        //                 })
        //             ]
        //         )
        //     ),
        //     100e18,
        //     users[2],
        //     sp,
        //     users[2],
        //     true,
        //     false,
        //     abi.encode(0)
        // );

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt4");
    }

    function test_CheckGasUsageOnUpdateShares() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        address[] memory priceAssets = new address[](0);
        bytes32[] memory priceData = new bytes32[](0);

        address[] memory assets = new address[](10);
        uint16[] memory shares = new uint16[](10);

        for (uint160 i = 1; i < 11; ++i) {
            assets[i - 1] = address(i);
            shares[i - 1] = 1;
        }

        vm.prank(owner);
        mp.updateAssets(priceAssets, priceData, assets, shares);

        vm.prank(owner);
        mp.updateAssets(priceAssets, priceData, assets, shares);
    }

    function test_SetFees() public {
        vm.prank(owner);
        mp.setFeeParams(
            1e4, 
            toX16(1e5), 
            1e6, 
            1e3, 
            1e5, 
            0, 
            owner, 
            owner, 
            address(oracle)
            );

        (bytes32 mpFees1, bytes32 mpFees2, address managerFeeReceiver, address lpFeeReceiver, uint total) = mp.getConfig();
        (        
            address oracleAddress,
            uint deviationIncreaseFee,
            uint feeToCashbackRatio,
            uint baseFee,
            uint lpFee,
            uint managementFee
        ) = unpackMpFees1(mpFees1);
        (        
            uint collectedLp,
            uint collectedManagement,
            uint totalTargetShares,
            uint deviationLimit
        ) = unpackMpFees2(mpFees2);
        assertEq(oracleAddress, address(oracle));
        // assertEq(deviationIncreaseFee, 1e4);
        // assertEq(feeToCashbackRatio, 1e5);
        assertEq(lpFee, 0);
        assertEq(baseFee, 4294967);
    }
}
