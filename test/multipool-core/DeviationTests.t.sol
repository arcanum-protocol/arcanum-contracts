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

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

    function test_MintFromAllAssetsWithEqualProportions() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18], users[3]);

        Multipool.AssetArg[] memory args = new Multipool.AssetArg[](6);

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
            args[i] = Multipool.AssetArg({addr: address(tokens[i]), amount: int(val)});
        }

        args[5] = Multipool.AssetArg({addr: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))});

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

        SharePriceParams memory sp;
        swap(
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(val)}),
                        Multipool.AssetArg({addr: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))})
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
                    Multipool.AssetArg({addr: address(tokens[0]), amount: int(0.5e18)}),
                    Multipool.AssetArg({addr: address(tokens[0]), amount: int(0.5e18)}),
                    Multipool.AssetArg({addr: address(tokens[1]), amount: int(0.5e18)}),
                    Multipool.AssetArg({addr: address(tokens[2]), amount: int(-1e18)}),
                    Multipool.AssetArg({addr: address(tokens[2]), amount: int(-1e18)}),
                    Multipool.AssetArg({addr: address(tokens[3]), amount: int(-4e18)})
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
                        Multipool.AssetArg({addr: address(tokens[0]), amount: int(1e18)}),
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(0.5e18)}),
                        Multipool.AssetArg({addr: address(tokens[2]), amount: int(-2e18)}),
                        Multipool.AssetArg({addr: address(tokens[3]), amount: int(-4e18)})
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
            sp
        );
        snapMultipool("SwapHappyPath2");

        // // bootstrap new
    }
}
