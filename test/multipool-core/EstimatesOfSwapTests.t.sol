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

    function testFail_CheckForcePushSignatureFailsWithInvalidTTL() public {
        vm.startPrank(owner);
        mp.toggleTargetShareAuthority(owner);
        mp.toggleForcePushAuthority(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        mp.updatePrice(address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
        mp.setSharePriceTTL(60);
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

        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(t, s);

        for (uint i = 0; i < t.length; i++) {
            mp.updatePrice(address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
        }
        mp.setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.6e18), toX32(0.01e18));
        vm.stopPrank();

        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / p[1];

        vm.warp(1701391851);
        console.log(address(mp));
        Multipool.FPSharePriceArg memory fp;
        fp.thisAddress = address(mp);
        fp.timestamp = 1701391951;
        fp.value = 7922816251426433759354395033;
        fp.signature = hex"0bed8a506cb35434040c7aa374cc8ab587d4f5959d8af4f62e5dbf9e5156857e4d90bac66ebd29bc8016987538831a593797d55c54ed57e6762e594466ca360d1b"
        ;

        (int expectedFee, int[] memory amounts) = mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(val)}),
                        Multipool.AssetArg({addr: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );

        assertEq(expectedFee, 99999997764825820);
        assertEq(amounts.length, 2);
        assertEq(amounts[1], int(val));
        assertEq(amounts[0], -int(100e18 + 990));
    }

    function test_CheckForcePushSignatureWorks() public {
        vm.startPrank(owner);
        mp.toggleTargetShareAuthority(owner);
        mp.toggleForcePushAuthority(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        mp.updatePrice(address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
        mp.setSharePriceTTL(60);
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

        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(t, s);

        for (uint i = 0; i < t.length; i++) {
            mp.updatePrice(address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
        }
        mp.setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.6e18), toX32(0.01e18));
        vm.stopPrank();

        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / p[1];

        vm.warp(1701391951);
        console.log(address(mp));
        Multipool.FPSharePriceArg memory fp;
        fp.thisAddress = address(mp);
        fp.timestamp = 1701391951;
        fp.value = 7922816251426433759354395033;
        fp.signature = hex"0bed8a506cb35434040c7aa374cc8ab587d4f5959d8af4f62e5dbf9e5156857e4d90bac66ebd29bc8016987538831a593797d55c54ed57e6762e594466ca360d1b"
        ;

        (int expectedFee, int[] memory amounts) = mp.checkSwap(
            fp,
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(val)}),
                        Multipool.AssetArg({addr: address(mp), amount: -1e18})
                    ]
                )
            ),
            true
        );

        assertEq(expectedFee, 99999997764825820);
        assertEq(amounts.length, 2);
        assertEq(amounts[1], int(val));
        assertEq(amounts[0], -int(100e18 + 990));
    }

    function test_CheckEstimatesZeroBalances() public {
        vm.startPrank(owner);
        mp.toggleTargetShareAuthority(owner);
        mp.updatePrice(address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
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

        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(t, s);

        for (uint i = 0; i < t.length; i++) {
            mp.updatePrice(address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
        }
        mp.setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.6e18), toX32(0.01e18));
        vm.stopPrank();

        uint quoteSum = 10e18;
        uint val = (quoteSum << 96) / p[1];

        SharePriceParams memory sp;
        (int expectedFee, int[] memory amounts) = checkSwap(
            sort(
                dynamic(
                    [
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(val)}),
                        Multipool.AssetArg({addr: address(mp), amount: -1e18})
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
                        Multipool.AssetArg({addr: address(tokens[1]), amount: int(1e18)}),
                        Multipool.AssetArg({addr: address(mp), amount: -int(100e18 + 990)})
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

    //check estimates with 3 tokens
}
