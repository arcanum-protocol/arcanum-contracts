//// SPDX-License-Identifier: GPL-3.0
//pragma solidity ^0.8.0;
//
//import "forge-std/Test.sol";
//import {MockERC20} from "../../src/mocks/erc20.sol";
//import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
//import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
//import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
//import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";
//
//contract MultipoolPriceChangeTest is Test, MultipoolUtils {
//    receive() external payable {}
//
//    function testFail_AssetPriceGrow() public {
//        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);
//
//        uint price = toX96(10e18);
//        uint quoteSum = 246.153846e18;
//        uint val = (quoteSum << 96) / price;
//
//        SharePriceParams memory sp;
//        tokens[0].mint(address(mp), val);
//        swap(
//            sort(
//                dynamic(
//                    [
//                        AssetArgs({assetAddress: address(tokens[0]), amount: int(val)}),
//                        AssetArgs({
//                            assetAddress: address(mp),
//                            amount: -int((quoteSum << 96) / toX96(0.1e18))
//                        })
//                    ]
//                )
//            ),
//            10000000000e18,
//            users[0],
//            sp
//        );
//    }
//}
