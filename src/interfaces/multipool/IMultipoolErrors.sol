// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/// @title Interface that contains all multipool events
interface IMultipoolErrors {
    /// @notice Thrown when target share change initiator is invalid
    error AssetsAreSame();

    /// @notice Thrown when management fee receiver authority is invalid
    error NotManagerFeeReceiver();

    /// @notice Thrown when lp fee receiver authority is invalid
    error NotLpFeeReceiver();

    /// @notice Thrown when target share change initiator is invalid
    error InvalidTargetShareAuthority();

    /// @notice Thrown when zero amount supplied for any asset token
    error ZeroAmountSupplied();

    /// @notice Thrown when supplied amount is less than required for swap
    /// @param asset asset who's balance is invalid
    error InsufficientBalance(address asset);

    /// @notice Thrown when sleepage check for some asset failed
    error SleepageExceeded();

    /// @notice Thrown when supplied native token value for fee expired
    error FeeExceeded();

    /// @notice Thrown when any asset's deviation after operation grows and exceeds deviation limit
    error DeviationExceedsLimit();

    /// @notice Thrown when contract has less balance of token than is requested for burn
    error NotEnoughQuantityToBurn();

    /// @notice Is thrown if price feed data is unset
    error NoPriceOriginSet();

    /// @notice Is thrown if uniswap v3 twap price fetching resulted in error that was not "OLD"
    error UniV3PriceFetchingReverted();

    /// @notice Is thrown if you are trying to increase the deviation while target share is set to 0
    error TargetShareIsZero();
}
