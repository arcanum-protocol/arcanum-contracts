// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {MpAsset} from "../../lib/MpContext.sol";
import {ForcePushArgs, AssetArgs} from "../../types/SwapArgs.sol";

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

    /// @notice Method that executes every trading in multipool
    /// @param forcePushArgs Arguments for share price force push
    /// @param assetsToSwap Assets that will be used as input or output and their amounts. Assets
    /// should be provided ascendingly sorted by addresses. Can't accept duplicates of assets
    /// @param isExactInput Shows sleepage direction. If is true input amouns (that are greater than
    /// zero) will be used exactly and output amounts (less than zero) will be used as slippage
    /// checks. If false it is reversed
    /// @param receiverAddress Address that will receive output amounts
    /// @param refundEthToReceiver If this value is true, left ether will be sent to
    /// `receiverAddress`, else, `refundAddress` will be used
    /// @param refundAddress Address that will be used to receive left input token and native token
    /// balances
    /// @dev This is a low level method that works via direct token transfer on contract and method
    /// execution. Should be used in other contracts only
    /// Fees are charged in native token equivalend via transferring them before invocation or in
    /// msg.value
  //  function swap(
  //      ForcePushArgs calldata forcePushArgs,
  //      AssetArgs[] calldata assetsToSwap,
  //      bool isExactInput,
  //      address receiverAddress,
  //      bool refundEthToReceiver,
  //      address refundAddress
  //  )
  //      external
  //      payable;

    /// @notice Method that dry runs swap execution and provides estimated fees and amounts
    /// @param forcePushArgs Arguments for share price force push
    /// @param assetsToSwap Assets that will be used as input or output and their amounts. Assets
    /// should be provided ascendingly sorted by addresses. Can't accept duplicates of assets
    /// @param isExactInput Shows sleepage direction. If is true input amouns (that are greater than
    /// zero) will be used and the output amounts will be estmated proportionally. If false it
    /// behaves reversed
    /// @return fee Native token amount to cover swap fees
    /// @dev To avoid calculation errors don't provide small values to amount
  //  function checkSwap(
  //      ForcePushArgs calldata forcePushArgs,
  //      AssetArgs[] calldata assetsToSwap,
  //      bool isExactInput
  //  )
  //      external
  //      view
  //      returns (int fee, int[] memory amounts);

    /// @notice Method that increases cashback for a specific asset
    /// @param assetAddress Address of asset selected to increase its cashback
    /// @dev Method is permissionless so anyone can boost incentives. Native token value can be
    /// transferred directly if used iva contract or via msg.value with any method
    function increaseCashback(address assetAddress) external payable;
}
