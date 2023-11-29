// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32} from "../MultipoolUtils.t.sol";

contract MultipoolSwapEstimate is Test, MultipoolUtils {
    receive() external payable {}

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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(val)}),
                        Multipool.AssetArg({addr: address(mp), amount: -1e18})
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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(1)}),
                        Multipool.AssetArg({addr: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))})
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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(val)}),
                        Multipool.AssetArg({addr: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))})
                    ]
                )
            ),
            111465793663798917,
            users[0],
            sp
        );

        snapMultipool("CheckEstimatesForwardWithMint");
    }
}
