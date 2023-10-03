// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Multipool, MpAsset as UintMpAsset, MpContext as UintMpContext} from "./Multipool.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import {IMetaAggregationRouterV2} from "../interfaces/KyberSwapRouter.sol";

contract MultipoolMassiveMintRouter {
    constructor() {}

    function massiveMint(
        address poolAddress,
        address swapRouterAddress,
        IMetaAggregationRouterV2.SwapExecutionParams[] calldata paths,
        address[] calldata multipoolAddresses,
        address to
    ) public {
        for (uint i = 0; i < paths.length; i++) {
            IMetaAggregationRouterV2(swapRouterAddress).swap(paths[i]);
        }

        Multipool(poolAddress).massiveMint(multipoolAddresses, to);
    }
}
