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

    // function massiveMint(
    //     address poolAddress,
    //     address tokenFrom,
    //     uint amount,
    //     uint minShareOut,
    //     CallParams[] calldata params,
    //     address[] calldata multipoolAddresses,
    //     address to
    // ) public payable nonReentrant {
    //     IERC20(tokenFrom).transferFrom(msg.sender, address(this), amount);
    //     for (uint i = 0; i < params.length; i++) {
    //         require(isContractAllowedToCall[params[i].target], "MULTIPOOL_MASS_ROUTER: IA");
    //         (bool success,) = params[i].target.call{value: params[i].ethValue}(params[i].targetData);
    //         require(success, "MULTIPOOL_MASS_ROUTER: CF");
    //     }
    //     uint share = Multipool(poolAddress).massiveMint(multipoolAddresses, to);
    //     require(minShareOut <= share, "MULTIPOOL_MASS_ROUTER: SE");
    // }

    struct SwapArgs {
        Multipool.FPSharePriceArg fpSharePrice;
        Multipool.AssetArg[] selectedAssets;
        bool isSleepageReverse;
        address to;
        bool refundDust;
        address refundTo;
    }

    function swap(
        address poolAddress,
        SwapArgs calldata swapArgs,
        Call[] calldata paramsBefore,
        Call[] calldata paramsAfter
    ) public {
        for (uint i; i < paramsBefore.length; ++i) {
            if (paramsBefore[i].callType == CallType.ANY) {
                CallParams memory params = abi.decode(paramsBefore[i].data, (CallParams));
                require(isContractAllowedToCall[params.target], "IA");
                (bool success,) = params.target.call{value: params.ethValue}(params.targetData);
                require(success, "CF");
            } else if (paramsBefore[i].callType == CallType.ERC20Transfer) {
                TokenTransferParams memory params = abi.decode(paramsBefore[i].data, (TokenTransferParams));
                IERC20(params.token).transferFrom(msg.sender, params.targetOrOrigin, params.amount);
            } else if (paramsBefore[i].callType == CallType.ERC20Approve) {
                RouterApproveParams memory params = abi.decode(paramsBefore[i].data, (RouterApproveParams));
                require(isContractAllowedToCall[params.target], "IA");
                IERC20(params.token).approve(params.target, params.amount);
            }
        }

        for (uint i; i < swapArgs.selectedAssets.length; ++i) {
            if (swapArgs.selectedAssets[i].amount > 0) {
                IERC20(swapArgs.selectedAssets[i].addr).transferFrom(
                    msg.sender, poolAddress, uint(swapArgs.selectedAssets[i].amount)
                );
            }
        }
        Multipool(poolAddress).swap(
            swapArgs.fpSharePrice,
            swapArgs.selectedAssets,
            swapArgs.isSleepageReverse,
            swapArgs.to,
            swapArgs.refundDust,
            swapArgs.refundTo
        );

        for (uint i; i < paramsAfter.length; ++i) {
            if (paramsAfter[i].callType == CallType.ANY) {
                CallParams memory params = abi.decode(paramsAfter[i].data, (CallParams));
                require(isContractAllowedToCall[params.target], "IA");
                (bool success,) = params.target.call{value: params.ethValue}(params.targetData);
                require(success, "CF");
            } else if (paramsAfter[i].callType == CallType.ERC20Transfer) {
                TokenTransferParams memory params = abi.decode(paramsAfter[i].data, (TokenTransferParams));
                IERC20(params.token).transferFrom(address(this), params.targetOrOrigin, params.amount);
            }
        }
    }
}
