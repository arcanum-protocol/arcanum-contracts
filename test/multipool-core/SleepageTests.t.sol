// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";

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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(0)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(0.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(-2e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(-4e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(1e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(0.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(-2e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(-4e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
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
                        Multipool.AssetArg({addr: address(mp), amount: int(19000000000000000000010)}),
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(-41e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(-15.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(-78e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(-116e18)}),
                        Multipool.AssetArg({addr: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(mp), amount: int(100000e18)}),
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(-41e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(-15.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(-78e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(-116e18)}),
                        Multipool.AssetArg({addr: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            abi.encodeWithSignature("DeviationExceedsLimit()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(mp), amount: int(190010)}),
                        Multipool.AssetArg({addr: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            abi.encodeWithSignature("SleepageExceeded()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(mp), amount: int(17000000000000000000010)}),
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(-410e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(-150.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(-780e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(-1160e18)}),
                        Multipool.AssetArg({addr: address(tokens[4]), amount: int(-300e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
            abi.encodeWithSignature("SleepageExceeded()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(mp), amount: int(17000000000000000000010)}),
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(-41e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(-15.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(-78e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(-116e18)}),
                        Multipool.AssetArg({addr: address(tokens[4]), amount: int(-30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
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
                        Multipool.AssetArg({addr: address(mp), amount: int(-17000000000000000000011)}),
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(41e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(15.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(78e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(116e18)}),
                        Multipool.AssetArg({addr: address(tokens[4]), amount: int(30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            true,
            abi.encodeWithSignature("SleepageExceeded()")
        );

        swapExt(
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(mp), amount: int(-17000000000000000001111)}),
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(41e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(15.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(78e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(116e18)}),
                        Multipool.AssetArg({addr: address(tokens[4]), amount: int(30e18)})
                    ]
                )
            ),
            100e18,
            users[0],
            sp,
            users[1],
            false,
            abi.encodeWithSignature("SleepageExceeded()")
        );
    }
}
