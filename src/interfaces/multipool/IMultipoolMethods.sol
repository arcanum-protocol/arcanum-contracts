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
    /// @return asset asset related data structure
    /// @dev Reads exacly two storage slots
    function getAsset(address assetAddress) external view returns (MpAsset memory asset);

    /// @notice Method that executes every trading in multipool, minting and burning is
    /// reached by setting in or out address as multipool's address
    /// @param oraclePrice Arguments for share price force push
    /// @param assetInAddress Asset that is deposited into pool
    /// @param assetOutAddress Asset that is received from pool
    /// @param isExactInput if true - swap amount is specified as amount in, if false - as amount out
    /// @param data Arguments with return data
    /// `receiverAddress`, else, `msg.sender` will be used
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
        ReceiverData calldata data
    )
        external
        payable 
        returns (uint amountIn, uint amountOut);

    /// @notice Method that increases cashback for a specific asset
    /// @param assetAddress Address of asset selected to increase its cashback
    /// @dev Method is permissionless so anyone can boost incentives. Native token value can be
    /// transferred directly if used iva contract or via msg.value with any method
    function increaseCashback(address assetAddress) external payable;
}
