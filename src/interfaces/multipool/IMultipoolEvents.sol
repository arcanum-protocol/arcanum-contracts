// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/// @title Interface that contains all multipool events
interface IMultipoolEvents {
    /// @notice Thrown right after pool is initialised
    /// @param initialSharePrice assets initial share price that can't be changed
    event PoolCreated(uint96 initialSharePrice);

    /// @notice Emitted when any quantity or cashback change happens even for multipool share
    /// @param asset address of changed assets (address(this) for multipool)
    /// @param quantity absolute value of new stored quantity
    /// @param price asset price
    /// @param collectedCashbacks absolute value of new cashbacks (always 0 for multipool)
    event AssetChange(address indexed asset, uint128 quantity, uint price, uint128 collectedCashbacks);

    /// @notice Emitted when fee charging params change. All ratios are Q32 values.
    /// @param newDeviationIncreaseFee fee charged when deviation is increased
    /// @param newDeviationLimit curve parameter determines what is the maximum deviation possible
    /// to create by swap
    /// @param newFeeToCashbackRatio ratio or fees taken by cashbacks
    /// @param newBaseFee fee ratio taken from any swap action
    /// @param newManagementFee management fee ratio
    /// @param newManagementFeeRecepient receiver of management fee
    event FeesChange(
        uint16 newDeviationIncreaseFee,
        uint16 newDeviationLimit,
        uint16 newFeeToCashbackRatio,
        uint16 newBaseFee,
        uint16 newManagementFee,
        address newManagementFeeRecepient
    );

    /// @notice Thrown when target share of any asset got updated
    /// @param asset changed target share address asset
    /// @param newTargetShare absolute value of updated target share
    /// @param newTotalTargetShares absolute value of new sum of all target shares
    event TargetShareChange(
        address indexed asset, uint16 newTargetShare, uint16 newTotalTargetShares
    );

    /// @notice Thrown when price feed for an asset got updated
    /// @param targetAsset address of asset wich price feed data is changed
    /// @param newFeed updated price feed data
    event PriceFeedChange(address indexed targetAsset, bytes32 newFeed);

    /// @notice Thrown when permissions of authorities were changed per each authority.
    /// event provides addresses new permissions
    /// @param oldStrategyManager address of old authority
    /// @param newStrategyManager address of new authority
    event StrategyManagerChange(
        address indexed oldStrategyManager, address indexed newStrategyManager
    );

    /// @notice Thrown every time new fee gets collected
    /// @param sender the address that invoked the trade
    /// @param assetIn token that beed sent
    /// @param assetOut token that been received
    /// @param amountIn the amount token in sent to pool
    /// @param amountOut the amount token out received from pool
    /// @param collectedManagementFees shows how much fees are earned for manager
    /// @param collectedOracleFees shows how much fees are earned for oracle
    event Swap(
        address indexed sender,
        address indexed assetIn,
        address indexed assetOut,
        uint amountIn,
        uint amountOut,
        uint collectedManagementFees,
        uint collectedOracleFees
    );

    /// @notice Thrown when price verifier is updated.
    /// @param oldOracle address of old price verifier contract
    /// @param newOracle address of new price verifier contract
    event PriceOracleUpdated(address oldOracle, address newOracle);
}
