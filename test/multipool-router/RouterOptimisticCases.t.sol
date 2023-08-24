pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import { MockERC20 } from "../../src/mocks/erc20.sol";
import { Multipool, MpContext, MpAsset } from "../../src/multipool/Multipool.sol";
import { MultipoolRouter } from "../../src/multipool/MultipoolRouter.sol";

contract MultipoolRouterCases is Test {
    Multipool mp;
    MultipoolRouter router;
    MockERC20[] tokens;
    address[] users;
    uint tokenNum;
    uint userNum;

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
       s[0] = 50e18; s[1] = 25e18; s[2] = 25e18;

       uint[] memory p = new uint[](3);
       p[0] = 10e18; p[1] = 20e18; p[2] = 10e18;

        mp.updatePrices(t, p);
        mp.updateTargetShares(t, s);

        tokens[0].mint(address(mp), shares[0] / 10);
        mp.mint(address(tokens[0]), 100e18, users[3]);

        tokens[1].mint(address(mp), shares[1] / 20);
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
        bootstrapTokens([uint(400e18),300e18,300e18]);

        vm.prank(users[3]);
        tokens[0].transfer(address(mp), 100e18);
        uint cashback = mp.increaseCashback(address(tokens[0]));
        assertEq(cashback, 100e18);

        vm.startPrank(users[0]);
        uint snapshot = vm.snapshot();

        {{
            (uint amount, uint refund) = router.mintWithSharesOut(
                address(mp), 
                address(tokens[0]), 
                2e18, 
                0.8008e18,
                users[0],
                0
            );

            MpAsset memory asset = mp.getAssets(address(tokens[0]));
            
            assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 - 0.8008e18);
            assertEq(refund, 0);
            assertEq(amount, 0.8008e18);
            assertEq(asset.collectedCashbacks, 4.761904761904761e18);
            assertEq(asset.collectedFees, 0.0008e18);
            assertEq(mp.balanceOf(users[0]), 2e18);
        }}

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        {{
            (uint shares, uint refund) = router.mintWithAmountIn(
                address(mp), 
                address(tokens[0]), 
                0.8008e18,
                2e18, 
                users[0],
                0
            );

            MpAsset memory asset = mp.getAssets(address(tokens[0]));
            
            assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 - 0.8008e18);
            assertEq(refund, 0);
            assertEq(shares, 2e18);
            assertEq(asset.collectedCashbacks, 4.761904761904761e18);
            assertEq(asset.collectedFees, 0.0008e18);
            assertEq(mp.balanceOf(users[0]), 2e18);
        }}

        vm.revertTo(snapshot);

        {{
            (uint sharesOut, uint fee, uint cashbackIn) = router.estimateMintSharesOut(
                address(mp), 
                address(tokens[0]), 
                0.8008e18
            );

            assertEq(sharesOut, 2e18);
            assertEq(fee, 0.001e18);
            assertEq(cashbackIn, 4.761904761904761e18);
        }}

        {{
            (uint amountIn, uint fee, uint cashbackIn) = router.estimateMintAmountIn(
                address(mp), 
                address(tokens[0]), 
                2e18
            );

            assertEq(amountIn, 0.8008e18);
            assertEq(fee, 0.001e18);
            assertEq(cashbackIn, 4.761904761904761e18);
        }}
    }

    function test_Router_Burn_LowerThanTarget_DeviationInRange_NoCashback() public {
        bootstrapTokens([uint(400e18),300e18,300e18]);

        vm.prank(users[3]);
        mp.transfer(users[0], 2e18);

        vm.prank(users[3]);
        tokens[0].transfer(address(mp), 100e18);
        uint cashback = mp.increaseCashback(address(tokens[0]));
        assertEq(cashback, 100e18);

        vm.startPrank(users[0]);
        mp.approve(address(router), 2e18);
        uint snapshot = vm.snapshot();

        {{
            (uint amount, uint refund) = router.burnWithSharesIn(
                address(mp), 
                address(tokens[0]), 
                2e18, 
                0.724215971548658261e18,
                users[0],
                0
            );

            MpAsset memory asset = mp.getAssets(address(tokens[0]));
            
            assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 724215971548658261);
            assertEq(refund, 0);
            assertEq(amount, 724215971548658261);
            assertEq(asset.collectedCashbacks, 1344972518590366 + 100e18);
            assertEq(asset.collectedFees, 74439055932751373);
            assertEq(mp.balanceOf(users[0]), 0);
            assertEq(mp.balanceOf(address(mp)), 0);
        }}

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        {{
            (uint shares, uint refund) = router.burnWithAmountOut(
                address(mp), 
                address(tokens[0]), 
                0.724215971548658261e18,
                2e18, 
                users[0],
                0
            );

            MpAsset memory asset = mp.getAssets(address(tokens[0]));
            
            assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 724215971548658261);
            assertEq(refund, 0);
            assertEq(shares, 2e18);
            assertEq(asset.collectedCashbacks, 1344972518590366 + 100e18);
            assertEq(asset.collectedFees, 74439055932751373);
            assertEq(mp.balanceOf(users[0]), 0);
            assertEq(mp.balanceOf(address(mp)), 0);
        }}

        vm.revertTo(snapshot);

        {{
            (uint sharesOut, uint fee, uint cashbackIn) = router.estimateBurnSharesIn(
                address(mp), 
                address(tokens[0]), 
                0.724215971548658261e18
            );

            assertEq(sharesOut, 2e18);
            assertEq(fee, 0.104642857142857142e18);
            assertEq(cashbackIn, 0);
        }}

        {{
            (uint amountIn, uint fee, uint cashbackIn) = router.estimateBurnAmountOut(
                address(mp), 
                address(tokens[0]), 
                2e18
            );

            assertEq(amountIn, 0.724215971548658261e18);
            assertEq(fee, 0.104642857142857142e18);
            assertEq(cashbackIn, 0);
        }}
    }

    function test_Router_Swap_Decrease_Decrease_Cashback() public {
        bootstrapTokens([uint(600e18),200e18,200e18]);

        vm.prank(users[3]);
        tokens[1].transfer(address(mp), 100e18);
        uint cashback = mp.increaseCashback(address(tokens[1]));
        assertEq(cashback, 100e18);

        vm.prank(users[3]);
        tokens[0].transfer(address(mp), 100e18);
        cashback = mp.increaseCashback(address(tokens[0]));
        assertEq(cashback, 100e18);

        MpAsset memory assetInBefore = mp.getAssets(address(tokens[1]));
        assertEq(assetInBefore.collectedCashbacks, 100e18);
        MpAsset memory assetOutBefore = mp.getAssets(address(tokens[0]));
        assertEq(assetOutBefore.collectedCashbacks, 100e18);
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);
        uint snapshot = vm.snapshot();

        {{
            (uint amountOut, uint refundIn, uint refundOut) = router.swapWithAmountIn(
                address(mp), 
                address(tokens[1]), 
                address(tokens[0]), 
                0.606e18, 
                1.188118811881188117e18,
                users[0],
                0
            );

            MpAsset memory assetIn = mp.getAssets(address(tokens[1]));
            MpAsset memory assetOut = mp.getAssets(address(tokens[0]));

            assertEq(mp.balanceOf(users[0]), 0);
            assertEq(amountOut, 1.188118811881188117e18);
            assertEq(refundIn, 18.972332015810277620e18);
            assertEq(refundOut, 5.259574468085106133e18);

            // 2 wei accuracy
            assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.605999999999999998e18 + 18.972332015810277620e18);
            assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 1.188118811881188117e18 + 5.259574468085106133e18);

            assertEq(tokens[1].balanceOf(address(mp)), 10.605999999999999997e18 + 81.027667984189722380e18);
            assertEq(tokens[0].balanceOf(address(mp)), 58.811881188118811883e18 + 94.740425531914893867e18);

            assertEq(assetIn.collectedCashbacks, 81.027667984189722380e18);
            assertEq(assetIn.collectedFees, 0.005999999999999999e18);
            assertEq(assetOut.collectedCashbacks, 94.740425531914893867e18);
            assertEq(assetOut.collectedFees, 0.011881188118811881e18);

            assertEq(tokens[1].balanceOf(users[0]) - tokenInBalanceBefore, 18.972332015810277620e18 - 0.605999999999999998e18);
            assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 5.259574468085106133e18 + 1.188118811881188117E18);

            assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
            assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);
        }}

        vm.revertTo(snapshot);
        snapshot = vm.snapshot();

        {{
            (uint amountIn, uint refundIn, uint refundOut) = router.swapWithAmountOut(
                address(mp), 
                address(tokens[1]), 
                address(tokens[0]), 
                1.188118811881188119e18,
                0.606e18, 
                users[0],
                0
            );

            MpAsset memory assetIn = mp.getAssets(address(tokens[1]));
            MpAsset memory assetOut = mp.getAssets(address(tokens[0]));

            assertEq(mp.balanceOf(users[0]), 0);
            assertEq(amountIn, 0.605999999999999998e18);
            assertEq(refundIn, 18.972332015810277620e18);
            assertEq(refundOut, 5.259574468085106133e18);

            // 2 wei accuracy
            assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.605999999999999998e18 + 18.972332015810277620e18);
            assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 1.188118811881188117e18 + 5.259574468085106133e18);

            assertEq(tokens[1].balanceOf(address(mp)), 10.605999999999999997e18 + 81.027667984189722380e18);
            assertEq(tokens[0].balanceOf(address(mp)), 58.811881188118811883e18 + 94.740425531914893867e18);

            assertEq(assetIn.collectedCashbacks, 81.027667984189722380e18);
            assertEq(assetIn.collectedFees, 0.005999999999999999e18);
            assertEq(assetOut.collectedCashbacks, 94.740425531914893867e18);
            assertEq(assetOut.collectedFees, 0.011881188118811881e18);

            assertEq(tokens[1].balanceOf(users[0]) - tokenInBalanceBefore, 18.972332015810277620e18 - 0.605999999999999998e18);
            assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 5.259574468085106133e18 + 1.188118811881188117E18);

            assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
            assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);
        }}

    }

   // function test_Router_Mint_HighterThanTarget_DeviationInRange_NoCashback() public {
   //     bootstrapTokens([uint(400e18),300e18,300e18]);

   //     vm.startPrank(users[0]);
   //     tokens[1].transfer(address(mp), 1e18);
   //     (uint amount, uint refund) = mp.mint(address(tokens[1]), 2e18, users[0]);

   //     MpAsset memory asset = mp.getAssets(address(tokens[1]));
   //     
   //     assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.4004e18 - 470588235294117);
   //     assertEq(refund, 0);
   //     assertEq(amount, 0.4004e18 + 470588235294117);
   //     assertEq(asset.collectedCashbacks, uint(470588235294117) * 2 / 5 + 1);
   //     assertEq(asset.collectedFees, uint(470588235294117) * 3 / 5 + 0.0004e18);
   //     assertEq(mp.balanceOf(users[0]), 2e18);

   // }

   // function test_Router_Mint_LowerThanTarget_DeviationOutOfRange_NoCashback() public {
   //     bootstrapTokens([uint(50e18),475e18,475e18]);

   //     vm.startPrank(users[0]);
   //     tokens[0].transfer(address(mp), 1e18);
   //     (uint amount, uint refund) = mp.mint(address(tokens[0]), 2e18, users[0]);

   //     MpAsset memory asset = mp.getAssets(address(tokens[0]));
   //     
   //     assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 - 0.1001e18);
   //     assertEq(refund, 0);
   //     assertEq(amount, 0.1001e18);
   //     assertEq(asset.collectedCashbacks, 0);
   //     assertEq(asset.collectedFees, 0.0001e18);
   //     assertEq(mp.balanceOf(users[0]), 2e18);

   // }

   // function test_Router_Mint_HighterThanTarget_DeviationOutOfRange_NoCashback() public {
   //     bootstrapTokens([uint(300e18),600e18,100e18]);

   //     vm.startPrank(users[0]);
   //     assertEq(tokens[1].balanceOf(address(mp)), 30e18);
   //     tokens[1].transfer(address(mp), 1000e18);
   //     vm.expectRevert("MULTIPOOL: deviation overflow");
   //     (uint amount, uint refund) = mp.mint(address(tokens[1]), 2e18, users[0]);

   //     MpAsset memory asset = mp.getAssets(address(tokens[1]));
   //     
   //     assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 1000e18);
   //     assertEq(tokens[1].balanceOf(address(mp)), 1030e18);
   //     assertEq(asset.collectedCashbacks, 0);
   //     assertEq(asset.collectedFees, 0);
   //     assertEq(mp.balanceOf(users[0]), 0);

   // }



   // function test_Router_Burn_HighterThanTarget_DeviationInRange_NoCashback() public {
   //     bootstrapTokens([uint(400e18),300e18,300e18]);

   //     MpAsset memory assetBefore = mp.getAssets(address(tokens[1]));
   //     uint tokenBalanceBefore = tokens[1].balanceOf(users[0]);
   //     vm.startPrank(users[3]);
   //     mp.transfer(address(mp), 2e18);
   //     changePrank(users[0]);
   //     (uint amount, uint refund) = mp.burn(address(tokens[1]), 2e18, users[0]);

   //     MpAsset memory asset = mp.getAssets(address(tokens[1]));

   //     assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 + 0.363636363636363636e18);
   //     assertEq(refund, 0);
   //     assertEq(amount, 0.363636363636363636e18);
   //     assertEq(asset.collectedFees, 0.036363636363636363e18);
   //     assertEq(asset.collectedCashbacks, 0);
   //     assertEq(mp.balanceOf(users[0]), 0);
   //     assertEq(tokens[1].balanceOf(users[0]) - tokenBalanceBefore, 0.363636363636363636e18);
   //     assertEq(assetBefore.quantity - asset.quantity, 0.4e18);

   // }

   // function test_Router_Burn_LowerThanTarget_DeviationOutOfRange_NoCashback() public {
   //     bootstrapTokens([uint(50e18),475e18,475e18]);

   //     vm.startPrank(users[3]);
   //     mp.transfer(address(mp), 2e18);
   //     changePrank(users[0]);
   //     vm.expectRevert("MULTIPOOL: deviation overflow");
   //     (uint amount, uint refund) = mp.burn(address(tokens[0]), 2e18, users[0]);
   // }

   // function test_Router_Burn_HighterThanTarget_DeviationOutOfRange_NoCashback() public {
   //     bootstrapTokens([uint(300e18),600e18,100e18]);

   //     MpAsset memory assetBefore = mp.getAssets(address(tokens[1]));
   //     uint tokenBalanceBefore = tokens[1].balanceOf(users[0]);
   //     vm.startPrank(users[3]);
   //     mp.transfer(address(mp), 2e18);
   //     changePrank(users[0]);
   //     (uint amount, uint refund) = mp.burn(address(tokens[1]), 2e18, users[0]);

   //     MpAsset memory asset = mp.getAssets(address(tokens[1]));
   //     
   //     assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 + 0.272727272727272726e18);
   //     assertEq(tokens[1].balanceOf(address(mp)), 29.727272727272727274e18);
   //     assertEq(asset.collectedCashbacks, 0);
   //     assertEq(asset.collectedFees, 0.027272727272727272e18);
   //     assertEq(mp.balanceOf(users[0]), 0);
   //     assertEq(tokens[1].balanceOf(users[0]) - tokenBalanceBefore, 0.272727272727272726e18);
   //     assertEq(assetBefore.quantity - asset.quantity, 0.299999999999999999e18);

   // }

   // function test_Router_Swap_Increase_Increase_Cashback() public {
   //     bootstrapTokens([uint(400e18),300e18,300e18]);

   //     MpAsset memory assetInBefore = mp.getAssets(address(tokens[1]));
   //     MpAsset memory assetOutBefore = mp.getAssets(address(tokens[0]));
   //     uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
   //     uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

   //     vm.startPrank(users[0]);
   //     tokens[1].transfer(address(mp), 2e18);
   //     (
   //         uint amountIn, 
   //         uint amountOut, 
   //         uint refundIn, 
   //         uint refundOut
   //     ) = mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

   //     MpAsset memory assetIn = mp.getAssets(address(tokens[1]));
   //     MpAsset memory assetOut = mp.getAssets(address(tokens[0]));

   //     assertEq(mp.balanceOf(users[0]), 0);

   //     assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.404470588235294117e18);
   //     assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 0.788066422741345342e18);

   //     assertEq(tokens[1].balanceOf(address(mp)), 15.404470588235294117e18);
   //     assertEq(tokens[0].balanceOf(address(mp)), 39.211933577258654658e18);

   //     assertEq(assetIn.collectedCashbacks, 0.000188235294117647e18);
   //     assertEq(assetIn.collectedFees, 0.004282352941176470e18);
   //     assertEq(assetOut.collectedCashbacks, 0.001621165212496482e18);
   //     assertEq(assetOut.collectedFees, 0.010312412046158176e18);

   //     assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.404470588235294117e18);
   //     assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 0.788066422741345342e18);

   //     assertEq(assetIn.quantity - assetInBefore.quantity, 0.4e18);
   //     assertEq(assetOutBefore.quantity - assetOut.quantity, 0.8e18);
   // }

   // function test_Router_Swap_Increase_Decrease_Cashback() public {
   //     bootstrapTokens([uint(600e18),300e18,100e18]);

   //     MpAsset memory assetInBefore = mp.getAssets(address(tokens[1]));
   //     MpAsset memory assetOutBefore = mp.getAssets(address(tokens[0]));
   //     uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
   //     uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

   //     vm.startPrank(users[0]);
   //     tokens[1].transfer(address(mp), 2e18);
   //     (
   //         uint amountIn, 
   //         uint amountOut, 
   //         uint refundIn, 
   //         uint refundOut
   //     ) = mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

   //     MpAsset memory assetIn = mp.getAssets(address(tokens[1]));
   //     MpAsset memory assetOut = mp.getAssets(address(tokens[0]));

   //     assertEq(mp.balanceOf(users[0]), 0);

   //     assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.606762931034482756e18);
   //     assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 1.188118811881188117e18);

   //     assertEq(tokens[1].balanceOf(address(mp)), 15.606762931034482756e18);
   //     assertEq(tokens[0].balanceOf(address(mp)), 58.811881188118811883e18);

   //     assertEq(assetIn.collectedCashbacks, 0.000305172413793104e18);
   //     assertEq(assetIn.collectedFees, 0.006457758620689653e18);
   //     assertEq(assetOut.collectedCashbacks, 0);
   //     assertEq(assetOut.collectedFees, 0.011881188118811881e18);

   //     assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.606762931034482756e18);
   //     assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 1.188118811881188117e18);

   //     assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
   //     assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);
   // }

   // function test_Router_Swap_Decrease_Increase_Cashback() public {
   //     bootstrapTokens([uint(400e18),200e18,400e18]);

   //     MpAsset memory assetInBefore = mp.getAssets(address(tokens[1]));
   //     MpAsset memory assetOutBefore = mp.getAssets(address(tokens[0]));
   //     uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
   //     uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

   //     vm.startPrank(users[0]);
   //     tokens[1].transfer(address(mp), 2e18);
   //     (
   //         uint amountIn, 
   //         uint amountOut, 
   //         uint refundIn, 
   //         uint refundOut
   //     ) = mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

   //     MpAsset memory assetIn = mp.getAssets(address(tokens[1]));
   //     MpAsset memory assetOut = mp.getAssets(address(tokens[0]));

   //     assertEq(mp.balanceOf(users[0]), 0);

   //     assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.404e18);
   //     assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 0.788066422741345342e18);

   //     assertEq(tokens[1].balanceOf(address(mp)), 10.404e18);
   //     assertEq(tokens[0].balanceOf(address(mp)), 39.211933577258654658e18);

   //     assertEq(assetIn.collectedCashbacks, 0);
   //     assertEq(assetIn.collectedFees, 0.004e18);
   //     assertEq(assetOut.collectedCashbacks, 0.001621165212496482e18);
   //     assertEq(assetOut.collectedFees, 0.010312412046158176e18);

   //     assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.404e18);
   //     assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 0.788066422741345342e18);

   //     assertEq(assetIn.quantity - assetInBefore.quantity, 0.4e18);
   //     assertEq(assetOutBefore.quantity - assetOut.quantity, 0.8e18);
   // }


}
