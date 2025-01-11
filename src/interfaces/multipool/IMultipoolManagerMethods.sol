// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FeedInfo, FeedType} from "../../lib/Price.sol";

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
    /// @param newManagementFeeRecepientAddress address to send management fees to
    /// @param newDeviationLimit curve parameter determines fee in middle of deviation limit
    /// @param newDeviationLimit curve parameter that shows maximum deviation changes that may be made
    /// by callers
    /// @param newDepegBaseFee parameter that shows ratio of value taken from deviation fee as base fee
    /// @param newBaseFee parameter that shows ratio of value taken from each operation quote value
    /// @param newManagementFee parameter that shows ratio of value that is taken from base fee
    /// as management fee
    /// @dev Remember to always update every value as this function overrides all variables
    function setFeeParams(
        uint16 newDeviationLimit,
        uint16 newHalfDeviationFee,
        uint16 newDepegBaseFee,
        uint16 newBaseFee,
        uint16 newManagementFee,
        address newManagementFeeRecepientAddress
    )
        external;

    /// @notice Method that enable account to be strategy manager
    /// @param authority address whos permissions change
    function toggleStrategyManager(
        address authority
    )
        external;

    /// @notice Method that updates price verifier address
    /// @param _priceVerifierAddress address of new price verifier
    function updatePriceVerifierAddress(
        address _priceVerifierAddress
    )
        external;
}
