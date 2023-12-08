// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FeedInfo} from "../../lib/Price.sol";

/// @title Interface that contains all multipool events
interface IMultipoolEvents {
    /// @notice Emitted when any quantity or cashback change happens even for multipool share
    /// @param asset address of changed assets (address(this) for multipool)
    /// @param quantity absolute value of new stored quantity
    /// @param collectedCashbacks absolute value of new cashbacks (always 0 for multipool)
    event AssetChange(address indexed asset, uint quantity, uint128 collectedCashbacks);

    /// @notice Emitted when fee charging params change. All ratios are Q32 values.
    /// @param developerAddress address to send arcanum protocol development and maintaince fees
    /// @param deviationParam curve parameter that is a fee ratio at the half of the curve divided
    /// by deviation limit
    /// @param deviationLimit curve parameter that shows maximum deviation changes that may be made
    /// by callers
    /// @param depegBaseFee parameter that shows ratio of value taken from deviation fee as base fee
    /// @param baseFee parameter that shows ratio of value taken from each operation quote value
    /// @param developerBaseFee parameter that shows ratio of value that is taken from base fee
    /// share for arcanum protocol developers and maintainers
    event FeesChange(
        address indexed developerAddress,
        uint64 deviationParam,
        uint64 deviationLimit,
        uint64 depegBaseFee,
        uint64 baseFee,
        uint64 developerBaseFee
    );

    /// @notice Thrown when target share of any asset got updated
    /// @param asset changed target share address asset
    /// @param newTargetShare absolute value of updated target share
    /// @param newTotalTargetShares absolute value of new sum of all target shares
    event TargetShareChange(address indexed asset, uint newTargetShare, uint newTotalTargetShares);

    /// @notice Thrown when price feed for an asset got updated
    /// @param targetAsset address of asset wich price feed data is changed
    /// @param newFeed updated price feed data
    event PriceFeedChange(address indexed targetAsset, FeedInfo newFeed);

    /// @notice Thrown when expiration time for share price force push change
    /// @param validityDuration time in seconds when force push data is valid
    event SharePriceExpirationChange(uint validityDuration);

    /// @notice Thrown when permissions of authorities were changed per each authority.
    /// event provides addresses new permissions
    /// @param account address of toggled authority
    /// @param isForcePushAuthority true if is trused to sign force push price data
    /// @param isTargetShareAuthority true if is trusted to change target shares
    event AuthorityRightsChange(
        address indexed account, bool isForcePushAuthority, bool isTargetShareAuthority
    );

    /// @notice Thrown when contract is paused or unpaused
    /// @param isPaused shows new value of pause
    event PauseChange(bool isPaused);

    /// @notice Thrown every time new fee gets collected
    /// @param totalCollectedBalance shows contracts native token balance which is sum of all fees
    /// and cashbacks
    /// @param totalCollectedCashbacks shows sum of all collected cashbacks
    event CollectedFeesChange(uint totalCollectedBalance, uint totalCollectedCashbacks);
}
