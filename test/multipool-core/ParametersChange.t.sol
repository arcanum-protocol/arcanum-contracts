pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";

contract MultipoolCornerCases is Test {
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

    function test_Swap_ChangeParams() public {
        bootstrapTokens([uint(600e18), 200e18, 200e18]);

        MpAsset memory assetInBefore = mp.getAssets(address(tokens[1]));
        MpAsset memory assetOutBefore = mp.getAssets(address(tokens[0]));
        uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
        uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

        vm.startPrank(users[0]);
        tokens[1].transfer(address(mp), 2e18);
        (uint amountIn, uint amountOut, uint refundIn, uint refundOut) =
            mp.swap(address(tokens[1]), address(tokens[0]), 2e18, users[0]);

        MpAsset memory assetIn = mp.getAssets(address(tokens[1]));
        MpAsset memory assetOut = mp.getAssets(address(tokens[0]));

        assertEq(mp.balanceOf(users[0]), 0);

        assertEq(tokens[1].balanceOf(users[0]), 10000000000e18 - 0.605999999999999998e18);
        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + 1.188118811881188117e18);

        assertEq(tokens[1].balanceOf(address(mp)), 10.605999999999999997e18);
        assertEq(tokens[0].balanceOf(address(mp)), 58.811881188118811883e18);

        assertEq(assetIn.collectedCashbacks, 0);
        assertEq(assetIn.collectedFees, 0.005999999999999999e18);
        assertEq(assetOut.collectedCashbacks, 0);
        assertEq(assetOut.collectedFees, 0.011881188118811881e18);

        assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 0.605999999999999998e18);
        assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 1.188118811881188117e18);

        assertEq(assetIn.quantity - assetInBefore.quantity, 0.599999999999999999e18);
        assertEq(assetOutBefore.quantity - assetOut.quantity, 1.199999999999999999e18);

        vm.stopPrank();
        mp.setDeviationLimit(0.30e18); // 30%
        mp.setHalfDeviationFee(0.003e18); // 3%
        mp.setBaseTradeFee(0.1e18); // 10%
        mp.setBaseMintFee(0.00001e18); // 0.001%
        mp.setBaseBurnFee(0.001e18); // 0.1%
        mp.setDepegBaseFee(0.1e18); // 10%

        vm.startPrank(users[0]);
        {
            MpAsset memory assetInBefore = mp.getAssets(address(tokens[1]));
            MpAsset memory assetOutBefore = mp.getAssets(address(tokens[0]));
            uint tokenInBalanceBefore = tokens[1].balanceOf(users[0]);
            uint tokenOutBalanceBefore = tokens[0].balanceOf(users[0]);

            vm.startPrank(users[0]);
            tokens[1].transfer(address(mp), 30e18);
            (uint amountIn, uint amountOut, uint refundIn, uint refundOut) =
                mp.swap(address(tokens[1]), address(tokens[0]), 30e18, users[0]);

            MpAsset memory assetIn = mp.getAssets(address(tokens[1]));
            MpAsset memory assetOut = mp.getAssets(address(tokens[0]));

            assertEq(mp.balanceOf(users[0]), 0);

            assertEq(tokens[1].balanceOf(users[0]), 9999999989.460031128404669266e18);
            assertEq(tokens[0].balanceOf(users[0]), 10000000017.486220849143942775e18);

            assertEq(tokens[1].balanceOf(address(mp)), 20.539968871595330733e18);
            assertEq(tokens[0].balanceOf(address(mp)), 42.513779150856057225e18);

            assertEq(assetIn.collectedCashbacks, 0.030571984435797665e18);
            assertEq(assetIn.collectedFees, 0.909396887159533071e18);
            assertEq(assetOut.collectedCashbacks, 0.064878983109872889e18);
            assertEq(assetOut.collectedFees, 1.648900167746184333e18);

            assertEq(tokenInBalanceBefore - tokens[1].balanceOf(users[0]), 9.933968871595330736e18);
            assertEq(tokens[0].balanceOf(users[0]) - tokenOutBalanceBefore, 16.298102037262754658e18);

            assertEq(assetIn.quantity - assetInBefore.quantity, 8.999999999999999999e18);
            assertEq(assetOutBefore.quantity - assetOut.quantity, 17.999999999999999999e18);
        }
    }
    function test_TokenRemovalWorks() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        address[] memory t = new address[](1);
        t[0] = address(tokens[0]);
        uint[] memory s = new uint[](1);
        s[0] = 0e18;
        mp.updateTargetShares(t, s);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 8e18);
        vm.expectRevert("MULTIPOOL: ZT");
        mp.mint(address(tokens[0]), 2e18, users[0]);

        changePrank(users[3]);
        mp.transfer(address(mp), 10e18);
        changePrank(users[0]);
        (uint amount, uint refund) = mp.burn(address(tokens[0]), 10e18, users[0]);

        MpAsset memory asset = mp.getAssets(address(tokens[0]));

        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + amount - 8e18);
        assertEq(refund, 0);
        assertEq(amount, 3.636363636363636363e18);
        assertEq(asset.collectedCashbacks, 0);
        assertEq(asset.collectedFees, 0.363636363636363636e18);

        changePrank(users[3]);
        mp.transfer(address(mp), 90e18);
        changePrank(users[0]);
        (uint amount2, uint refund2) = mp.burn(address(tokens[0]), 90e18, users[0]);

        asset = mp.getAssets(address(tokens[0]));

        assertEq(tokens[0].balanceOf(users[0]), 10000000000e18 + amount + amount2 - 8e18);
        assertEq(refund2, 0);
        assertEq(amount2, 32.727272727272727272e18);
        assertEq(asset.collectedCashbacks, 0);
        assertEq(asset.collectedFees, 3.636363636363636363e18);
        assertEq(asset.quantity, 0);

        vm.stopPrank();

        mp.withdrawFees(address(tokens[0]), makeAddr("RECEIVER"));
        assertEq(tokens[0].balanceOf(makeAddr("RECEIVER")), 3.636363636363636363e18);
    }
}
