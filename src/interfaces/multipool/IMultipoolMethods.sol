// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {MpAsset} from "../../lib/MpContext.sol";
import {OraclePrice} from "../../types/OraclePrice.sol";
import {ReceiverData} from "../../types/ReceiverData.sol";

/// @title Interface that contains all multipool public methods
interface IMultipoolMethods {
    /// @notice Gets price feed data
    /// @param asset Asset for wich to get price feed
    /// @return priceFeed Returns price feed data
    function getPriceFeed(address asset) external view returns (bytes32 priceFeed);

    /// @notice Gets current asset price
    /// @param asset Asset for wich to get price
    /// @return price Returns price data in a format of Q96 decimal value
    function getPrice(address asset) external view returns (uint price);

    /// @notice Gets asset related info
    /// @param assetAddress address of asset wich data to provide
    /// @dev Reads exacly two storage slots
    function getAsset(address assetAddress) external view returns (bool isUsed, uint quantity, uint collectedCashback, uint targetShare);

    /// @notice Method that executes every trading in multipool, minting and burning is
    /// reached by setting in or out address as multipool's address
    /// @param oraclePrice Arguments for share price force push
    /// @param assetInAddress Asset that is deposited into pool
    /// @param assetOutAddress Asset that is received from pool
    /// @param isExactInput if true - swap amount is specified as amount in, if false - as amount
    /// out
    /// @dev This is a low level method that works via direct token transfer on contract and method
    /// execution. Should be used in other contracts only
    /// Fees are charged in native token equivalend via transferring them before invocation or in
    /// msg.value
    function swap(
        OraclePrice calldata oraclePrice,
        address assetInAddress,
        address assetOutAddress,
        uint swapAmount,
        bool isExactInput,
        address receiverAddress,
        address refundAddress,
        bool refundEthToReceiver
    )
        external
        payable
        returns (uint amountIn, uint amountOut);

    /// @notice Method that increases cashback for a specific asset
    /// @param assetAddress Address of asset selected to increase its cashback
    /// @dev Method is permissionless so anyone can boost incentives. Native token value can be
    /// transferred directly if used iva contract or via msg.value with any method
    function increaseCashback(address assetAddress) external payable;

    /// @notice Method that returns ever used tokens in etf by limit and offset.
    /// @param limit The amount of addresses to query
    /// @param offset The index to query from
    function getUsedAssets(
        uint limit,
        uint offset
    )
        external
        view
        returns (address[] memory assetsRes, uint length);

    /// @notice Method that returns price of Multipool share
    /// @param limit The amount of addresses to query
    /// @param offset The index to query from
    function getSharePricePart(uint limit, uint offset) external view returns (uint pricePart);
}
