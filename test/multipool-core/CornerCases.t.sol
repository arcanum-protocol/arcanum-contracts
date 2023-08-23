pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import { MockERC20 } from "../../src/mocks/erc20.sol";
import { Multipool, MpContext, MpAsset } from "../../src/multipool/Multipool.sol";

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

    function test_mintUnconfiguredContract() public {
        vm.prank(users[0]);
        tokens[0].transfer(address(mp), 10e18);
        vm.expectRevert("MULTIPOOL: zero price");
        mp.mint(address(tokens[0]), 10e18, users[0]);
        mp.updateTargetShare(address(tokens[0]), 10);
        mp.updatePrice(address(tokens[0]), 10);
        mp.mint(address(tokens[0]), 10e18, users[0]);
    }

    function test_burnUnconfiguredContract() public {
        vm.prank(users[0]);
        vm.expectRevert("MULTIPOOL: zero price");
        mp.burn(address(tokens[0]), 10e18, users[0]);
    }

    function test_mintBurnSignleAssetWithFees() public {
        vm.prank(users[0]);
        tokens[0].transfer(address(mp), 10e18);
        vm.expectRevert("MULTIPOOL: zero price");
        mp.mint(address(tokens[0]), 10e18, users[0]);
        mp.updateTargetShare(address(tokens[0]), 10);
        mp.updatePrice(address(tokens[0]), 10);
        mp.mint(address(tokens[0]), 10e18, users[0]);
    }
}
