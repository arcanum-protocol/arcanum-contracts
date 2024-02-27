// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little defi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {MpAsset, MpContext} from "../lib/MpContext.sol";
import {FeedInfo, FeedType} from "../lib/Price.sol";

import {IMultipoolManagerMethods} from "../interfaces/multipool/IMultipoolManagerMethods.sol";
import {IMultipoolMethods} from "../interfaces/multipool/IMultipoolMethods.sol";
import {IMultipool} from "../interfaces/IMultipool.sol";

import {ForcePushArgs, AssetArgs} from "../types/SwapArgs.sol";

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

    mapping(uint => address) public multipools;
    uint public multipoolNumber;
    address public implementationAddress;

    event MultipoolSpawned(address indexed, uint number);

    function updateImplementationAddress(address newImplementationAddress) external onlyOwner {
        implementationAddress = newImplementationAddress;
    }

    struct MultipoolSetupArgs {
        string name;
        string symbol;
        uint signatureThershold;
        uint128 sharePriceValidity;
        uint128 initialSharePrice;
        uint64 deviationLimit;
        uint64 halfDeviationFee;
        uint64 depegBaseFee;
        uint64 baseFee;
        uint64 developerBaseFee;
        address developerAddress;
        address[] oracleAddresses;
        address[] assetAddresses;
        FeedType[] priceFeedKinds;
        bytes[] feedData;
        uint[] targetShares;
    }

    function spawnMultipool(MultipoolSetupArgs calldata args) external {
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementationAddress), "");
        Multipool mp = Multipool(address(proxy));

        mp.initialize(args.name, args.symbol, args.initialSharePrice);

        mp.setAuthorityRights(address(this), true, true);

        mp.setAuthorityRights(msg.sender, false, true);
        mp.setSharePriceParams(args.sharePriceValidity, args.signatureThershold);
        for (uint i = 0; i < args.oracleAddresses.length; ++i) {
            mp.setAuthorityRights(args.oracleAddresses[i], true, false);
        }

        mp.setFeeParams(
            args.deviationLimit,
            args.halfDeviationFee,
            args.depegBaseFee,
            args.baseFee,
            args.developerBaseFee,
            args.developerAddress
        );

        mp.updateTargetShares(args.assetAddresses, args.targetShares);
        mp.updatePrices(args.assetAddresses, args.priceFeedKinds, args.feedData);

        mp.setAuthorityRights(address(this), false, false);
        mp.transferOwnership(msg.sender);

        uint multipoolIndex = multipoolNumber;

        multipools[multipoolIndex] = address(mp);

        emit MultipoolSpawned(address(mp), multipoolIndex);

        multipoolNumber = (multipoolIndex + 1);
    }
}
