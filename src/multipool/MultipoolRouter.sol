// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Multipool, MpAsset as UintMpAsset, MpContext as UintMpContext} from "./Multipool.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import {MpAsset, MpContext, Multipool} from "./Multipool.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";

contract MultipoolRouter is ReentrancyGuard {
    mapping(address => bool) isContractAllowedToCall;

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

    error PredecessingCallFailed(uint callNumber);
    error SubsequentCallFailed(uint callNumber);
    error ContractCallNotAllowed(address target);

    struct SwapArgs {
        Multipool.FPSharePriceArg fpSharePrice;
        Multipool.AssetArg[] selectedAssets;
        bool isSleepageReverse;
        address to;
        address refundTo;
    }

    function processCall(Call memory call, uint index) internal {
        if (call.callType == CallType.ANY) {
            CallParams memory params = abi.decode(call.data, (CallParams));
            if (!isContractAllowedToCall[params.target]) revert ContractCallNotAllowed(params.target);
            (bool success,) = params.target.call{value: params.ethValue}(params.targetData);
            if (!success) revert PredecessingCallFailed(index);
        } else if (call.callType == CallType.ERC20Transfer) {
            TokenTransferParams memory params = abi.decode(call.data, (TokenTransferParams));
            IERC20(params.token).transferFrom(msg.sender, params.targetOrOrigin, params.amount);
        } else if (call.callType == CallType.ERC20Approve) {
            RouterApproveParams memory params = abi.decode(call.data, (RouterApproveParams));
            if (!isContractAllowedToCall[params.target]) revert ContractCallNotAllowed(params.target);
            IERC20(params.token).approve(params.target, params.amount);
        }
    }

    function swap(
        address poolAddress,
        SwapArgs calldata swapArgs,
        Call[] calldata paramsBefore,
        Call[] calldata paramsAfter
    ) public payable {
        for (uint i; i < paramsBefore.length; ++i) {
            processCall(paramsBefore[i], i);
        }

        Multipool(poolAddress).swap(
            swapArgs.fpSharePrice, swapArgs.selectedAssets, swapArgs.isSleepageReverse, swapArgs.to, swapArgs.refundTo
        );

        for (uint i; i < paramsAfter.length; ++i) {
            processCall(paramsAfter[i], i);
        }
    }
}
