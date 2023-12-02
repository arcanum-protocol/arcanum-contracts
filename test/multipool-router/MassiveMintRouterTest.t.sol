pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../../src/multipool/MultipoolRouter.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic} from "../MultipoolUtils.t.sol";

contract MockCallSomething is Test {
    function callWithEther(uint amount, address token, address to) public payable {
        require(msg.value != 20e18, "fail");
        IERC20(token).transfer(to, amount);
    }

    function callNoEther(uint amount, address token, address to) public {
        IERC20(token).transferFrom(msg.sender, to, amount);
    }

    function mockTransferAllFunds(uint[] calldata amounts, address[] calldata tokens, address to)
        public
    {
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transfer(to, amounts[i]);
        }
    }
}

contract MultipoolRouterCases is Test, MultipoolUtils {
    MockCallSomething mocked;

    function test_MassiveRouter_GasExample() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);
        mocked = new MockCallSomething();

        Multipool.AssetArg[] memory assetArgs = sort(
            dynamic(
                [
                    Multipool.AssetArg({addr: address(tokens[0]), amount: int(1e18)}),
                    Multipool.AssetArg({addr: address(tokens[1]), amount: int(0.5e18)}),
                    Multipool.AssetArg({addr: address(tokens[2]), amount: int(-2e18)}),
                    Multipool.AssetArg({addr: address(tokens[3]), amount: int(-4e18)})
                ]
            )
        );
        MultipoolRouter.SwapArgs memory sa = MultipoolRouter.SwapArgs({
            fpSharePrice: Multipool.FPSharePriceArg({
                thisAddress: address(0),
                timestamp: 0,
                value: 0,
                signature: abi.encode(0)
            }),
            selectedAssets: assetArgs,
            isExactInput: true,
            to: users[0],
            refundTo: users[0],
            ethValue: 5e18
        });

        MultipoolRouter.Call[] memory calls = new MultipoolRouter.Call[](7);
        calls[0] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ERC20Transfer,
            data: abi.encode(
                MultipoolRouter.TokenTransferParams({
                    token: address(tokens[0]),
                    targetOrOrigin: address(mocked),
                    amount: 0.5e18
                })
                )
        });

        calls[1] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ERC20Approve,
            data: abi.encode(
                MultipoolRouter.RouterApproveParams({
                    token: address(tokens[0]),
                    target: address(mocked),
                    amount: 0.5e18
                })
                )
        });

        calls[2] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ANY,
            data: abi.encode(
                MultipoolRouter.CallParams({
                    targetData: abi.encodeCall(
                        MockCallSomething.callWithEther, (0.5e18, address(tokens[0]), address(mp))
                        ),
                    target: address(mocked),
                    ethValue: 20e18
                })
                )
        });

        address[] memory tokensArg = new address[](2);
        tokensArg[0] = address(tokens[0]);
        tokensArg[1] = address(tokens[1]);

        uint[] memory amountsArg = new uint[](2);
        amountsArg[0] = 0.5e18;
        amountsArg[1] = 0.25e18;

        calls[3] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ERC20Transfer,
            data: abi.encode(
                MultipoolRouter.TokenTransferParams({
                    token: address(tokens[0]),
                    targetOrOrigin: address(mocked),
                    amount: 0.5e18
                })
                )
        });

        calls[4] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ERC20Transfer,
            data: abi.encode(
                MultipoolRouter.TokenTransferParams({
                    token: address(tokens[1]),
                    targetOrOrigin: address(mocked),
                    amount: 0.25e18
                })
                )
        });

        calls[5] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ANY,
            data: abi.encode(
                MultipoolRouter.CallParams({
                    targetData: abi.encodeCall(
                        MockCallSomething.mockTransferAllFunds, (amountsArg, tokensArg, address(mp))
                        ),
                    target: address(mocked),
                    ethValue: 0
                })
                )
        });

        calls[6] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ERC20Transfer,
            data: abi.encode(
                MultipoolRouter.TokenTransferParams({
                    token: address(tokens[1]),
                    targetOrOrigin: address(mp),
                    amount: 0.25e18
                })
                )
        });

        MultipoolRouter.Call[] memory callsAfter;

        router.toggleContract(address(mocked));

        vm.deal(users[0], 100 ether);

        vm.prank(users[0]);
        tokens[0].approve(address(router), 1e18);
        vm.prank(users[0]);
        tokens[1].approve(address(router), 1e18);

        vm.prank(users[0]);
        vm.expectRevert(
            abi.encodeWithSelector(MultipoolRouter.InsufficientEthBalance.selector, 2, true)
        );
        router.swap(address(mp), sa, calls, callsAfter);

        vm.prank(users[0]);
        vm.expectRevert(
            abi.encodeWithSelector(MultipoolRouter.InsufficientEthBalance.selector, 2, true)
        );
        router.swap{value: 1}(address(mp), sa, calls, callsAfter);

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(MultipoolRouter.CallFailed.selector, 2, true));
        router.swap{value: 20e18}(address(mp), sa, calls, callsAfter);

        calls[2] = MultipoolRouter.Call({
            callType: MultipoolRouter.CallType.ANY,
            data: abi.encode(
                MultipoolRouter.CallParams({
                    targetData: abi.encodeCall(
                        MockCallSomething.callWithEther, (0.5e18, address(tokens[0]), address(mp))
                        ),
                    target: address(mocked),
                    ethValue: 1e18
                })
                )
        });

        vm.prank(users[0]);
        router.swap{value: 10e18}(address(mp), sa, calls, callsAfter);
    }
}
