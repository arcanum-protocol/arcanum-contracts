// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

contract MultipoolPriceChangeTest is Test, MultipoolUtils {
    receive() external payable {}

    function test_FeedExceed() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

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
            0,
            users[0],
            sp,
            users[3],
            true,
            false,
            abi.encodeWithSignature("FeeExceeded()")

        );
    }

    function test_AssetPriceGrow() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);


        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), FeedType.FixedValue, abi.encode(toX96(40e18)));

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

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
            users[3],
            true,
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")

        );

        uint256 snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), FeedType.FixedValue, abi.encode(toX96(10e18+1000)));
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
            users[3],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("AssetPriceGrow1");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), FeedType.FixedValue, abi.encode(toX96(15e18)));
        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.11e18)));

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
            users[3],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("AssetPriceGrow2");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), FeedType.FixedValue, abi.encode(toX96(5e18)));
        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.09e18)));

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-1e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-2e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[3],
            true,
            true,
            abi.encode(0)
        );

        snapMultipool("AssetPriceGrow3");

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[0]), FeedType.FixedValue, abi.encode(toX96(0.1e18)));

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-0.1e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-0.1e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[3],
            true,
            false,
            abi.encode(0)

        );

        snapMultipool("AssetPriceGrow4");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(tokens[2]), FeedType.FixedValue, abi.encode(toX96(0.01e18)));

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-0.1e18)}),
                        AssetArgs({assetAddress: address(tokens[3]), amount: int(-0.1e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[3],
            true,
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")
        );

    }

    function test_SharePriceChange() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

        uint256 snapshot = vm.snapshot();

        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(1e18)));

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
            users[3],
            true,
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")

        );

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.001e18)));

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
            users[3],
            true,
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")
        );

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.11e18)));

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
            users[3],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("SharePriceChange1");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.09e18)));

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
            users[3],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("SharePriceChange2");

        vm.revertTo(snapshot);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.09e18)));

        sp.ts = uint128(block.timestamp);
        sp.value = uint128(toX96(0.1e18));
        sp.send = true;

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
            users[3],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("SharePriceChange3");

    }
}
