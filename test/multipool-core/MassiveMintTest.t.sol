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
        tokenNum = 5;
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

    function bootstrapTokens(uint[5] memory shares) private {
        mp.setDeviationLimit(1e18); // 100%

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        uint[] memory s = new uint[](5);
        s[0] = 50e18;
        s[1] = 25e18;
        s[2] = 25e18;
        s[3] = 25e18;
        s[4] = 25e18;

        uint[] memory p = new uint[](5);
        p[0] = 10e18;
        p[1] = 20e18;
        p[2] = 10e18;
        p[3] = 10e18;
        p[4] = 10e18;

        mp.updatePrices(t, p);
        mp.updateTargetShares(t, s);

        mp.setTokenDecimals(address(tokens[0]), 18);
        mp.setTokenDecimals(address(tokens[1]), 18);
        mp.setTokenDecimals(address(tokens[2]), 18);
        mp.setTokenDecimals(address(tokens[3]), 18);
        mp.setTokenDecimals(address(tokens[4]), 18);

        if (shares[0] / 10 != 0) {
            tokens[0].mint(address(mp), shares[0] / 10);
            mp.mint(address(tokens[0]), 100e18, users[3]);
        }

        if (shares[1] / 20 != 0) {
            tokens[1].mint(address(mp), shares[1] / 20);
            mp.mint(address(tokens[1]), 100e18 * shares[1] / shares[0], users[3]);
        }

        if (shares[2] / 10 != 0) {
            tokens[2].mint(address(mp), shares[2] / 10);
            mp.mint(address(tokens[2]), 100e18 * shares[2] / shares[0], users[3]);
        }

        if (shares[3] / 10 != 0) {
            tokens[3].mint(address(mp), shares[3] / 10);
            mp.mint(address(tokens[3]), 100e18 * shares[3] / shares[0], users[3]);
        }

        if (shares[4] / 10 != 0) {
            tokens[4].mint(address(mp), shares[4] / 10);
            mp.mint(address(tokens[4]), 100e18 * shares[4] / shares[0], users[3]);
        }

        mp.setDeviationLimit(0.15e18); // 0.15
        mp.setHalfDeviationFee(0.0003e18); // 0.0003
        mp.setBaseTradeFee(0.01e18); // 0.01 1%
        mp.setBaseMintFee(0.001e18); // 0.001 0.1%
        mp.setBaseBurnFee(0.1e18); // 0.1 10%
        mp.setDepegBaseFee(0.6e18);
    }

    function mpUpdateTargetShares(address token, uint share) internal {
        address[] memory t = new address[](1);
        t[0] = address(token);

        uint[] memory s = new uint[](1);
        s[0] = share;
        mp.updateTargetShares(t, s);
    }

    function mpUpdatePrices(address token, uint price) internal {
        address[] memory t = new address[](1);
        t[0] = address(token);

        uint[] memory p = new uint[](1);
        p[0] = price;
        mp.updatePrices(t, p);
    }

    function test_massiveMint_simple() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 40e18);
        tokens[1].transfer(address(mp), 15e18);
        tokens[2].transfer(address(mp), 30e18);
        tokens[3].transfer(address(mp), 30e18);
        tokens[4].transfer(address(mp), 30e18);

        uint oldTs = mp.totalSupply();
        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        mp.massiveMint(t, users[0]);
        assertEq(mp.totalSupply(), oldTs + 399.6e18);
    }

    function test_massiveMint_zero() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 40e18);
        tokens[1].transfer(address(mp), 15e18);
        tokens[2].transfer(address(mp), 30e18);
        tokens[3].transfer(address(mp), 30e18);
        tokens[4].transfer(address(mp), 0e18);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        vm.expectRevert("MULTIPOOL: ZQ");
        mp.massiveMint(t, users[0]);
    }

    function test_massiveMint_skipToken() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 40e18);
        tokens[1].transfer(address(mp), 15e18);
        tokens[2].transfer(address(mp), 30e18);
        tokens[4].transfer(address(mp), 0e18);

        address[] memory t = new address[](4);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[4]);

        vm.expectRevert("MULTIPOOL: IL");
        mp.massiveMint(t, users[0]);
    }

    function test_massiveMint_tokensLeft() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 40e18);
        tokens[1].transfer(address(mp), 15e18);
        tokens[2].transfer(address(mp), 30e18);
        tokens[3].transfer(address(mp), 30e18);
        tokens[4].transfer(address(mp), 1000e18);

        uint oldTs = mp.totalSupply();
        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        mp.massiveMint(t, users[0]);
        assertEq(mp.totalSupply(), oldTs + 399.6e18);
        assertEq(mp.getAsset(address(tokens[4])).quantity, 60e18 - 0.03e18);
        assertEq(mp.getAsset(address(tokens[4])).collectedFees, 0.03e18);
        assertEq(mp.getAsset(address(tokens[4])).collectedCashbacks, 0e18);
        assertEq(mp.getAsset(address(tokens[4])).share, 25e18);
        assertEq(mp.getAsset(address(tokens[4])).price, 10e18);
        assertEq(tokens[4].balanceOf(address(mp)), 1030e18);
        assertEq(mp.balanceOf(users[0]), 399.6e18);
        assertEq(mp.balanceOf(users[3]), 400e18);
    }

    function test_massiveMint_smallAmount() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 40);
        tokens[1].transfer(address(mp), 15);
        tokens[2].transfer(address(mp), 30);
        tokens[3].transfer(address(mp), 30);
        tokens[4].transfer(address(mp), 30);

        uint oldTs = mp.totalSupply();
        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        mp.massiveMint(t, users[0]);
        assertEq(mp.totalSupply(), oldTs + 400);
        assertEq(mp.getAsset(address(tokens[4])).quantity, 30e18 + 30);
        assertEq(mp.getAsset(address(tokens[4])).collectedFees, 0);
        assertEq(mp.getAsset(address(tokens[4])).collectedCashbacks, 0e18);
        assertEq(mp.getAsset(address(tokens[4])).share, 25e18);
        assertEq(mp.getAsset(address(tokens[4])).price, 10e18);
        assertEq(tokens[4].balanceOf(address(mp)), 30e18 + 30);
        assertEq(mp.balanceOf(users[0]), 400);
        assertEq(mp.balanceOf(users[3]), 400e18);
    }

    function test_massiveMint_addRemoveTokens() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 0e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 40e18);
        tokens[1].transfer(address(mp), 15e18);
        tokens[2].transfer(address(mp), 30e18);
        tokens[3].transfer(address(mp), 30e18);

        uint oldTs = mp.totalSupply();
        address[] memory t = new address[](4);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);

        mp.massiveMint(t, users[0]);

        assertEq(mp.totalSupply(), oldTs + 324.675e18);
        assertEq(mp.getAsset(address(tokens[3])).quantity, 60e18 - 0.03e18);
        assertEq(mp.getAsset(address(tokens[3])).collectedFees, 0.03e18);
        assertEq(mp.getAsset(address(tokens[3])).collectedCashbacks, 0e18);
        assertEq(mp.getAsset(address(tokens[3])).share, 25e18);
        assertEq(mp.getAsset(address(tokens[3])).price, 10e18);
        assertEq(tokens[3].balanceOf(address(mp)), 60e18);
        assertEq(mp.balanceOf(users[0]), 324.675e18);
        assertEq(mp.balanceOf(users[3]), 325e18);

        uint preMintTs = mp.totalSupply();

        assertEq(preMintTs, 649.675e18);

        tokens[4].mint(address(mp), 600e18 / 10);
        mp.mint(address(tokens[4]), 100e18 * 300e18 / 400e18, users[3]);

        uint aftMintTs = mp.totalSupply();
        assertEq(aftMintTs, 649.675e18 + 75e18);

        tokens[0].transfer(address(mp), 40e18);
        tokens[1].transfer(address(mp), 15e18);
        tokens[2].transfer(address(mp), 30e18);
        tokens[3].transfer(address(mp), 30e18);
        tokens[4].transfer(address(mp), 30e18);

        address[] memory t1 = new address[](5);
        t1[0] = address(tokens[0]);
        t1[1] = address(tokens[1]);
        t1[2] = address(tokens[2]);
        t1[3] = address(tokens[3]);
        t1[4] = address(tokens[4]);

        mp.massiveMint(t1, users[0]);

        assertEq(mp.totalSupply(), 649.675e18 + 75e18 + 362.156240620310155078e18);
    }

    function test_massiveMint_usdCapAccuracy() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 0e18]);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        uint[] memory p = new uint[](5);
        p[0] = 1111111111;
        p[1] = 20.000002e18;
        p[2] = 10.000001e18;
        p[3] = 10.000001e18;
        p[4] = 10.000001e18;

        mp.updatePrices(t, p);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 41);
        tokens[1].transfer(address(mp), 150);
        tokens[2].transfer(address(mp), 300);
        tokens[3].transfer(address(mp), 300);

        uint oldTs = mp.totalSupply();
        t = new address[](4);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);

        mp.massiveMint(t, users[0]);

        uint preMintTs = mp.totalSupply();

        tokens[0].transfer(address(mp), 40.000000000411111111e18);
        tokens[1].transfer(address(mp), 15.00000000015e18);
        tokens[2].transfer(address(mp), 30.0000000003e18);
        tokens[3].transfer(address(mp), 30.0000000003e18);

        console.log(
            uint(909090909091687668) * uint(8940000000000000000) / uint(1e18)
                + uint(6363636363646034826) * uint(719741000000000000) / uint(1e18)
                + uint(10909090909093024797) * uint(3290000000000000000) / uint(1e18)
                + uint(909090909090909230) * uint(467448143500000000) / uint(1e18)
                + uint(1826295030239284775) * uint(38114302323000000000) / uint(1e18)
        );
        console.log(uint(118631265589462499816));

        address[] memory t1 = new address[](4);
        t1[0] = address(tokens[0]);
        t1[1] = address(tokens[1]);
        t1[2] = address(tokens[2]);
        t1[3] = address(tokens[3]);

        mp.massiveMint(t1, users[0]);

        uint aftMintTs = mp.totalSupply();
    }
}
