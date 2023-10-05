pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../../src/multipool/MultipoolRouter.sol";
import {MultipoolMassiveMintRouter} from "../../src/multipool/MultipoolMassiveMintRouter.sol";

contract MockCallSomething is Test {
    function callWithEther(uint amount, address token, address to) public payable {
        require(msg.value != 0, "fail");
        IERC20(token).transferFrom(msg.sender, to, amount);
    }

    function callNoEther(uint amount, address token, address to) public {
        IERC20(token).transferFrom(msg.sender, to, amount);
    }

    function mockTransferAllFunds(uint[] calldata amounts, address[] calldata tokens, address to) public {
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transfer(to, amounts[i]);
        }
    }
}

contract MultipoolRouterCases is Test {
    Multipool mp;
    MultipoolRouter router;
    MultipoolMassiveMintRouter massiveRouter;

    MockCallSomething mocked;

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
        massiveRouter = new MultipoolMassiveMintRouter();
        mocked = new MockCallSomething();

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

    function test_MassiveRouter_Mint() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        address[] memory t = new address[](3);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);

        MultipoolMassiveMintRouter.CallParams[] memory calls = new MultipoolMassiveMintRouter.CallParams[](2);
        calls[0].targetData = abi.encodeCall(MockCallSomething.callNoEther, (20e18, address(tokens[0]), address(mp)));
        calls[0].target = address(mocked);
        calls[0].ethValue = 0;

        calls[1].targetData = abi.encodeCall(MockCallSomething.callWithEther, (20e18, address(tokens[0]), address(mp)));
        calls[1].target = address(mocked);
        calls[1].ethValue = 10;

        massiveRouter.toggleContract(address(mocked));
        massiveRouter.approveToken(address(tokens[0]), address(mocked));

        tokens[1].mint(address(mp), 15e18);
        tokens[2].mint(address(mp), 30e18);

        vm.prank(users[0]);
        tokens[0].approve(address(massiveRouter), 40e18);
        vm.deal(users[0], 1 ether);
        vm.prank(users[0]);

        massiveRouter.massiveMint{value: 10}(address(mp), address(tokens[0]), 40e18, 0, calls, t, users[0]);

        assertEq(mp.balanceOf(users[0]), 249.75e18);
        checkUsdCap();
    }

    function test_MassiveRouter_FailLackEth() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        address[] memory t = new address[](3);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);

        MultipoolMassiveMintRouter.CallParams[] memory calls = new MultipoolMassiveMintRouter.CallParams[](2);
        calls[0].targetData = abi.encodeCall(MockCallSomething.callNoEther, (20e18, address(tokens[0]), address(mp)));
        calls[0].target = address(mocked);
        calls[0].ethValue = 0;

        calls[1].targetData = abi.encodeCall(MockCallSomething.callWithEther, (20e18, address(tokens[0]), address(mp)));
        calls[1].target = address(mocked);
        calls[1].ethValue = 10;

        massiveRouter.toggleContract(address(mocked));
        massiveRouter.approveToken(address(tokens[0]), address(mocked));

        tokens[1].mint(address(mp), 15e18);
        tokens[2].mint(address(mp), 30e18);

        vm.prank(users[0]);
        tokens[0].approve(address(massiveRouter), 40e18);
        vm.deal(users[0], 1 ether);
        vm.prank(users[0]);

        vm.expectRevert("MULTIPOOL_MASS_ROUTER: CF");
        massiveRouter.massiveMint{value: 1}(address(mp), address(tokens[0]), 40e18, 0, calls, t, users[0]);
        checkUsdCap();
    }

    function test_MassiveRouter_FailFunctionRevert() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        address[] memory t = new address[](3);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);

        MultipoolMassiveMintRouter.CallParams[] memory calls = new MultipoolMassiveMintRouter.CallParams[](2);
        calls[0].targetData = abi.encodeCall(MockCallSomething.callNoEther, (20e18, address(tokens[0]), address(mp)));
        calls[0].target = address(mocked);
        calls[0].ethValue = 0;

        calls[1].targetData = abi.encodeCall(MockCallSomething.callWithEther, (20e18, address(tokens[0]), address(mp)));
        calls[1].target = address(mocked);
        calls[1].ethValue = 0;

        massiveRouter.toggleContract(address(mocked));
        massiveRouter.approveToken(address(tokens[0]), address(mocked));

        tokens[1].mint(address(mp), 15e18);
        tokens[2].mint(address(mp), 30e18);

        vm.prank(users[0]);
        tokens[0].approve(address(massiveRouter), 40e18);
        vm.deal(users[0], 1 ether);
        vm.prank(users[0]);

        vm.expectRevert("MULTIPOOL_MASS_ROUTER: CF");
        massiveRouter.massiveMint{value: 10}(address(mp), address(tokens[0]), 40e18, 0, calls, t, users[0]);
        checkUsdCap();
    }

    function test_MassiveRouter_GasExample() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18]);

        address[] memory t = new address[](3);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);

        MultipoolMassiveMintRouter.CallParams[] memory calls = new MultipoolMassiveMintRouter.CallParams[](2);
        calls[0].targetData = abi.encodeCall(MockCallSomething.callNoEther, (40e18, address(tokens[0]), address(mp)));
        calls[0].target = address(mocked);
        calls[0].ethValue = 0;

        address[] memory tokensArg = new address[](2);
        tokensArg[0] = address(tokens[1]);
        tokensArg[1] = address(tokens[2]);

        uint[] memory amountsArg = new uint[](2);
        amountsArg[0] = 15e18;
        amountsArg[1] = 30e18;

        calls[1].targetData =
            abi.encodeCall(MockCallSomething.mockTransferAllFunds, (amountsArg, tokensArg, address(mp)));
        calls[1].target = address(mocked);
        calls[1].ethValue = 0;

        massiveRouter.toggleContract(address(mocked));
        massiveRouter.approveToken(address(tokens[0]), address(mocked));

        tokens[1].mint(address(mocked), 15e18);
        tokens[2].mint(address(mocked), 30e18);

        vm.prank(users[0]);
        tokens[0].approve(address(massiveRouter), 40e18);
        vm.prank(users[0]);

        massiveRouter.massiveMint(address(mp), address(tokens[0]), 40e18, 0, calls, t, users[0]);
        assertEq(mp.balanceOf(users[0]), 249.75e18);
        checkUsdCap();
    }
}
