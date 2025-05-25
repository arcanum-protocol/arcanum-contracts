// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/// @title Interface that contains all multipool events
interface IMultipoolEvents {
    /// @notice Emitted when any transfer event is thrown in multipool mirrors ERC20 tranfer event
    /// @param from address of sender (zero if mint)
    /// @param to address of receiver (zero if burn)
    /// @param amount value that was transferred/minted/burned
    event ShareTransfer(address indexed from, address indexed to, uint amount);

    /// @notice Thrown right after owner is changed not to index all ownership changes
    /// @param newOwner new owner of the contract
    event MultipoolOwnerChange(address indexed newOwner);

    /// @notice Emitted when any quantity or cashback change happens even for multipool share
    /// @param asset address of changed assets (address(this) for multipool)
    /// @param quantity absolute value of new stored quantity
    /// @param collectedCashbacks absolute value of new cashbacks (always 0 for multipool)
    event AssetChange(address indexed asset, uint128 quantity, uint112 collectedCashbacks);

    event FeesChange(
        uint24 deviationIncreaseFee,
        uint16 deviationLimit,
        uint24 feeToCashbackRatio,
        uint24 baseFee,
        uint24 managerFee,
        uint24 lpFee,

        address managerFeeReceiver,
        address lpFeeReceiver,
        address oracleAddress
    );

    /// @notice Thrown when target share of any asset got updated
    /// @param asset changed target share address asset
    /// @param newTargetShare absolute value of updated target share
    /// @param newTotalTargetShares absolute value of new sum of all target shares
    event TargetShareChange(address indexed asset, uint16 newTargetShare, uint16 newTotalTargetShares);

    /// @notice Thrown when price feed for an asset got updated
    /// @param targetAsset address of asset wich price feed data is changed
    /// @param newFeed updated price feed data
    event PriceFeedChange(address indexed targetAsset, bytes32 newFeed);

    event Swap(
        address indexed sender,
        address indexed assetIn,
        address indexed assetOut,
        uint128 amountIn,
        uint128 amountOut,
        uint priceIn,
        uint priceOut,
        uint112 collectedManagerFees,
        uint112 collectedLpFees,
        uint112 collectedOracleFees
    );
}
