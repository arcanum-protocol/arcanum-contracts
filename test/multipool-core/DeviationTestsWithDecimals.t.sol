pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";

contract MultipoolDeviationTestsWithDecimals is Test {
    Multipool mp;
    MockERC20[] tokens;
    address[] users;
    uint tokenNum;
    uint userNum;

    function setUp() public {
        tokenNum = 3;
        userNum = 4;

        mp = new Multipool('Name', 'SYMBOL');
        for (uint i; i < tokenNum; i++) {
            tokens.push(new MockERC20('token', 'token', 0));
        }
        for (uint i; i < userNum; i++) {
            users.push(makeAddr(string(abi.encode(i))));
        }
        for (uint u; u < userNum; u++) {
            for (uint t; t < tokenNum; t++) {
                tokens[t].mint(users[u], 10000000000e18);
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

    /// mint of 2 wei was requiring 0 tokens what in most cases is economically useless but
    /// better to restrict
    function test_MintWithSuperSmallShareCantProceedWithoutGettingTokens() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        vm.startPrank(users[0]);
        vm.expectRevert("MULTIPOOL: ZS");
        mp.mint(address(tokens[0]), 2, users[0]);
    }

    function test_Mint_LowerThanTarget_DeviationInRange_NoCashback() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 8e6);
        (uint amount, uint refund) = mp.mint(address(tokens[0]), 2e18, users[0]);

        MpAsset memory asset = mp.getAsset(address(tokens[0]));

        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 - 0.8008e6);
        assertEq(refund, 0);
        assertEq(amount, 0.8008e18);
        assertEq(asset.collectedCashbacks, 0);
        assertEq(asset.collectedFees, 0.0008e18);
        assertEq(mp.balanceOf(users[0]), 2e18);
    }

    function test_Mint_HighterThanTarget_DeviationInRange_NoCashback() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        vm.startPrank(users[0]);
        tokens[1].transfer(address(mp), 1e24);
        (uint amount, uint refund) = mp.mint(address(tokens[1]), 2e18, users[0]);

        MpAsset memory asset = mp.getAsset(address(tokens[1]));

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.4004e24 - 470588235294117 * 1e6);
        assertEq(refund, 0);
        assertEq(amount, 0.4004e18 + 470588235294117);
        assertEq(asset.collectedCashbacks, uint(470588235294117) * 2 / 5 + 1);
        assertEq(asset.collectedFees, uint(470588235294117) * 3 / 5 + 0.0004e18);
        assertEq(mp.balanceOf(users[0]), 2e18);
    }

    function test_Mint_LowerThanTarget_DeviationOutOfRange_NoCashback() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 1e6);
        (uint amount, uint refund) = mp.mint(address(tokens[0]), 2e18, users[0]);

        MpAsset memory asset = mp.getAsset(address(tokens[0]));

        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 - 0.1001e6);
        assertEq(refund, 0);
        assertEq(amount, 0.1001e18);
        assertEq(asset.collectedCashbacks, 0);
        assertEq(asset.collectedFees, 0.0001e18);
        assertEq(mp.balanceOf(users[0]), 2e18);
    }

    function test_Mint_HighterThanTarget_DeviationOutOfRange_NoCashback() public {
        bootstrapTokens([uint(300e18), 600e18, 100e18]);

        vm.startPrank(users[0]);
        assertEq(tokens[1].balanceOf(address(mp)), 30e24);
        tokens[1].transfer(address(mp), 1000e24);
        vm.expectRevert("MULTIPOOL: DO");
        (uint amount, uint refund) = mp.mint(address(tokens[1]), 2e18, users[0]);

        MpAsset memory asset = mp.getAsset(address(tokens[1]));

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 1000e24);
        assertEq(tokens[1].balanceOf(address(mp)), 1030e24);
        assertEq(asset.collectedCashbacks, 0);
        assertEq(asset.collectedFees, 0);
        assertEq(mp.balanceOf(users[0]), 0);
    }

    function test_Burn_LowerThanTarget_DeviationInRange_NoCashback() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        vm.startPrank(users[3]);
        mp.transfer(address(mp), 2e18);
        changePrank(users[0]);
        (uint amount, uint refund) = mp.burn(address(tokens[0]), 2e18, users[0]);

        MpAsset memory asset = mp.getAsset(address(tokens[0]));

        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 724215971548658261 / uint(1e12));
        assertEq(refund, 0);
        assertEq(amount, 724215971548658261);
        assertEq(asset.collectedCashbacks, 1344972518590366);
        assertEq(asset.collectedFees, 74439055932751373);
        assertEq(mp.balanceOf(users[0]), 0);
        assertEq(mp.balanceOf(address(mp)), 0);
    }

    function test_Burn_HighterThanTarget_DeviationInRange_NoCashback() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        MpAsset memory assetBefore = mp.getAsset(address(tokens[1]));
        uint tokenBalanceBefore = tokens[1].balanceOf(users[0]);
        vm.startPrank(users[3]);
        mp.transfer(address(mp), 2e18);
        changePrank(users[0]);
        (uint amount, uint refund) = mp.burn(address(tokens[1]), 2e18, users[0]);

        MpAsset memory asset = mp.getAsset(address(tokens[1]));

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 + 0.363636363636363636e24);
        assertEq(refund, 0);
        assertEq(amount, 0.363636363636363636e18);
        assertEq(asset.collectedFees, 0.036363636363636363e18);
        assertEq(asset.collectedCashbacks, 0);
        assertEq(mp.balanceOf(users[0]), 0);
        assertEq(tokens[1].balanceOf(users[0]) - tokenBalanceBefore, 0.363636363636363636e24);
        assertEq(assetBefore.quantity - asset.quantity, 0.4e18);
    }

    function test_Burn_LowerThanTarget_DeviationOutOfRange_NoCashback() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[3]);
        mp.transfer(address(mp), 2e18);
        changePrank(users[0]);
        vm.expectRevert("MULTIPOOL: DO");
        (uint amount, uint refund) = mp.burn(address(tokens[0]), 2e18, users[0]);
    }

    function test_Burn_HighterThanTarget_DeviationOutOfRange_NoCashback() public {
        bootstrapTokens([uint(300e18), 600e18, 100e18]);

        MpAsset memory assetBefore = mp.getAsset(address(tokens[1]));
        uint tokenBalanceBefore = tokens[1].balanceOf(users[0]);
        vm.startPrank(users[3]);
        mp.transfer(address(mp), 2e18);
        changePrank(users[0]);
        (uint amount, uint refund) = mp.burn(address(tokens[1]), 2e18, users[0]);

        MpAsset memory asset = mp.getAsset(address(tokens[1]));

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 + 0.272727272727272726e24);
        assertEq(tokens[1].balanceOf(address(mp)), 29.727272727272727274e24);
        assertEq(asset.collectedCashbacks, 0);
        assertEq(asset.collectedFees, 0.027272727272727272e18);
        assertEq(mp.balanceOf(users[0]), 0);
        assertEq(tokens[1].balanceOf(users[0]) - tokenBalanceBefore, 0.272727272727272726e24);
        assertEq(assetBefore.quantity - asset.quantity, 0.299999999999999999e18);
    }

    function test_Swap_Increase_Increase_Cashback() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        MpAsset memory assetInBefore = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOutBefore = mp.getAsset(address(tokens[0]));
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);
        tokens[1].transfer(address(mp), 2e24);
        (uint amountIn, uint amountOut, uint refundIn, uint refundOut) =
            mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

        MpAsset memory assetIn = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOut = mp.getAsset(address(tokens[0]));

        assertEq(mp.balanceOf(users[0]), 0);

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.404470588235294117e24);
        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 0.788066e6);

        assertEq(tokens[1].balanceOf(address(mp)), 15.404470588235294117e24);
        assertEq(tokens[0].balanceOf(address(mp)), 39.211933e6 + 1);

        assertEq(assetIn.collectedCashbacks, 0.000188235294117647e18);
        assertEq(assetIn.collectedFees, 0.00428235294117647e18);
        assertEq(assetOut.collectedCashbacks, 0.001621165212496482e18);
        assertEq(assetOut.collectedFees, 0.010312412046158176e18);

        assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.404470588235294117e24);
        assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 0.788066e6);

        assertEq(assetIn.quantity - assetInBefore.quantity, 0.4e18);
        assertEq(assetOutBefore.quantity - assetOut.quantity, 0.8e18);
    }

    function test_Swap_Increase_Decrease_Cashback() public {
        bootstrapTokens([uint(600e18), 300e18, 100e18]);

        MpAsset memory assetInBefore = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOutBefore = mp.getAsset(address(tokens[0]));
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);
        tokens[1].transfer(address(mp), 2e24);
        (uint amountIn, uint amountOut, uint refundIn, uint refundOut) =
            mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

        MpAsset memory assetIn = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOut = mp.getAsset(address(tokens[0]));

        assertEq(mp.balanceOf(users[0]), 0);

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.606762931034482756e24);
        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 1.188118e6);

        assertEq(tokens[1].balanceOf(address(mp)), 15.606762931034482756e24);
        assertEq(tokens[0].balanceOf(address(mp)), 58.811881e6 + 1);

        assertEq(assetIn.collectedCashbacks, 0.000305172413793104e18);
        assertEq(assetIn.collectedFees, 0.006457758620689653e18);
        assertEq(assetOut.collectedCashbacks, 0);
        assertEq(assetOut.collectedFees, 0.011881188118811881e18);

        assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.606762931034482756e24);
        assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 1.188118e6);

        assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
        assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);
    }

    function test_Swap_Decrease_Increase_Cashback() public {
        bootstrapTokens([uint(400e18), 200e18, 400e18]);

        MpAsset memory assetInBefore = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOutBefore = mp.getAsset(address(tokens[0]));
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);
        tokens[1].transfer(address(mp), 2e24);
        (uint amountIn, uint amountOut, uint refundIn, uint refundOut) =
            mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

        MpAsset memory assetIn = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOut = mp.getAsset(address(tokens[0]));

        assertEq(mp.balanceOf(users[0]), 0);

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.404e24);
        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 0.788066e6);

        assertEq(tokens[1].balanceOf(address(mp)), 10.404e24);
        assertEq(tokens[0].balanceOf(address(mp)), 39.211933e6 + 1);

        assertEq(assetIn.collectedCashbacks, 0);
        assertEq(assetIn.collectedFees, 0.004e18);
        assertEq(assetOut.collectedCashbacks, 0.001621165212496482e18);
        assertEq(assetOut.collectedFees, 0.010312412046158176e18);

        assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.404e24);
        assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 0.788066e6);

        assertEq(assetIn.quantity - assetInBefore.quantity, 0.4e18);
        assertEq(assetOutBefore.quantity - assetOut.quantity, 0.8e18);
    }

    function test_Swap_Decrease_Decrease_Cashback() public {
        bootstrapTokens([uint(600e18), 200e18, 200e18]);

        MpAsset memory assetInBefore = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOutBefore = mp.getAsset(address(tokens[0]));
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);
        tokens[1].transfer(address(mp), 2e24);
        (uint amountIn, uint amountOut, uint refundIn, uint refundOut) =
            mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

        MpAsset memory assetIn = mp.getAsset(address(tokens[1]));
        MpAsset memory assetOut = mp.getAsset(address(tokens[0]));

        assertEq(mp.balanceOf(users[0]), 0);

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.605999999999999998e24);
        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 1.188118e6);

        assertEq(tokens[1].balanceOf(address(mp)), 10.605999999999999997e24);
        assertEq(tokens[0].balanceOf(address(mp)), 58.811881e6 + 1);

        assertEq(assetIn.collectedCashbacks, 0);
        assertEq(assetIn.collectedFees, 0.005999999999999999e18);
        assertEq(assetOut.collectedCashbacks, 0);
        assertEq(assetOut.collectedFees, 0.011881188118811881e18);

        assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.605999999999999998e24);
        assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 1.188118e6);

        assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
        assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);
    }
}
