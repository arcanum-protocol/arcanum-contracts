// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

    function test_PauseWorks() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        vm.expectRevert("Ownable: caller is not the owner");
        mp.togglePause();

        vm.expectRevert("Ownable: caller is not the owner");
        mp.withdrawFees(address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        mp.setFeeParams(0, 0, 0, 0, 0, address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        mp.setSharePriceParams(0, 0);

        vm.prank(owner);
        mp.setAuthorityRights(owner, false, false);

        address[] memory a;
        uint[] memory b;

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("InvalidTargetShareAuthority()"));
        mp.updateTargetShares(a, b);

        address[] memory c;
        FeedType[] memory d;
        bytes[] memory e;
        vm.expectRevert("Ownable: caller is not the owner");
        mp.updatePrices(c, d, e);

        vm.expectRevert("Ownable: caller is not the owner");
        mp.setAuthorityRights(address(0), false, false);

        vm.prank(owner);
        mp.togglePause();

        SharePriceParams memory sp;
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: int(0)}),
                        AssetArgs({assetAddress: address(mp), amount: -int((0 << 96) / toX96(0.1e18))})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[3],
            true,
            false,
            abi.encodeWithSignature("IsPaused()")
        );

        vm.expectRevert("Ownable: caller is not the owner");
        mp.upgradeTo(implementation);

        vm.prank(owner);
        mp.upgradeTo(implementation);

        vm.expectRevert(abi.encodeWithSignature("IsPaused()"));
        mp.increaseCashback(address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        mp.withdrawFees(address(0));

        vm.expectRevert(abi.encodeWithSignature("IsPaused()"));
        mp.withdrawDeveloperFees();

        vm.prank(owner);
        mp.transferOwnership(address(this));
        mp.renounceOwnership();

        mp.getSharePriceParams();
        mp.getPriceFeed(address(0));

        mp.getFeeParams();

        vm.expectRevert(abi.encodeWithSignature("NoPriceOriginSet()"));
        mp.getPrice(address(0));

        mp.getAsset(address(0));
    }

    function test_MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        uint price = toX96(10e18);
        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / price;

        tokens[0].mint(address(mp), val);
        SharePriceParams memory sp;
        swapExt(
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
            sp,
            users[3],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt1");

        vm.prank(owner);
        mp.withdrawFees(users[1]);

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt2");

        mp.increaseCashback{value: 1e18}(address(tokens[0]));

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt3");

        mp.increaseCashback{value: 0e18}(address(tokens[0]));

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt3");

        vm.prank(users[0]);
        mp.transfer(address(mp), (quoteSum << 96) / toX96(0.1e18) / 2);
        swapExt(
            sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(tokens[0]), amount: -int(10000)}),
                        AssetArgs({
                            assetAddress: address(mp),
                            amount: int((quoteSum << 96) / toX96(0.1e18) / 2)
                        })
                    ]
                )
            ),
            100e18,
            users[2],
            sp,
            users[2],
            true,
            false,
            abi.encode(0)
        );

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt4");

        mp.withdrawDeveloperFees();

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt5");
    }
}
