// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, toX16RatioTick, toX16, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

contract MultipoolSwapEstimate is Test, MultipoolUtils {
    receive() external payable {}

    function test_CheckEstimatesZeroBalances() public {
        vm.startPrank(owner);
        mp.toggleStrategyManager(owner);
        updatePrice(address(mp), address(mp), abi.encode(FeedType.FixedValue, uint128(toX96(0.1e18))));
        uint[] memory p = new uint[](5);
        p[0] = toX96(0.01e18);
        p[1] = toX96(0.02e18);
        p[2] = toX96(0.03e18);
        p[3] = toX96(0.04e18);
        p[4] = toX96(0.05e18);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        uint16[] memory s = new uint16[](5);
        s[0] = 1000;
        s[1] = 1000;
        s[2] = 1000;
        s[3] = 1000;
        s[4] = 1000;

        mp.updateTargetShares(t, s);

        for (uint i = 0; i < t.length; i++) {
            updatePrice(address(mp), address(tokens[i]), abi.encode(FeedType.FixedValue, uint128(p[i])));
        }
        setCurveParams(toX16RatioTick(0.15e5), toX16RatioTick(0.0003e5), toX16RatioTick(0.01e5), toX16RatioTick(0.6e5));
        vm.stopPrank();

        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / p[1];

        SharePriceParams memory sp;
        (int expectedFee, int[] memory amounts) = checkSwap(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true,
            sp
        );

        assertEq(expectedFee, 99999997764825820);
        assertEq(amounts.length, 2);
        assertEq(amounts[1], int(val));
        assertEq(amounts[0], -int(100e18 + 990));

        (expectedFee, amounts) = checkSwap(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(mp), amount: -int(100e18 + 990)})
                    ]
                )
            ),
            false,
            sp
        );

        assertEq(expectedFee, 99999997764825820 + 1);
        assertEq(amounts.length, 2);
        assertEq(amounts[1], int(val + 29900));
        assertEq(amounts[0], -int(100e18 + 990));
    }

    function test_CheckEstimatesForwardWithMint() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        uint price = toX96(10e18);
        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / price;

        tokens[0].mint(address(mp), val);

        SharePriceParams memory sp;
        (int expectedFee, int[] memory amounts) = checkSwap(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(val)}),
                        AssetArgs({assetAddress: address(mp), amount: -1e18})
                    ]
                )
            ),
            true,
            sp
        );

        assertEq(expectedFee, 111465793663798917);
        assertEq(amounts.length, 2);
        assertEq(amounts[1], int(val));
        assertEq(amounts[0], -int(100e18 + 1000));

        (expectedFee, amounts) = checkSwap(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1)}),
                        AssetArgs({
                            assetAddress: address(mp),
                            amount: -int((quoteSum << 96) / toX96(0.1e18))
                        })
                    ]
                )
            ),
            false,
            sp
        );

        assertEq(expectedFee, 111465793663798917);
        assertEq(amounts.length, 2);
        assertEq(amounts[1], int(val) - 1);
        assertEq(amounts[0], -int(100e18));

        swap(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(val)}),
                        AssetArgs({
                            assetAddress: address(mp),
                            amount: -int((quoteSum << 96) / toX96(0.1e18))
                        })
                    ]
                )
            ),
            111465793663798917,
            users[0],
            sp
        );

        snapMultipool("CheckEstimatesForwardWithMint");
    }

    //check estimates with 3 tokens
}
