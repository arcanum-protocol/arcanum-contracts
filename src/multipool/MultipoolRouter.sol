// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Multipool} from "./Multipool.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract MultipoolRouter is Ownable {
    mapping(address => bool) isContractAllowedToCall;

    function toggleContract(address contractAddress) public onlyOwner {
        isContractAllowedToCall[contractAddress] = !isContractAllowedToCall[contractAddress];
    }

    enum CallType {
        ERC20Transfer,
        ERC20Approve,
        ANY
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

    struct CallParams {
        bytes targetData;
        address target;
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
        Multipool.ForcePushArgs fpSharePrice;
        Multipool.AssetArgs[] selectedAssets;
        bool isExactInput;
        address to;
        address refundTo;
        uint ethValue;
    }

    function processCall(Call memory call, uint index, bool isPredecessing) internal {
        if (call.callType == CallType.ANY) {
            CallParams memory params = abi.decode(call.data, (CallParams));
            if (!isContractAllowedToCall[params.target]) {
                revert ContractCallNotAllowed(params.target);
            }
            if (address(this).balance < params.ethValue) {
                revert InsufficientEthBalance(index, isPredecessing);
            }
            (bool success,) = params.target.call{value: params.ethValue}(params.targetData);
            if (!success) revert CallFailed(index, isPredecessing);
        } else if (call.callType == CallType.ERC20Transfer) {
            TokenTransferParams memory params = abi.decode(call.data, (TokenTransferParams));
            IERC20(params.token).transferFrom(msg.sender, params.targetOrOrigin, params.amount);
        } else if (call.callType == CallType.ERC20Approve) {
            RouterApproveParams memory params = abi.decode(call.data, (RouterApproveParams));
            if (!isContractAllowedToCall[params.target]) {
                revert ContractCallNotAllowed(params.target);
            }
            IERC20(params.token).approve(params.target, params.amount);
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
            swapArgs.fpSharePrice,
            swapArgs.selectedAssets,
            swapArgs.isExactInput,
            swapArgs.to,
            swapArgs.refundTo
        );

        for (uint i; i < paramsAfter.length; ++i) {
            processCall(paramsAfter[i], i, false);
        }
    }
}
