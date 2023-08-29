pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../../src/multipool/MultipoolRouter.sol";

contract MultipoolRouterActor is Test {
    Multipool public mp;
    MultipoolRouter public router;
    MockERC20[] public tokens;
    address[] public users;

    constructor(uint tokenNum, uint userNum) {
        mp = new Multipool('Name', 'SYMBOL');
        router = new MultipoolRouter();
        for (uint i; i < tokenNum; i++) {
            tokens.push(new MockERC20('token', 'token', 0));
        }
        for (uint i; i < userNum; i++) {
            users.push(makeAddr(string(abi.encode("ROUTER", i ,1000))));
        }
        for (uint u; u < userNum; u++) {
            for (uint t; t < tokenNum; t++) {
                tokens[t].mint(users[u], 10000000000e18);
            }
        }
        updateTargetShare(0, 10e18);
        updateDeviationLimit(0.1e18);
        updateHalfDeviationFee(0.0003e18);
        updatePrice(0, 10e18);
        address initialMinter = makeAddr(string(abi.encode("INITIAL USER")));
        tokens[0].mint(address(mp), 1000e18);
        vm.prank(initialMinter);
        mp.mint(address(tokens[0]), 1000e18, initialMinter);
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
       value = bound(value, 1, 1e18);
       mp.setDeviationLimit(value);
    }

    function updateHalfDeviationFee(uint value) public {
       value = bound(value, 1, 1e18);
       mp.setHalfDeviationFee(value);
    }

    function updatePrice(uint8 tokenIndex, uint price) public {
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];
       price = bound(price, 0, 10e18);

       address[] memory tkn = new address[](1);
       tkn[0] = address(token);

       uint[] memory pr = new uint[](1);
       pr[0] = price;

       mp.updatePrices(tkn, pr);
    }

    function mintFromShare(uint8 callerIndex, uint8 tokenIndex, uint share, uint8 toIndex) public {
       address caller = users[bound(callerIndex, 0, users.length-1)];
       address to = users[bound(toIndex, 0, users.length-1)];
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];
       share = bound(share, 0, 10e18);

       uint balance = token.balanceOf(caller);
       (bool success, bytes memory data) = address(router).call(abi.encode(
               router.estimateMintAmountIn.selector,
               address(mp),
               address(token),
               share
       ));
       if (!success) {
           vm.expectRevert();
       } 
       vm.prank(caller);
       router.mintWithSharesOut(
           address(mp),
           address(token),
           share,
           balance,
           to,
           uint(0)
       );
    }

    function mintFromAmountIn(uint8 callerIndex, uint8 tokenIndex, uint amount, uint8 toIndex) public {
       address caller = users[bound(callerIndex, 0, users.length-1)];
       address to = users[bound(toIndex, 0, users.length-1)];
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];
       amount = bound(amount, 0, 10e18);

       (bool success, bytes memory data) = address(router).call(abi.encode(
               router.estimateMintSharesOut.selector,
               address(mp),
               address(token),
               amount
       ));
       if (!success) {
           vm.expectRevert();
       }
       vm.prank(caller);
       router.mintWithAmountIn(
           address(mp),
           address(token),
           amount,
           0,
           to,
           uint(0)
       );
    }

    function burnFromShare(uint8 callerIndex, uint8 tokenIndex, uint share, uint8 toIndex) public {
       address caller = users[bound(callerIndex, 0, users.length-1)];
       address to = users[bound(toIndex, 0, users.length-1)];
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];
       share = bound(share, 0, 10e18);

       (bool success, bytes memory data) = address(router).call(abi.encode(
               router.estimateBurnAmountOut.selector,
               address(mp),
               address(token),
               share
       ));
       if (!success) {
           vm.expectRevert();
       } 
       vm.prank(caller);
       router.burnWithSharesIn(
           address(mp),
           address(token),
           share,
           0,
           to,
           uint(0)
       );
    }

    function burnFromAmountOut(uint8 callerIndex, uint8 tokenIndex, uint amount, uint8 toIndex) public {
       address caller = users[bound(callerIndex, 0, users.length-1)];
       address to = users[bound(toIndex, 0, users.length-1)];
       MockERC20 token = tokens[bound(tokenIndex, 0, tokens.length-1)];
       amount = bound(amount, 0, 10e18);

        uint balance = mp.balanceOf(caller);
       (bool success, bytes memory data) = address(router).call(abi.encode(
               router.estimateBurnSharesIn.selector,
               address(mp),
               address(token),
               amount
       ));
       if (!success) {
           vm.expectRevert();
       } 
       vm.prank(caller);
       router.burnWithAmountOut(
           address(mp),
           address(token),
           amount,
           balance,
           to,
           uint(0)
       );
    }

   // function swap(uint8 callerIndex,uint8 tokenInIndex, uint8 tokenOutIndex, uint share, uint supplyAmount, uint8 toIndex) public {
   //    address caller = users[bound(callerIndex, 0, users.length-1)];
   //    address to = users[bound(toIndex, 0, users.length-1)];
   //    MockERC20 tokenIn = tokens[bound(tokenInIndex, 0, tokens.length-1)];
   //    MockERC20 tokenOut = tokens[bound(tokenOutIndex, 0, tokens.length-1)];

   //    MpContext memory ctx = mp.getMintContext();
   //    uint balanceOfAsset = tokenIn.balanceOf(address(caller));

   //    share = bound(share, 0, 100000e18);
   //    supplyAmount = bound(share, 0, balanceOfAsset);

   //    vm.startPrank(caller);
   //    tokenIn.transfer(address(mp), supplyAmount);
   //    mp.swap(address(tokenIn), address(tokenOut), share, to);
   // }
}

contract MultipoolRouterSingleAssetTest is Test {
    MultipoolRouterActor h;
    uint tokensNum;
    uint usersNum;

    function setUp() public {
        tokensNum = 3;
        usersNum = 2;
        h = new MultipoolRouterActor(tokensNum,usersNum);
        targetContract(address(h));
    }

    function invariant_RouterExecution() public {
        for (uint t = 0; t < tokensNum; t++) {
            MockERC20 token = h.tokens(t);
            Multipool mp = h.mp();
            uint balance = token.balanceOf(address(mp));
            MpAsset memory asset = mp.getAssets(address(token));
            uint mpSumm = asset.quantity + asset.collectedCashbacks + asset.collectedFees;
            console.log("tot: ", mpSumm);
            console.log("balance: ", balance);
            assertEq(mpSumm,balance);
           // uint usersBalance;
           // for (uint u = 0; u < usersNum; u++) {
           //     usersBalance += token.balanceOf(h.users(u));
           // }
            console.log(address(token));
        }
    }
}
