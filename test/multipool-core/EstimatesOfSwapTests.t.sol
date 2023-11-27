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

        uint newPrice = toX96(10e18);
        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / newPrice;

        changePrice(address(tokens[0]), newPrice);
        tokens[0].mint(address(mp), val);

        SharePriceParams memory sp;
        (int expectedFee, int[] memory amounts) = checkSwap(
            dynamic(
                [
                    Multipool.AssetArg({addr: address(tokens[0]), amount: int(val)}),
                    Multipool.AssetArg({addr: address(mp), amount: -1e18})
                ]
            ),
            false,
            sp
        );

        assertEq(expectedFee, 211999993285785121);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], int(val));
        assertEq(amounts[1], -int(100e18 + 1000));
        
        swap(
            dynamic(
                [
                    Multipool.AssetArg({addr: address(tokens[0]), amount: int(val)}),
                    Multipool.AssetArg({addr: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))})
                ]
            ),
            100e18,
            users[0],
            sp
        );

        snapMultipool("CheckEstimatesForwardWithMint");
    }
}
