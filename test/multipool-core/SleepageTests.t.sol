// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

//also test refund
contract MultipoolTestSleepageAndRefund is Test, MultipoolUtils {
    receive() external payable {}

    function test_CheckSupplyZero() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        vm.prank(users[1]);
        tokens[0].transfer(address(mp), 100e18);
        vm.prank(users[1]);
        tokens[1].transfer(address(mp), 100e18);

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

        // swap 2 tokens for 2 tokens
        SharePriceParams memory sp;
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(0)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-2e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-4e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
            false,
            abi.encodeWithSignature("ZeroAmountSupplied()")
        );
    }

    function test_MintBurnSleepageAndRefund() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        vm.prank(users[1]);
        tokens[0].transfer(address(mp), 100e18);
        vm.prank(users[1]);
        tokens[1].transfer(address(mp), 100e18);

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

        // swap 2 tokens for 2 tokens
        SharePriceParams memory sp;
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-2e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-4e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("MintBurnSleepageAndRefund1");

        vm.prank(users[3]);
        mp.transfer(address(mp), 17000000000000000000010);
        // burn everything
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(19000000000000000000010)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(-41e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(-15.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-78e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-116e18)}),
                        AssetArgs({assetAddress: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(100000e18)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(-41e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(-15.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-78e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-116e18)}),
                        AssetArgs({assetAddress: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(190010)}),
                        AssetArgs({assetAddress: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            false,
            abi.encodeWithSignature("SleepageExceeded()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(17000000000000000000010)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(-410e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(-150.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-780e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-1160e18)}),
                        AssetArgs({assetAddress: address(tokens[4]), amount: int(-300e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
            false,
            abi.encodeWithSignature("SleepageExceeded()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(17000000000000000000010)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(-41e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(-15.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-78e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-116e18)}),
                        AssetArgs({assetAddress: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            false,
            abi.encode(0)
        );
        snapMultipool("MintBurnSleepageAndRefund2");

        tokens[0].mint(address(mp), 41e18);
        tokens[1].mint(address(mp), 15.5e18);
        tokens[2].mint(address(mp), 78e18);
        tokens[3].mint(address(mp), 116e18);
        tokens[4].mint(address(mp), 30e18);

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(-17000000000000000000011)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(41e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(15.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(78e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(116e18)}),
                        AssetArgs({assetAddress: address(tokens[4]), amount: int(30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
            false,
            abi.encodeWithSignature("SleepageExceeded()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(-17000000000000000001111)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(41e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(15.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(78e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(116e18)}),
                        AssetArgs({assetAddress: address(tokens[4]), amount: int(30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            false,
            abi.encodeWithSignature("SleepageExceeded()")
        );
    }
}
