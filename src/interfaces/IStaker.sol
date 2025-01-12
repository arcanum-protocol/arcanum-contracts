// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ForcePushArgs} from "../types/SwapArgs.sol";

/// @title Interface that contains all multipool events
interface IStaker {
    /// @notice Thrown when force push signed contract address doesn't match msg.sender
    error InvalidSender();

    /// @notice Thrown when force push signature verification fails
    error InvalidForcePushAuthority();

    /// @notice Thrown when force push signature verification fails
    /// @param blockTimestamp current block timestamp
    /// @param priceTimestamp signed with price timestamp
    error ForcePushPriceExpired(uint blockTimestamp, uint priceTimestamp);

    /// @notice Method that dry runs swap execution and provides estimated fees and amounts
    /// @param signedPrice Address of asset selected to increase its cashback
    /// @dev Method is permissionless so anyone can boos incentives. Native token value can be
    /// transferred directly if used iva contract or via msg.value with any method
    function commitPrice(ForcePushArgs calldata signedPrice) external payable;
}
