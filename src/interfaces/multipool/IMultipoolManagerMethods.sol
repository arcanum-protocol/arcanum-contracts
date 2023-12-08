// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FeedInfo, FeedType} from "../../lib/Price.sol";

/// @title Interface that contains all multipool owner methods
interface IMultipoolManagerMethods {
    /// @notice Updates price feeds for multiple tokens.
    /// @param assetAddresses Addresses of assets for wich to update feeds
    /// @param kinds Price feed extraction strategy type
    /// @param feedData Data with encoded payload for price extraction
    /// @dev Values in each of these arrays should match with indexes (e.g. index 1 contains all
    /// data for asset 1)
    function updatePrices(
        address[] calldata assetAddresses,
        FeedType[] calldata kinds,
        bytes[] calldata feedData
    )
        external;

    /// @notice Updates target shares for multiple tokens.
    /// @param assetAddresses Addresses of assets for wich to update target shares
    /// @param targetShares Share values to update to
    /// @dev Values in each of these arrays should match with indexes (e.g. index 1 contains all
    /// data for asset 1)
    function updateTargetShares(
        address[] calldata assetAddresses,
        uint[] calldata targetShares
    )
        external;

    /// @notice Method that allows to withdraw collected to owner fees. May be only called by owner
    /// @param to Address to wich to transfer collected fees
    /// @return fees withdrawn native token value
    /// @dev Sends all collected values at once
    function withdrawFees(address to) external returns (uint fees);

    /// @notice Method that allows to withdraw developer fees from contract
    /// @return fees withdrawn native token value
    /// @dev Can be invoked by anyone but is still safe as recepient is always developer address
    function withdrawDeveloperFees() external returns (uint fees);

    /// @notice Method that stops or launches contract. Used in case of freezing (e.g hacks or
    /// temprorary stopping contract)
    function togglePause() external;

    /// @notice Method to change fee charging rules. All ratios are Q32 values.
    /// @param newDeveloperAddress address to send arcanum protocol development and maintaince fees
    /// @param newHalfDeviationFee curve parameter that is a fee ratio at the half of the curve
    /// @param newDeviationLimit curve parameter that shows maximum deviation changes that may be
    /// made
    /// by callers
    /// @param newDepegBaseFee parameter that shows ratio of value taken from deviation fee as base
    /// fee
    /// @param newBaseFee parameter that shows ratio of value taken from each operation quote value
    /// @param newDeveloperBaseFee parameter that shows ratio of value that is taken from base fee
    /// share for arcanum protocol developers and maintainers
    /// @dev Remember to always update every value as this function overrides all variables
    function setFeeParams(
        uint64 newDeviationLimit,
        uint64 newHalfDeviationFee,
        uint64 newDepegBaseFee,
        uint64 newBaseFee,
        uint64 newDeveloperBaseFee,
        address newDeveloperAddress
    )
        external;

    /// @notice This method allows to chenge time for wich force pushed share price is valid
    /// @param newValidityDuration New interval in seconds
    /// @dev Called only by owner. This mechanism allow you to manage price volatility by changing
    /// valid price timeframes
    function setSharePriceValidityDuration(uint128 newValidityDuration) external;

    /// @notice Method that changes permissions of accounts
    /// @param authority address whos permissions change
    /// @param forcePushSettlement allows to sign force push data if true
    /// @param targetShareSettlement allows to change target share if true
    /// @dev Remember to always update every value as this function overrides all variables
    function setAuthorityRights(
        address authority,
        bool forcePushSettlement,
        bool targetShareSettlement
    )
        external;
}
