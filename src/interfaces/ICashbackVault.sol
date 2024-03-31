// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ICashbackVault {
    /// @notice Common interface for cachback vault to release funds
    /// @dev It can be used inside of user transaction for further arbitraging
    /// @param multipool address of multipool that is used
    /// @param assets addresses of assets which cashback is to be released
    /// @return values cachback values that was sent, order same as assets are
    function payCashback(
        address multipool,
        address[] calldata assets
    )
        external
        returns (uint[] memory values);

    /// @notice This event should be thrown thrown every time cashback gets payed
    /// @param multipool address of the multipool contract
    /// @param assets addresses of assets which cashback was released
    /// @param values cachback values that was sent, order same as assets are
    event CashbackPayed(address multipool, address[] assets, uint[] values);
}
