pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../../src/multipool/MultipoolRouter.sol";

contract MultipoolRouterCases is Test {
    Multipool mp;
    MultipoolRouter router;
    MockERC20[] tokens;
    address[] users;
    uint tokenNum;
    uint userNum;

    function checkUsdCap() public {
        uint acc;
        for (uint i = 0; i < tokens.length; i++) {
            acc += mp.getAsset(address(tokens[i])).quantity * mp.getAsset(address(tokens[i])).price / 1e18;
        }
        assertEq(acc, mp.usdCap());
    }

    function setUp() public {
        tokenNum = 3;
        userNum = 4;

        mp = new Multipool('Name', 'SYMBOL');
        router = new MultipoolRouter();
        for (uint i; i < tokenNum; i++) {
            tokens.push(new MockERC20('token', 'token', 0));
        }
        for (uint i; i < userNum; i++) {
            users.push(makeAddr(string(abi.encode(i, "router"))));
        }
        for (uint u; u < userNum; u++) {
            for (uint t; t < tokenNum; t++) {
                tokens[t].mint(users[u], 10000000000e18);
            }
        }
        for (uint i; i < tokenNum; i++) {
            for (uint u; u < userNum; u++) {
                vm.startPrank(users[u]);
                tokens[i].approve(address(router), 10000000000e18);
                vm.stopPrank();
            }
        }
    }

    function bootstrapTokens(uint[3] memory shares) private {
        mp.setDeviationLimit(1e18); // 100%

        address[] memory t = new address[](3);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);

        uint[] memory s = new uint[](3);
        s[0] = 50e18;
        s[1] = 25e18;
        s[2] = 25e18;

        uint[] memory p = new uint[](3);
        p[0] = 10e18;
        p[1] = 20e18;
        p[2] = 10e18;

        mp.updatePrices(t, p);
        mp.updateTargetShares(t, s);

        mp.setTokenDecimals(address(tokens[0]), 6);
        mp.setTokenDecimals(address(tokens[1]), 24);
        mp.setTokenDecimals(address(tokens[2]), 18);

        tokens[0].mint(address(mp), shares[0] / 1e12 / 10);
        mp.mint(address(tokens[0]), 100e18, users[3]);

        tokens[1].mint(address(mp), shares[1] * 1e6 / 20);
        mp.mint(address(tokens[1]), 100e18 * shares[1] / shares[0], users[3]);

        tokens[2].mint(address(mp), shares[2] / 10);
        mp.mint(address(tokens[2]), 100e18 * shares[2] / shares[0], users[3]);

        mp.setDeviationLimit(0.15e18); // 0.15
        mp.setHalfDeviationFee(0.0003e18); // 0.0003
        mp.setBaseTradeFee(0.01e18); // 0.01 1%
        mp.setBaseMintFee(0.001e18); // 0.001 0.1%
        mp.setBaseBurnFee(0.1e18); // 0.1 10%
        mp.setDepegBaseFee(0.6e18);
    }

    function bootstrapTokensFirst24(uint[3] memory shares) private {
        mp.setDeviationLimit(1e18); // 100%

        address[] memory t = new address[](3);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);

        uint[] memory s = new uint[](3);
        s[0] = 50e18;
        s[1] = 25e18;
        s[2] = 25e18;

        uint[] memory p = new uint[](3);
        p[0] = 10e18;
        p[1] = 20e18;
        p[2] = 10e18;

        mp.updatePrices(t, p);
        mp.updateTargetShares(t, s);

        mp.setTokenDecimals(address(tokens[0]), 24);
        mp.setTokenDecimals(address(tokens[1]), 6);
        mp.setTokenDecimals(address(tokens[2]), 18);

        tokens[0].mint(address(mp), shares[0] * 1e6 / 10);
        mp.mint(address(tokens[0]), 100e18, users[3]);

        tokens[1].mint(address(mp), shares[1] / 1e12 / 20);
        mp.mint(address(tokens[1]), 100e18 * shares[1] / shares[0], users[3]);

        tokens[2].mint(address(mp), shares[2] / 10);
        mp.mint(address(tokens[2]), 100e18 * shares[2] / shares[0], users[3]);

        mp.setDeviationLimit(0.15e18); // 0.15
        mp.setHalfDeviationFee(0.0003e18); // 0.0003
        mp.setBaseTradeFee(0.01e18); // 0.01 1%
        mp.setBaseMintFee(0.001e18); // 0.001 0.1%
        mp.setBaseBurnFee(0.1e18); // 0.1 10%
        mp.setDepegBaseFee(0.6e18);
    }

    function test_Router_Mint_LowerThanTarget_DeviationInRange_NoCashback() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        vm.prank(users[3]);
        tokens[0].transfer(address(mp), 100e6);
        uint cashback = mp.increaseCashback(address(tokens[0]));
        assertEq(cashback, 100e18);

        vm.startPrank(users[0]);
        uint snapshot = vm.snapshot();

        {
            {
                (uint amount, uint refund) =
                    router.mintWithSharesOut(address(mp), address(tokens[0]), 2e18, 0.8008e6, users[0]);

                MpAsset memory asset = mp.getAsset(address(tokens[0]));

                assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 - 0.8008e6 + 4.761904761904761e18 / uint(1e12));
                assertEq(refund, 4.761904761904761e18 / uint(1e12));
                assertEq(amount, 0.8008e18 / uint(1e12));
                assertEq(asset.collectedCashbacks, 95.238095238095239e18);
                assertEq(asset.collectedFees, 0.0008e18);
                assertEq(mp.balanceOf(users[0]), 2e18);
                checkUsdCap();
            }
        }

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        {
            {
                (uint shares, uint refund) =
                    router.mintWithAmountIn(address(mp), address(tokens[0]), 0.8008e6, 2e18, users[0]);

                MpAsset memory asset = mp.getAsset(address(tokens[0]));

                assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 - 0.8008e6 + 4.761904761904761e18 / uint(1e12));
                assertEq(refund, 4.761904761904761e18 / uint(1e12));
                assertEq(shares, 2e18);
                assertEq(asset.collectedCashbacks, 95.238095238095239e18);
                assertEq(asset.collectedFees, 0.0008e18);
                assertEq(mp.balanceOf(users[0]), 2e18);
                checkUsdCap();
            }
        }

        vm.revertTo(snapshot);

        {
            {
                (uint sharesOut, uint assetPrice, uint sharePrice, uint cashbackIn) =
                    router.estimateMintSharesOut(address(mp), address(tokens[0]), 0.8008e6);

                assertEq(sharesOut, 2e18);
                assertEq(assetPrice, 10e18);
                assertEq(sharePrice, 4e18);
                assertEq(cashbackIn, 4.761904761904761e18 / uint(1e12));
                checkUsdCap();
            }
        }

        {
            {
                (uint amountIn, uint assetPrice, uint sharePrice, uint cashbackIn) =
                    router.estimateMintAmountIn(address(mp), address(tokens[0]), 2e18);

                assertEq(amountIn, 0.8008e6);
                assertEq(assetPrice, 10e18);
                assertEq(sharePrice, 4e18);
                assertEq(cashbackIn, 4.761904761904761e18 / uint(1e12));
                checkUsdCap();
            }
        }
    }

    function test_Router_Burn_LowerThanTarget_DeviationInRange_Cashback() public {
        bootstrapTokensFirst24([uint(400e18), 300e18, 300e18]);

        vm.prank(users[3]);
        mp.transfer(users[0], 2e18);

        vm.prank(users[3]);
        tokens[0].transfer(address(mp), 100e24);
        uint cashback = mp.increaseCashback(address(tokens[0]));
        assertEq(cashback, 100e18);

        vm.startPrank(users[0]);
        mp.approve(address(router), 2e18);
        uint snapshot = vm.snapshot();

        {
            {
                (uint amount, uint refund) =
                    router.burnWithSharesIn(address(mp), address(tokens[0]), 2e18, 0.724215971548658261e24, users[0]);
                MpAsset memory asset = mp.getAsset(address(tokens[0]));

                assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 724215971548658261 * uint(1e6));
                assertEq(refund, 0);
                assertEq(amount, 724215971548658261 * uint(1e6));
                assertEq(asset.collectedCashbacks, 1344972518590366 + 100e18);
                assertEq(asset.collectedFees, 74439055932751373);
                assertEq(mp.balanceOf(users[0]), 0);
                assertEq(mp.balanceOf(address(mp)), 0);
                checkUsdCap();
            }
        }

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        {
            {
                (uint shares, uint refund) =
                    router.burnWithAmountOut(address(mp), address(tokens[0]), 0.724215971548658261e24, 2e18, users[0]);

                MpAsset memory asset = mp.getAsset(address(tokens[0]));

                assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 724215971548658261 * uint(1e6));
                assertEq(refund, 0);
                assertEq(shares, 2e18);
                assertEq(asset.collectedCashbacks, 1344972518590366 + 100e18);
                assertEq(asset.collectedFees, 74439055932751373);
                assertEq(mp.balanceOf(users[0]), 0);
                assertEq(mp.balanceOf(address(mp)), 0);
                checkUsdCap();
            }
        }

        vm.revertTo(snapshot);

        {
            {
                (uint sharesOut, uint assetPrice, uint sharePrice, uint cashbackIn) =
                    router.estimateBurnSharesIn(address(mp), address(tokens[0]), 0.724215971548658261e24);

                assertEq(sharesOut, 2e18);
                assertEq(assetPrice, 10e18);
                assertEq(sharePrice, 4e18);
                assertEq(cashbackIn, 0);
            }
        }

        {
            {
                (uint amountIn, uint assetPrice, uint sharePrice, uint cashbackIn) =
                    router.estimateBurnAmountOut(address(mp), address(tokens[0]), 2e18);

                assertEq(amountIn, 0.724215971548658261e18 * uint(1e6));
                assertEq(assetPrice, 10e18);
                assertEq(sharePrice, 4e18);
                assertEq(cashbackIn, 0);
            }
        }
    }

    function test_Router_Swap_Decrease_Decrease_Cashback() public {
        bootstrapTokens([uint(600e18), 200e18, 200e18]);

        vm.prank(users[3]);
        tokens[1].transfer(address(mp), 100e24);
        uint cashback = mp.increaseCashback(address(tokens[1]));
        assertEq(cashback, 100e18);

        vm.prank(users[3]);
        tokens[0].transfer(address(mp), 100e6);
        cashback = mp.increaseCashback(address(tokens[0]));
        assertEq(cashback, 100e18);

        MpAsset memory assetInBefore = mp.getAsset(address(tokens[1]));
        assertEq(assetInBefore.collectedCashbacks, 100e18);
        MpAsset memory assetOutBefore = mp.getAsset(address(tokens[0]));
        assertEq(assetOutBefore.collectedCashbacks, 100e18);
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);
        uint snapshot = vm.snapshot();

        {
            {
                (uint amountOut, uint refundIn, uint refundOut) = router.swapWithAmountIn(
                    address(mp),
                    address(tokens[1]),
                    address(tokens[0]),
                    0.606e24,
                    1.188118811881188117e18 / uint(1e12),
                    users[0]
                );

                MpAsset memory assetIn = mp.getAsset(address(tokens[1]));
                MpAsset memory assetOut = mp.getAsset(address(tokens[0]));

                assertEq(mp.balanceOf(users[0]), 0);
                assertEq(amountOut, 1.188118811881188117e18 / uint(1e12));
                assertEq(refundIn, 18.97233201581027762e24);
                assertEq(refundOut, 5.259574468085106133e18 / uint(1e12));

                assertEq(
                    tokens[1].balanceOf(users[0]), 10000000000e18 - 0.605999999999999998e24 + 18.97233201581027762e24
                );
                assertEq(
                    tokens[0].balanceOf(users[0]),
                    10000000000e18 + 1 + 1.188118811881188117e18 / uint(1e12) + 5.259574468085106133e18 / uint(1e12)
                );

                assertEq(tokens[1].balanceOf(address(mp)), 10.605999999999999997e24 + 81.02766798418972238e24);
                assertEq(
                    tokens[0].balanceOf(address(mp)),
                    58.811881188118811883e18 / uint(1e12) + 1 + 94.740425531914893867e18 / uint(1e12)
                );

                assertEq(assetIn.collectedCashbacks, 81.02766798418972238e18);
                assertEq(assetIn.collectedFees, 0.005999999999999999e18);
                assertEq(assetOut.collectedCashbacks, 94.740425531914893867e18);
                assertEq(assetOut.collectedFees, 0.011881188118811881e18);

                assertEq(
                    tokens[1].balanceOf(users[0]) - tokenInBalanceBefore,
                    18.97233201581027762e24 - 0.605999999999999998e24
                );
                assertEq(
                    tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore,
                    5.259574468085106133e18 / uint(1e12) + 1.188118811881188117e18 / uint(1e12) + 1
                );

                assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
                assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);
                checkUsdCap();
            }
        }

        vm.revertTo(snapshot);

        {
            {
                (uint shares, uint amountIn, uint assetInPrice, uint assetOutPrice, uint cashbackIn, uint cashbackOut) =
                router.estimateSwapAmountIn(
                    address(mp), address(tokens[1]), address(tokens[0]), 1.188118811881188119e18 / uint(1e12)
                );

                assertEq(shares, 1.999998633333333333e18);
                assertEq(amountIn, 0.605999585899999998e24);
                assertEq(assetInPrice, 20e18);
                assertEq(assetOutPrice, 10e18);
                assertEq(cashbackIn, 18.97231920511167762e24);
                assertEq(cashbackOut, 5.25957e6);
            }
        }

        {
            {
                (uint shares, uint amountOut, uint assetInPrice, uint assetOutPrice, uint cashbackIn, uint cashbackOut)
                = router.estimateSwapAmountOut(address(mp), address(tokens[1]), address(tokens[0]), 0.606e24);

                assertEq(shares, 2e18);
                assertEq(amountOut, 1.188118811881188117e18 / uint(1e12));
                assertEq(assetInPrice, 20e18);
                assertEq(assetOutPrice, 10e18);
                assertEq(cashbackIn, 18.97233201581027762e24);
                assertEq(cashbackOut, 5.259574468085106133e18 / uint(1e12));
            }
        }
    }

    function test_Router_Swap_Decrease_Decrease_ScndPRt() public {
        bootstrapTokensFirst24([uint(600e18), 200e18, 200e18]);

        MpAsset memory a = mp.getAsset(address(tokens[1]));
        assertEq(a.quantity + a.collectedFees + a.collectedCashbacks, 1e12 * tokens[1].balanceOf(address(mp)) - 1);
        assertEq(a.quantity + a.collectedFees + a.collectedCashbacks, 10e18 - 1);
        vm.prank(users[3]);
        tokens[1].transfer(address(mp), 100e6);
        uint cashback = mp.increaseCashback(address(tokens[1]));
        assertEq(cashback, 100e18 + 1);

        vm.prank(users[3]);
        tokens[0].transfer(address(mp), 100e24);
        cashback = mp.increaseCashback(address(tokens[0]));
        assertEq(cashback, 100e18);

        MpAsset memory assetInBefore = mp.getAsset(address(tokens[1]));
        assertEq(assetInBefore.collectedCashbacks, 100e18 + 1);
        MpAsset memory assetOutBefore = mp.getAsset(address(tokens[0]));
        assertEq(assetOutBefore.collectedCashbacks, 100e18);
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);

        (uint amountIn, uint refundIn, uint refundOut) = router.swapWithAmountOut(
            address(mp),
            address(tokens[1]),
            address(tokens[0]),
            1.188118811881188119e24,
            0.606e18 / uint(1e12),
            users[0]
        );

        MpAsset memory assetIn = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOut = mp.getAsset(address(tokens[0]));

        checkUsdCap();
        assertEq(mp.balanceOf(users[0]), 0);
        assertEq(amountIn, 0.605999999999999998e18 / uint(1e12));
        assertEq(refundIn, 18.97233201581027762e18 / uint(1e12));
        assertEq(refundOut, 5.259574468085106133e24);

        // 2 wei accuracy
        assertEq(
            tokens[1].balanceOf(users[0]),
            10000000000e18 - 1 - 0.605999999999999998e18 / uint(1e12) + 18.97233201581027762e18 / uint(1e12)
        );
        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 1.188118811881188117e24 + 5.259574468085106133e24);

        assertEq(
            tokens[1].balanceOf(address(mp)),
            10.605999999999999997e18 / uint(1e12) + 81.02766798418972238e18 / uint(1e12) + 2
        );
        assertEq(tokens[0].balanceOf(address(mp)), 58.811881188118811883e24 + 94.740425531914893867e24);

        assertEq(assetIn.collectedCashbacks, 81.02766798418972238e18 + 1);
        assertEq(assetIn.collectedFees, 0.005999999999999999e18);
        assertEq(assetOut.collectedCashbacks, 94.740425531914893867e18);
        assertEq(assetOut.collectedFees, 0.011881188118811881e18);

        assertEq(
            tokens[1].balanceOf(users[0]) - tokenInBalanceBefore,
            18.97233201581027762e18 / uint(1e12) - 0.605999999999999998e18 / uint(1e12) - 1
        );
        assertEq(
            tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 5.259574468085106133e24 + 1.188118811881188117e24
        );

        assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
        assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);
        checkUsdCap();
    }
}
