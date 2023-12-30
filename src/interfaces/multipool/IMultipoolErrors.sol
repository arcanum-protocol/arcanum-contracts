// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FeedInfo} from "../../lib/Price.sol";

/// @title Interface that contains all multipool events
interface IMultipoolErrors {
    /// @notice Thrown when force push signature verification fails
    error InvalidForcePushAuthority();

    /// @notice Thrown when target share change initiator is invalid
    error InvalidTargetShareAuthority();

    /// @notice Thrown when force push signature verification fails
    /// @param blockTimestamp current block timestamp
    /// @param priceTimestamp signed with price timestamp
    error ForcePushPriceExpired(uint blockTimestamp, uint priceTimestamp);

    /// @notice Thrown when zero amount supplied for any asset token
    error ZeroAmountSupplied();

    /// @notice Thrown when supplied amount is less than required for swap
    /// @param asset asset who's balance is invalid
    error InsufficientBalance(address asset);

    /// @notice Thrown when sleepage check for some asset failed
    error SleepageExceeded();

    /// @notice Thrown when supplied assets have duplicates or are not sorted ascending
    error AssetsNotSortedOrNotUnique();

    /// @notice Thrown when contract is paused
    error IsPaused();

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

    /// @notice Is thrown if the number of signatures is lower than threshold
    error InvalidForcePushSignatureNumber();

    /// @notice Is thrown if same force push signature is passed twice
    error SignaturesNotSortedOrNotUnique();
}
