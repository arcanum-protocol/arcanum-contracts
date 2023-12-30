// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {FeedInfo} from "../../lib/Price.sol";
import {MpAsset} from "../../lib/MpContext.sol";
import {ForcePushArgs, AssetArgs} from "../../types/SwapArgs.sol";

/// @title Interface that contains all multipool public methods
interface IMultipoolMethods {
    /// @notice Gets several share prive params
    /// @return _sharePriceValidityDuration Time in seconds for signed share price to be valid
    /// @return _initialSharePrice Price that is used when contract's total supply is zero
    /// @return _signatureThreshold Minimal signature number required for force push price verification
    /// @dev Fetches data by reading a single slot
    function getSharePriceParams()
        external
        view
        returns (uint128 _sharePriceValidityDuration, uint128 _initialSharePrice, uint _signatureThreshold);

    /// @notice Gets price feed data
    /// @param asset Asset for wich to get price feed
    /// @return priceFeed Returns price feed data
    function getPriceFeed(address asset) external view returns (FeedInfo memory priceFeed);

    /// @notice Gets current asset price
    /// @param asset Asset for wich to get price
    /// @return price Returns price data in a format of Q96 decimal value
    function getPrice(address asset) external view returns (uint price);

    /// @notice Gets fee params from state. All ratios are Q32 values.
    /// @return _deviationParam Curve parameter that is a fee ratio at the half of the curve divided
    /// by deviation limit
    /// @return _deviationLimit Curve parameter that shows maximum deviation changes that may be
    /// made by callers
    /// @return _depegBaseFee Parameter that shows ratio of value taken from deviation fee as base
    /// @return _baseFee Parameter that shows ratio of value taken from each operation quote value
    /// fee
    /// @return _developerBaseFee Parameter that shows ratio of value that is taken from base fee
    /// @return _developerAddress Address to send arcanum protocol development and maintaince fees
    /// share for arcanum protocol developers and maintainers
    /// @dev Fetches data by reading a single slot for first integers
    function getFeeParams()
        external
        view
        returns (
            uint64 _deviationParam,
            uint64 _deviationLimit,
            uint64 _depegBaseFee,
            uint64 _baseFee,
            uint64 _developerBaseFee,
            address _developerAddress
        );

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
    function swap(
        ForcePushArgs calldata forcePushArgs,
        AssetArgs[] calldata assetsToSwap,
        bool isExactInput,
        address receiverAddress,
        bool refundEthToReceiver,
        address refundAddress
    )
        external
        payable;

    /// @notice Method that dry runs swap execution and provides estimated fees and amounts
    /// @param forcePushArgs Arguments for share price force push
    /// @param assetsToSwap Assets that will be used as input or output and their amounts. Assets
    /// should be provided ascendingly sorted by addresses. Can't accept duplicates of assets
    /// @param isExactInput Shows sleepage direction. If is true input amouns (that are greater than
    /// zero) will be used and the output amounts will be estmated proportionally. If false it
    /// behaves reversed
    /// @return fee Native token amount to cover swap fees
    /// @dev To avoid calculation errors don't provide small values to amount
    function checkSwap(
        ForcePushArgs calldata forcePushArgs,
        AssetArgs[] calldata assetsToSwap,
        bool isExactInput
    )
        external
        view
        returns (int fee, int[] memory amounts);

    /// @notice Method that dry runs swap execution and provides estimated fees and amounts
    /// @param assetAddress Address of asset selected to increase its cashback
    /// @return amount Native token amount that was put into cashback
    /// @dev Method is permissionless so anyone can boos incentives. Native token value can be
    /// transferred directly if used iva contract or via msg.value with any method
    function increaseCashback(address assetAddress) external payable returns (uint128 amount);
}
