// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little defi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {MpAsset, MpContext} from "../lib/MpContext.sol";
import {FeedType} from "../lib/Price.sol";

import {IMultipoolManagerMethods} from "../interfaces/multipool/IMultipoolManagerMethods.sol";
import {IMultipoolMethods} from "../interfaces/multipool/IMultipoolMethods.sol";
import {IMultipool} from "../interfaces/IMultipool.sol";

import {OraclePrice} from "../types/OraclePrice.sol";

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import {Multipool} from "./Multipool.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

/// @custom:security-contact badconfig@arcanum.to
contract MultipoolFactory is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address implementation) public initializer {
        __ReentrancyGuard_init();
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

    struct MultipoolSetupArgs {
        string name;
        string symbol;
        uint128 initialSharePrice;

        uint16 deviationIncreaseFee;
        uint16 deviationLimit;
        uint16 feeToCashbackRatio;
        uint16 baseFee;
        address managementFeeRecepient;
        uint16 managementFee;

        address oracleAddress;

        address[] strategyManagers;

        address[] assetAddresses;
        bytes32[] priceData;
        uint16[] targetShares;
    }

    function spawnMultipool(MultipoolSetupArgs calldata args) external {
        address _implementationAddress = implementationAddress;
        uint96 _multipoolsNumber = multipoolsNumber; 

        ERC1967Proxy proxy = new ERC1967Proxy{salt: bytes32(uint(_multipoolsNumber))}(
            address(_implementationAddress), 
            abi.encodeWithSignature(
                "initialize(string,string,address,uint96)", 
                args.name,
                args.symbol,
                args.oracleAddress,
                args.initialSharePrice
            )
        );
        Multipool mp = Multipool(address(proxy));

        mp.setFeeParams(
            args.deviationIncreaseFee,
            args.deviationLimit,
            args.feeToCashbackRatio,
            args.baseFee,
            args.managementFeeRecepient,
            args.managementFee
        );

        mp.updateTargetShares(args.assetAddresses, args.targetShares);
        mp.updatePrices(args.assetAddresses, args.priceData);

        mp.toggleStrategyManager(address(this));
        mp.transferOwnership(msg.sender);

        multipoolsNumber = _multipoolsNumber + 1;
        emit MultipoolCreated(address(mp), _multipoolsNumber);
    }
}
