// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IPriceAdapter {
    /// @notice Common interface for extracting prices from external sources
    /// @dev Used to safe multipool contract spece and to be able to easily change price logic if
    /// needed
    /// @param feedId Identifier of price feed that is used to specify price origin
    /// @return price value is represented as a Q96 value
    function getPrice(uint feedId) external view returns (uint price);
}
