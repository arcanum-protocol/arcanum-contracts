// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

    function test_SimpleSwap() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );

        vm.prank(user0);
        tokens[1].transfer(address(mp), 2e6);

        snapMultipool("SimpleSwap1");
        swap(user0, token1, token0, true, 1e6);
        swap(user0, token1, token0, true, 1e6);
        snapMultipool("SimpleSwap2");
    }
}
