// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, updatePrice, vec} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";
import {ReceiverData} from "../../src/types/ReceiverData.sol";

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

        ReceiverData memory rd;
        rd.receiverAddress = user0;
        rd.refundAddress = address(0);
        rd.refundEthToReceiver = true;

        mp.swap{value: uint128(toX96(0.1e18))}(
            oraclePrice, address(tokens[0]), address(mp), val, true, rd
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

        rd.receiverAddress = user2;
        rd.refundEthToReceiver = false;
        mp.swap{value: 1e13}(oraclePrice, address(mp), address(tokens[0]), 10000, true, rd);
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

        address[] memory assets = new address[](10);
        uint16[] memory shares = new uint16[](10);

        for (uint160 i = 1; i < 11; ++i) {
            assets[i - 1] = address(i);
            shares[i - 1] = 1;
        }

        vm.prank(owner);
        mp.updateTargetShares(assets, shares);

        vm.prank(owner);
        mp.updateTargetShares(assets, shares);
    }
}
