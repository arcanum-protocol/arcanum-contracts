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
    /// @param newManagementFeeRecepientAddress address to send management fees to
    /// @param newDeviationLimit curve parameter determines fee in middle of deviation limit
    /// @param newDeviationLimit curve parameter that shows maximum deviation changes that may be made
    /// by callers
    /// @param newDepegBaseFee parameter that shows ratio of value taken from deviation fee as base fee
    /// @param newBaseFee parameter that shows ratio of value taken from each operation quote value
    /// @param newManagementFee parameter that shows ratio of value that is taken from base fee
    /// as management fee
    event FeesChange(
        uint16 newDeviationLimit,
        uint16 newHalfDeviationFee,
        uint16 newDepegBaseFee,
        uint16 newBaseFee,
        uint16 newManagementFee,
        address newManagementFeeRecepientAddress
    );

    /// @notice Thrown when target share of any asset got updated
    /// @param asset changed target share address asset
    /// @param newTargetShare absolute value of updated target share
    /// @param newTotalTargetShares absolute value of new sum of all target shares
    event TargetShareChange(address indexed asset, uint newTargetShare, uint newTotalTargetShares);

    /// @notice Thrown when price feed for an asset got updated
    /// @param targetAsset address of asset wich price feed data is changed
    /// @param newFeed updated price feed data
    event PriceFeedChange(address indexed targetAsset, bytes32 newFeed);

    /// @notice Thrown when permissions of authorities were changed per each authority.
    /// event provides addresses new permissions
    /// @param account address of toggled authority
    /// @param isTargetShareAuthority true if is trusted to change target shares for now
    event StrategyManagerToggled(
        address indexed account, bool isTargetShareAuthority
    );

    /// @notice Thrown every time new fee gets collected
    /// @param collectedManagementFees shows how much fees are earned for manager
    /// @param collectedOracleFees shows how much fees are earned for oracle
    event Swapped(uint collectedManagementFees, uint collectedOracleFees);

    /// @notice Thrown when price verifier is updated.
    /// @param oldPriceVerifierAddress address of old price verifier contract
    /// @param newPriceVerifierAddress address of new price verifier contract
    event PriceVerifierUpdated(
        address oldPriceVerifierAddress, address newPriceVerifierAddress
    );
}
