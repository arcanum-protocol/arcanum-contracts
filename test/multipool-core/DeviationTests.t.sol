// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

    function testFail_DeviationOverflowFeeWhenIsCloseToDeviationLimit() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        uint price = toX96(10e18);
        uint quoteSum = 246.153846e18;
        uint val = (quoteSum << 96) / price;

        SharePriceParams memory sp;
        tokens[0].mint(address(mp), val);
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
            10000000000e18,
            users[0],
            sp
        );
    }

    function test_MintFromAllAssetsWithEqualProportions() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        AssetArgs[] memory args = new AssetArgs[](6);

        uint quoteSum;
        uint[] memory p = new uint[](5);
        p[0] = toX96(10e18);
        p[1] = toX96(20e18);
        p[2] = toX96(5e18);
        p[3] = toX96(2.5e18);
        p[4] = toX96(10e18);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        for (uint i = 0; i < t.length; i++) {
            quoteSum += 10e18;
            uint val = (10e18 << 96) / p[i];
            changePrice(address(tokens[i]), p[i]);
            tokens[i].mint(address(mp), val);
            args[i] = AssetArgs({assetAddress: address(tokens[i]), amount: int(val)});
        }

        args[5] =
            AssetArgs({assetAddress: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))});

        SharePriceParams memory sp;
        swap(sort(args), 1e18, users[3], sp);

        snapMultipool("MintFromAllAssetsWithEqualProportions");
    }

    function test_MintFromSignleAssetWithDeviation() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        uint newPrice = toX96(10e18);
        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / newPrice;

        changePrice(address(tokens[0]), newPrice);
        tokens[0].mint(address(mp), val);

        vm.prank(owner);
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.09e18)));

        SharePriceParams memory sp;
        sp.ts = uint128(block.timestamp);
        sp.value = uint128(toX96(0.1e18));
        sp.send = true;

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
            100e18,
            users[0],
            sp
        );

        snapMultipool("MintFromSignleAssetWithDeviation");
    }

    function testFail_SplittingTokens() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

        // swap 2 tokens for 2 tokens
        SharePriceParams memory sp;
        swap(
            dynamic(
                [
                    AssetArgs({assetAddress: address(tokens[0]), amount: int(0.5e18)}),
                    AssetArgs({assetAddress: address(tokens[0]), amount: int(0.5e18)}),
                    AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                    AssetArgs({assetAddress: address(tokens[2]), amount: int(-1e18)}),
                    AssetArgs({assetAddress: address(tokens[2]), amount: int(-1e18)}),
                    AssetArgs({assetAddress: address(tokens[3]), amount: int(-4e18)})
                ]
            ),
            100e18,
            users[0],
            sp
        );
    }

    function test_SwapHappyPath() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        tokens[0].mint(address(mp), 1e18);
        tokens[1].mint(address(mp), 0.5e18);

        // swap 2 tokens for 2 tokens
        SharePriceParams memory sp;
        swap(
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
            sp
        );

        snapMultipool("SwapHappyPath1");

        vm.prank(users[3]);
        mp.transfer(address(mp), 17000000000000000000010);
        // burn everything
        swap(
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
            sp
        );
        snapMultipool("SwapHappyPath2");
    }

    function test_RemoveOldToken() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        changeShare(address(tokens[1]), 0);

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

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[1]), amount: int(-0.1e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-0.1e18)})
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

        snapMultipool("RemoveOldToken");
    }

    function test_AddNewTokenAndTryToBurnWithIt() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        MockERC20 newOne = new MockERC20("NEW", "NEW", 0);

        changeShare(address(newOne), 10e18);

        //uint newPrice = toX96(10e18);
        //uint quoteSum = 10e18;
        //uint val = (quoteSum << 96) / newPrice;

        //changePrice(address(tokens[0]), newPrice);
        tokens[0].mint(address(mp), 1e18);

        SharePriceParams memory sp;
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(newOne), amount: -int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            address(this),
            true,
            false,
            abi.encodeWithSignature("NoPriceOriginSet()")
        );

        uint newPrice = toX96(10e18);
        changePrice(address(newOne), newPrice);

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(newOne), amount: -int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            address(this),
            true,
            false,
            abi.encodePacked("ERC20: transfer amount exceeds balance")
        );

        newOne.mint(address(mp), 1e18);
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(newOne), amount: -int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            address(this),
            true,
            false,
            abi.encodeWithSignature("NotEnoughQuantityToBurn()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(newOne), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: -int(1000)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            address(this),
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("AddNewTokenAndTryToBurnWithIt");
        assertEq(
            mp.getAsset(address(newOne)),
            MpAsset({quantity: 1e18, targetShare: 10e18, collectedCashbacks: 0})
        );
        assertEq(newOne.balanceOf(address(mp)), 1e18);

        newOne.mint(address(mp), 25e18);
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(newOne), amount: int(25e18)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: -int(1000)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            address(this),
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("AddNewTokenAndTryToBurnWithIt2");
        assertEq(
            mp.getAsset(address(newOne)),
            MpAsset({quantity: 26e18, targetShare: 10e18, collectedCashbacks: 0})
        );
        assertEq(newOne.balanceOf(address(mp)), 26e18);
    }

    function test_BurnValue() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        SharePriceParams memory sp;

        vm.prank(users[3]);
        mp.transfer(address(mp), 17000000000000000000010);
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(1000000000000000000000)}),
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(-2e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[3],
            false,
            false,
            abi.encode(0)
        );
        snapMultipool("BurnValue");
    }

    function test_BurnWhenDeviationExceedsAccuracy() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        SharePriceParams memory sp;

        // removing token 0
        changeShare(address(tokens[0]), 0);
        snapMultipool("BurnWhenDeviationExceedsAccuracy0");

        vm.prank(users[3]);
        mp.transfer(address(mp), 17000000000000000000010);
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(mp), amount: int(17000000000000000000010)}),
                        // leave almost nothing there
                        AssetArgs({
                            assetAddress: address(tokens[0]),
                            amount: int(-39.999999999999999e18)
                        })
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[3],
            false,
            false,
            abi.encode(0)
        );
        snapMultipool("BurnWhenDeviationExceedsAccuracy1");

        uint balance = mp.balanceOf(users[3]);
        vm.prank(users[3]);
        mp.transfer(address(mp), balance);
        swapExt(
            sort(
                dynamic(
                    [
                        // sleepage can be actually any big value
                        AssetArgs({assetAddress: address(mp), amount: int(17000000000000000000010)}),
                        // leave almost nothing there
                        AssetArgs({
                            assetAddress: address(tokens[0]),
                            amount: int(-(40e18 - 39.999999999999999e18))
                        })
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[3],
            false,
            false,
            abi.encode(0)
        );
        snapMultipool("BurnWhenDeviationExceedsAccuracy2");
    }

    function testFail_SwapHappyPathWithLowOutput() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        tokens[0].mint(address(mp), 2e18);

        changePrice(address(tokens[2]), toX96(0.000001e18));

        // swap 2 tokens for 2 tokens
        SharePriceParams memory sp;
        swap(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                        AssetArgs({assetAddress: address(tokens[2]), amount: int(-1e7)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp
        );
    }
}
