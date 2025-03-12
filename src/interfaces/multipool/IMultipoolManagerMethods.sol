// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FeedType} from "../../lib/Price.sol";

/// @title Interface that contains all multipool owner methods
interface IMultipoolManagerMethods {
    /// @notice Updates price feeds for multiple tokens.
    /// @param assetAddresses Addresses of assets for wich to update feeds
    /// @param priceData Packed data of price feed
    /// @dev Values in each of these arrays should match with indexes (e.g. index 1 contains all
    /// data for asset 1)
    function updatePrices(
        address[] calldata assetAddresses,
        bytes32[] calldata priceData
    )
        external;

    /// @notice Updates target shares for multiple tokens.
    /// @param assetAddresses Addresses of assets for wich to update target shares
    /// @param targetShares Share values to update to
    /// @dev Values in each of these arrays should match with indexes (e.g. index 1 contains all
    /// data for asset 1)
    function updateTargetShares(
        address[] calldata assetAddresses,
        uint16[] calldata targetShares
    )
        external;

    /// @notice Method to change fee charging rules. All ratios are Q32 values.
    /// @notice Emitted when fee charging params change. All ratios are Q32 values.
    /// @param newDeviationIncreaseFee fee charged when deviation is increased
    /// @param newDeviationLimit curve parameter determines what is the maximum deviation possible
    /// to create by swap
    /// @param newFeeToCashbackRatio ratio or fees taken by cashbacks
    /// @param newBaseFee fee ratio taken from any swap action
    /// @param newManagementFee management fee ratio
    /// @param newManagementFeeRecepient receiver of management fee
    /// @dev Remember to always update every value as this function overrides all variables
    function setFeeParams(
        uint16 newDeviationIncreaseFee,
        uint16 newDeviationLimit,
        uint16 newFeeToCashbackRatio,
        uint16 newBaseFee,
        address newManagementFeeRecepient,
        uint16 newManagementFee
    )
        external;

    /// @notice Method that enable account to be strategy manager
    /// @param authority address whos permissions change
    function updateStrategyManager(address authority) external;

    /// @notice Method that updates price verifier address
    /// @param _priceVerifierAddress address of new price verifier
    function updateOracleAddress(address _priceVerifierAddress) external;
}
