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
        tokenNum = 4;
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

        mp.setTokenDecimals(address(tokens[0]), 18);
        mp.setTokenDecimals(address(tokens[1]), 18);
        mp.setTokenDecimals(address(tokens[2]), 18);

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

    function test_mintUnconfiguredContract() public {
        vm.prank(users[0]);
        tokens[0].transfer(address(mp), 10e18);
        vm.expectRevert("MULTIPOOL: ZP");
        mp.mint(address(tokens[0]), 10e18, users[0]);
        mpUpdateTargetShares(address(tokens[0]), 10);
        mpUpdatePrices(address(tokens[0]), 10);
        mp.mint(address(tokens[0]), 10e18, users[0]);
    }

    function test_burnUnconfiguredContract() public {
        vm.prank(users[0]);
        vm.expectRevert("MULTIPOOL: ZP");
        mp.burn(address(tokens[0]), 10e18, users[0]);
    }

    function test_mintBurnSignleAssetWithFees() public {
        vm.prank(users[0]);
        tokens[0].transfer(address(mp), 10e18);
        vm.expectRevert("MULTIPOOL: ZP");
        mp.mint(address(tokens[0]), 10e18, users[0]);
        mpUpdateTargetShares(address(tokens[0]), 10);
        mpUpdatePrices(address(tokens[0]), 10);
        mp.mint(address(tokens[0]), 10e18, users[0]);
    }

    function test_MintZeroShares() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 1e18);
        vm.expectRevert("MULTIPOOL: ZS");
        mp.mint(address(tokens[0]), 0, users[0]);
    }

    function test_BurnZeroShares() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 1e18);
        vm.expectRevert("MULTIPOOL: ZS");
        mp.burn(address(tokens[0]), 0, users[0]);
    }

    function test_SwapSameTokens() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 1e18);
        vm.expectRevert("MULTIPOOL: SA");
        mp.swap(address(tokens[0]), address(tokens[0]), 2e18, users[0]);
    }

    function test_SwapZeroShare() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 1e18);
        vm.expectRevert("MULTIPOOL: ZS");
        mp.swap(address(tokens[0]), address(tokens[1]), 0e18, users[0]);
    }

    function test_SwapToNonExistingToken() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 1e18);
        vm.expectRevert("MULTIPOOL: ZP");
        mp.swap(address(tokens[0]), users[0], 2e18, users[0]);
    }

    function test_SwapWithNonExistingToken() public {
        bootstrapTokens([uint(50e18), 475e18, 475e18]);

        vm.startPrank(users[0]);
        tokens[0].transfer(address(mp), 1e18);
        vm.expectRevert("MULTIPOOL: ZP");
        mp.swap(users[0], address(tokens[0]), 2e18, users[0]);
    }
}
