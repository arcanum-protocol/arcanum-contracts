pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import { MockERC20 } from "../../src/mocks/erc20.sol";
import { Multipool, MpContext, MpAsset } from "../../src/multipool/Multipool.sol";

contract MultipoolActor is Test {
    Multipool mp;
    MockERC20[] tokens;
    address[] users;
    constructor(uint tokenNum, uint userNum) {
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

    function updateTargetShare(uint8 tokenIndex, uint targetShare) public {
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];
       targetShare = bound(targetShare, 0, 100000e18);

       address[] memory tkn = new address[](1);
       tkn[0] = address(token);

       uint[] memory trgtShare = new uint[](1);
       trgtShare[0] = targetShare;

       mp.updateTargetShares(tkn, trgtShare);
    }

    function updateDeviationLimit(uint value) public {
       value = bound(value, 1, 90e18);
       mp.setDeviationLimit(value);
    }

    function updateHalfDeviationFee(uint value) public {
       value = bound(value, 1, 90e18);
       mp.setHalfDeviationFee(value);
    }

    function updatePrice(uint8 tokenIndex, uint price) public {
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];
       price = bound(price, 0, 100000e18);

       address[] memory tkn = new address[](1);
       tkn[0] = address(token);

       uint[] memory pr = new uint[](1);
       pr[0] = price;

       mp.updatePrices(tkn, pr);
    }

    function mint(uint8 callerIndex, uint8 tokenIndex, uint share, uint supplyAmount, uint8 toIndex) public {
       address caller = users[bound(callerIndex, 0, users.length-1)];
       address to = users[bound(toIndex, 0, users.length-1)];
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];

       MpContext memory ctx = mp.getMintContext();
       MpAsset memory asset = mp.getAssets(address(token));
       uint balanceOfAsset = token.balanceOf(address(caller));
       uint totalSupply = mp.totalSupply();

       share = bound(share, 0, 100000e18);
       supplyAmount = bound(share, 0, balanceOfAsset);

       vm.startPrank(caller);
       token.transfer(address(mp), totalSupply == 0 ? share : supplyAmount );
       mp.mint(address(token), share, to);
       console.log("here");
    }

    function burn(uint8 callerIndex, uint8 tokenIndex, uint share, uint8 toIndex) public {
       address caller = users[bound(callerIndex, 0, users.length-1)];
       address to = users[bound(toIndex, 0, users.length-1)];
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];

       MpContext memory ctx = mp.getMintContext();
       MpAsset memory asset = mp.getAssets(address(token));
       uint balanceOfMultipool = mp.balanceOf(address(caller));

       share = bound(share, 0, balanceOfMultipool);

       vm.startPrank(caller);
       mp.transfer(address(mp), share);
       mp.burn(address(token), share, to);
    }

    function swap(uint8 callerIndex,uint8 tokenInIndex, uint8 tokenOutIndex, uint share, uint supplyAmount, uint8 toIndex) public {
       address caller = users[bound(callerIndex, 0, users.length-1)];
       address to = users[bound(toIndex, 0, users.length-1)];
       MockERC20 tokenIn = tokens[bound(tokenInIndex, 0, tokens.length-1)];
       MockERC20 tokenOut = tokens[bound(tokenOutIndex, 0, tokens.length-1)];

       MpContext memory ctx = mp.getMintContext();
       uint balanceOfAsset = tokenIn.balanceOf(address(caller));

       share = bound(share, 0, 100000e18);
       supplyAmount = bound(share, 0, balanceOfAsset);

       vm.startPrank(caller);
       tokenIn.transfer(address(mp), supplyAmount);
       mp.swap(address(tokenIn), address(tokenOut), share, to);
    }
}

contract MultipoolSingleAssetTest is Test {
    MultipoolActor h;

    function setUp() public {
        h = new MultipoolActor(3,2);
        targetContract(address(h));
    }

   // function invariant_BalancesMatch() public {
   //     assertEq(address(h),address(h));
   // }
}
