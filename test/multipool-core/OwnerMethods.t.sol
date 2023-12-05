// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic} from "../MultipoolUtils.t.sol";

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(val)}),
                        Multipool.AssetArg({
                            addr: address(mp),
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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: -int(10000)}),
                        Multipool.AssetArg({
                            addr: address(mp),
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
            abi.encode(0)
        );

        snapMultipool("MakeDeviationAndCollectFeesThenAddCashbackAndCollectIt4");
    }
}
