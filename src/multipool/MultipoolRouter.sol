// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Multipool} from "./Multipool.sol";
import {MultipoolCreationParams, MultipoolFactory} from "./Factory.sol";
import {OraclePrice} from "../types/OraclePrice.sol";
import {ReceiverData} from "../types/ReceiverData.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

interface WETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
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

struct SwapArgs {
    OraclePrice oraclePrice;
    address assetIn;
    address assetOut;
    uint swapAmount;
    bool isExactInput;
    ReceiverData receiverData;
    uint ethValue;
}

contract MultipoolRouter is Ownable {
    constructor(address _factory) {
        factory = _factory;
    }

    address public factory;

    mapping(address => bool) isContractAllowedToCall;

    function toggleContract(address contractAddress) public onlyOwner {
        isContractAllowedToCall[contractAddress] = !isContractAllowedToCall[contractAddress];
    }

    error CallFailed(uint callNumber, bool isPredecessing);
    error InsufficientEthBalance(uint callNumber, bool isPredecessing);
    error InsufficientEthBalanceCallingSwap();
    error ContractCallNotAllowed(address target);

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
        Call[] calldata callsBefore,
        Call[] calldata callsAfter
    )
        external
        payable
    {
        for (uint i; i < callsBefore.length; ++i) {
            processCall(callsBefore[i], i, true);
        }

        if (address(this).balance < swapArgs.ethValue) revert InsufficientEthBalanceCallingSwap();
        Multipool(poolAddress).swap{value: swapArgs.ethValue}(
            swapArgs.oraclePrice,
            swapArgs.assetIn,
            swapArgs.assetOut,
            swapArgs.swapAmount,
            swapArgs.isExactInput,
            swapArgs.receiverData
        );

        for (uint i; i < callsAfter.length; ++i) {
            processCall(callsAfter[i], i, false);
        }
    }

    function createMultipool(
        MultipoolCreationParams calldata creationParams,
        Call[] calldata callsBefore,
        Call[] calldata callsAfter
    )
        external
        payable
    {
        for (uint i; i < callsBefore.length; ++i) {
            processCall(callsBefore[i], i, true);
        }
        MultipoolFactory(factory).createMultipool(creationParams);
        for (uint i; i < callsAfter.length; ++i) {
            processCall(callsAfter[i], i, false);
        }
    }
}
