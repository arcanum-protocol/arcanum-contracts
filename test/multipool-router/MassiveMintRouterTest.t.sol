// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../../src/multipool/MultipoolRouter.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

contract MockCallSomething is Test {
    function callWithEther(uint amount, address token, address to) public payable {
        require(msg.value != 20e18, "fail");
        IERC20(token).transfer(to, amount);
    }

    function callNoEther(uint amount, address token, address to) public {
        IERC20(token).transferFrom(msg.sender, to, amount);
    }

    function mockTransferAllFunds(
        uint[] calldata amounts,
        address[] calldata tokens,
        address to
    )
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

        AssetArgs[] memory assetArgs = sort(
            dynamic(
                [
                    AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                    AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                    AssetArgs({assetAddress: address(tokens[2]), amount: int(-2e18)}),
                    AssetArgs({assetAddress: address(tokens[3]), amount: int(-4e18)})
                ]
            )
        );
        bytes[] memory signatures0 = new bytes[](0);
        MultipoolRouter.SwapArgs memory sa = MultipoolRouter.SwapArgs({
            forcePushArgs: ForcePushArgs({
                contractAddress: address(0),
                timestamp: 0,
                sharePrice: 0,
                signatures: signatures0
            }),
            assetsToSwap: assetArgs,
            isExactInput: true,
            receiverAddress: users[0],
            refundEthToReceiver: false,
            refundAddress: users[0],
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
            callType: MultipoolRouter.CallType.Any,
            data: abi.encode(
                address(mocked),
                uint(20e18),
                bytes(
                    abi.encodeCall(
                        MockCallSomething.callWithEther, (0.5e18, address(tokens[0]), address(mp))
                    )
                )
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
            callType: MultipoolRouter.CallType.Any,
            data: abi.encode(
                address(mocked),
                uint(0),
                abi.encodeCall(
                    MockCallSomething.mockTransferAllFunds, (amountsArg, tokensArg, address(mp))
                )
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
            callType: MultipoolRouter.CallType.Any,
            data: abi.encode(
                address(mocked),
                uint(1e18),
                abi.encodeCall(
                    MockCallSomething.callWithEther, (0.5e18, address(tokens[0]), address(mp))
                )
            )
        });

        vm.prank(users[0]);
        router.swap{value: 10e18}(address(mp), sa, calls, callsAfter);
    }

    function test_MassiveRouter_LargeMemoryAllocation() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);
        mocked = new MockCallSomething();

        AssetArgs[] memory assetArgs = sort(
            dynamic(
                [
                    AssetArgs({assetAddress: address(tokens[0]), amount: int(1e18)}),
                    AssetArgs({assetAddress: address(tokens[1]), amount: int(0.5e18)}),
                    AssetArgs({assetAddress: address(tokens[2]), amount: int(-2e18)}),
                    AssetArgs({assetAddress: address(tokens[3]), amount: int(-4e18)})
                ]
            )
        );
        bytes[] memory signatures0 = new bytes[](0);
        MultipoolRouter.SwapArgs memory sa = MultipoolRouter.SwapArgs({
            forcePushArgs: ForcePushArgs({
                contractAddress: address(0),
                timestamp: 0,
                sharePrice: 0,
                signatures: signatures0
            }),
            assetsToSwap: assetArgs,
            isExactInput: true,
            receiverAddress: users[0],
            refundEthToReceiver: false,
            refundAddress: users[0],
            ethValue: 5e18
        });

        MultipoolRouter.Call[] memory calls = new MultipoolRouter.Call[](7);

        for (uint i; i < calls.length; ++i) {
            calls[i] = MultipoolRouter.Call({
                callType: MultipoolRouter.CallType.Any,
                data: hex"000000000000000000000000000000000000000000000000000000000000006000000000000000000000000068b3465833fb72a70ecdf485e0e4c7bd8665fc4500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000144c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000004810e5a7741ea5fdbb658eda632ddfac3b19e3c600000000000000000000000000000000000000000000000000000000658a3a5c0000000000000000000000000000000000000000000000000000000001d763a900000000000000000000000000000000000000000000000008d64feffa1fddb00000000000000000000000000000000000000000000000000000000000000042fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb90001f482af49447d8a07e3bd95bd0d56f35241523fbab1002710fc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            });
        }

        MultipoolRouter.Call[] memory callsAfter;

        router.toggleContract(address(mocked));

        vm.expectRevert(
            abi.encodeWithSelector(
                MultipoolRouter.ContractCallNotAllowed.selector,
                0x0000000000000000000000000000000000000060
            )
        );
        router.swap(address(mp), sa, calls, callsAfter);
    }
}
