// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {Multipool, IERC20, OraclePrice} from "./Multipool.sol";
import {ReceiverData} from "../types/ReceiverData.sol";

struct MultipoolCreationParams {
    string name;
    string symbol;
    uint96 initialSharePrice;
    uint16 deviationIncreaseFee;
    uint16 deviationLimit;
    uint16 feeToCashbackRatio;
    uint16 baseFee;
    address managementFeeRecepient;
    uint16 managementFee;
    address oracleAddress;
    address strategyManager;
    address[] assetAddresses;
    bytes32[] priceData;
    uint16[] targetShares;
    address initialLiquidityAsset;
}

/// @custom:security-contact badconfig@arcanum.to
contract MultipoolFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address implementation) public initializer {
        __Ownable_init();
        transferOwnership(owner);
        implementationAddress = implementation;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    address public implementationAddress;

    event MultipoolCreated(address indexed);

    function updateImplementationAddress(address newImplementationAddress) external onlyOwner {
        implementationAddress = newImplementationAddress;
    }

    ///@dev it's important to remember: if this function is used with no initial liquidity
    /// It's safe to use it directly, otherwhise use it through router
    function createMultipool(MultipoolCreationParams calldata params)
        external
        payable
        returns (Multipool mp)
    {
        address _implementationAddress = implementationAddress;

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(_implementationAddress),
            abi.encodeWithSignature(
                "initialize(string,string,address,uint96)",
                params.name,
                params.symbol,
                params.oracleAddress,
                params.initialSharePrice
            )
        );
        mp = Multipool(address(proxy));

        mp.updateTargetShares(params.assetAddresses, params.targetShares);

        mp.updatePrices(params.assetAddresses, params.priceData);

        if (params.strategyManager != address(0)) {
            mp.updateStrategyManager(params.strategyManager);
        }

        if (params.initialLiquidityAsset != address(0)) {
            // Not needed for initial mint, so it's empty
            OraclePrice memory oraclePrice;
            mp.swap{value: msg.value}(
                oraclePrice,
                params.initialLiquidityAsset,
                address(mp),
                IERC20(params.initialLiquidityAsset).balanceOf(address(mp)),
                true,
                ReceiverData({
                    refundAddress: address(0),
                    receiverAddress: msg.sender,
                    refundEthToReceiver: true
                })
            );
        }

        mp.setFeeParams(
            params.deviationIncreaseFee,
            params.deviationLimit,
            params.feeToCashbackRatio,
            params.baseFee,
            params.managementFeeRecepient,
            params.managementFee
        );

        mp.transferOwnership(msg.sender);

        emit MultipoolCreated(address(mp));
    }
}
