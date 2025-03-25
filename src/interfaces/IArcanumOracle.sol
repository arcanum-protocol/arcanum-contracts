// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {OraclePrice} from "../types/OraclePrice.sol";

/// @title Interface that contains all multipool events
interface IArcanumOracle {
    /// @notice Thrown when force push signed contract address doesn't match msg.sender
    error InvalidSender();

    /// @notice Thrown when force push signature verification fails
    error InvalidForcePushAuthority(address decoded, address required);

    /// @notice Thrown when force push signature verification fails
    /// @param blockTimestamp current block timestamp
    /// @param priceTimestamp signed with price timestamp
    error ForcePushPriceExpired(uint blockTimestamp, uint priceTimestamp);

    /// @notice Method that dry runs swap execution and provides estimated fees and amounts
    /// @param oraclePrice Address of asset selected to increase its cashback
    /// @dev Method is permissionless so anyone can boos incentives. Native token value can be
    /// transferred directly if used iva contract or via msg.value with any method
    function commitPrice(OraclePrice calldata oraclePrice) external payable;
}
