// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {Multipool} from "./Multipool.sol";

/// @custom:security-contact badconfig@arcanum.to
contract MultipoolFactory is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{

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
    uint96 public multipoolsNumber;

    event MultipoolCreated(address indexed, uint number);

    function updateImplementationAddress(address newImplementationAddress) external onlyOwner {
        implementationAddress = newImplementationAddress;
    }

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
    }

    function createMultipool(MultipoolCreationParams calldata params) external {
        address _implementationAddress = implementationAddress;
        uint96 _multipoolsNumber = multipoolsNumber; 

        ERC1967Proxy proxy = new ERC1967Proxy{salt: bytes32(uint(_multipoolsNumber))}(
            address(_implementationAddress), 
            abi.encodeWithSignature(
                "initialize(string,string,address,uint96)", 
                params.name,
                params.symbol,
                params.oracleAddress,
                params.initialSharePrice
            )
        );
        Multipool mp = Multipool(address(proxy));

        mp.setFeeParams(
            params.deviationIncreaseFee,
            params.deviationLimit,
            params.feeToCashbackRatio,
            params.baseFee,
            params.managementFeeRecepient,
            params.managementFee
        );

        mp.updateTargetShares(params.assetAddresses, params.targetShares);
        mp.updatePrices(params.assetAddresses, params.priceData);

        mp.toggleStrategyManager(address(this));
        if (params.strategyManager != address(0)) {
            mp.toggleStrategyManager(params.strategyManager);
        }

        mp.transferOwnership(msg.sender);

        multipoolsNumber = _multipoolsNumber + 1;
        emit MultipoolCreated(address(mp), _multipoolsNumber);
    }
}
