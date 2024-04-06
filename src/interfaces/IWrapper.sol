// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IWrapper {
    /// @notice Common interface for wrapping assets
    /// @dev Used to do mints in router and trader
    /// @param baseAmount amount of base token to use
    /// @param to where to send tokens
    /// @return wrappedAmount used wrappedAmount
    function wrap(
        uint baseAmount,
        address to,
        bytes calldata data
    )
        external
        returns (uint wrappedAmount);

    /// @notice Common interface for wrapping assets
    /// @dev Used to do burns in router and trader
    /// @param wrappedAmount amount of wrapped token to use
    /// @param to where to send tokens
    /// @return baseAmount used baseAmount
    function unwrap(
        uint wrappedAmount,
        address to,
        bytes calldata data
    )
        external
        returns (uint baseAmount);
}
