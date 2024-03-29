// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Multipool} from "./Multipool.sol";
import {ForcePushArgs, AssetArgs} from "../types/SwapArgs.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

interface WETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract MultipoolRouter is Ownable {
    mapping(address => bool) isContractAllowedToCall;

    function toggleContract(address contractAddress) public onlyOwner {
        isContractAllowedToCall[contractAddress] = !isContractAllowedToCall[contractAddress];
    }

    enum CallType {
        ERC20Transfer,
        ERC20Approve,
        Any,
        Wrap
    }

    struct TokenTransferParams {
        address token;
        address targetOrOrigin;
        uint amount;
    }

    struct RouterApproveParams {
        address token;
        address target;
        uint amount;
    }

    struct WrapParams {
        address weth;
        bool wrap;
        uint ethValue;
    }

    struct Call {
        CallType callType;
        bytes data;
    }

    error CallFailed(uint callNumber, bool isPredecessing);
    error InsufficientEthBalance(uint callNumber, bool isPredecessing);
    error InsufficientEthBalanceCallingSwap();
    error ContractCallNotAllowed(address target);

    struct SwapArgs {
        ForcePushArgs forcePushArgs;
        AssetArgs[] assetsToSwap;
        bool isExactInput;
        address receiverAddress;
        bool refundEthToReceiver;
        address refundAddress;
        uint ethValue;
    }

    function processCall(Call memory call, uint index, bool isPredecessing) internal {
        if (call.callType == CallType.Any) {
            (address target, uint ethValue, bytes memory targetData) =
                abi.decode(call.data, (address, uint, bytes));
            if (!isContractAllowedToCall[target]) {
                revert ContractCallNotAllowed(target);
            }
            if (address(this).balance < ethValue) {
                revert InsufficientEthBalance(index, isPredecessing);
            }
            (bool success,) = target.call{value: ethValue}(targetData);
            if (!success) revert CallFailed(index, isPredecessing);
        } else if (call.callType == CallType.ERC20Transfer) {
            TokenTransferParams memory params = abi.decode(call.data, (TokenTransferParams));
            if (isPredecessing) {
                IERC20(params.token).transferFrom(msg.sender, params.targetOrOrigin, params.amount);
            } else {
                IERC20(params.token).transferFrom(
                    address(this), params.targetOrOrigin, params.amount
                );
            }
        } else if (call.callType == CallType.ERC20Approve) {
            RouterApproveParams memory params = abi.decode(call.data, (RouterApproveParams));
            if (!isContractAllowedToCall[params.target]) {
                revert ContractCallNotAllowed(params.target);
            }
            IERC20(params.token).approve(params.target, params.amount);
        } else if (call.callType == CallType.Wrap) {
            WrapParams memory params = abi.decode(call.data, (WrapParams));
            if (params.wrap) {
                WETH(params.weth).deposit{value: params.ethValue}();
            } else {
                WETH(params.weth).withdraw(params.ethValue);
            }
        }
    }

    function swap(
        address poolAddress,
        SwapArgs calldata swapArgs,
        Call[] calldata paramsBefore,
        Call[] calldata paramsAfter
    )
        external
        payable
    {
        for (uint i; i < paramsBefore.length; ++i) {
            processCall(paramsBefore[i], i, true);
        }

        if (address(this).balance < swapArgs.ethValue) revert InsufficientEthBalanceCallingSwap();
        Multipool(poolAddress).swap{value: swapArgs.ethValue}(
            swapArgs.forcePushArgs,
            swapArgs.assetsToSwap,
            swapArgs.isExactInput,
            swapArgs.receiverAddress,
            swapArgs.refundEthToReceiver,
            swapArgs.refundAddress
        );

        for (uint i; i < paramsAfter.length; ++i) {
            processCall(paramsAfter[i], i, false);
        }
    }
}
