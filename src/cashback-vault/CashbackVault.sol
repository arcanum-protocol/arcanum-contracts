// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Dis guy rly saved tons of eepy assets

import {MpAsset} from "../lib/MpContext.sol";
import {CashbackDistributor} from "../lib/CashbackDistributor.sol";
import {FixedPoint96} from "../lib/FixedPoint96.sol";

import {IMultipool} from "../interfaces/IMultipool.sol";

import {ICashbackVault} from "../interfaces/ICashbackVault.sol";

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact badconfig@arcanum.to
contract CashbackVault is
    ICashbackVault,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        _transferOwnership(owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    error IsPaused();
    error InsufficientAmount();
    error InvalidAsset(address asset);

    mapping(address => CashbackDistributor) internal distributors;
    mapping(address => mapping(address => uint)) internal lastUpdated;
    bool public isPaused;

    modifier notPaused() {
        if (isPaused) revert IsPaused();
        _;
    }

    function getDistrubutor(address distributorAddress)
        external
        view
        returns (CashbackDistributor memory distributor)
    {
        distributor = distributors[distributorAddress];
    }

    function getLastUpdated(
        address distributorAddress,
        address token
    )
        external
        view
        returns (uint lastUpdatedTime)
    {
        lastUpdatedTime = lastUpdated[distributorAddress][token];
    }

    /// @inheritdoc ICashbackVault
    function payCashback(
        address multipool,
        address[] calldata assets
    )
        external
        override
        notPaused
        nonReentrant
        returns (uint[] memory values)
    {
        CashbackDistributor memory distributor = distributors[multipool];
        uint assetsLen = assets.length;
        uint currentTime = block.timestamp;
        values = new uint[](assetsLen);
        for (uint i; i < assetsLen;) {
            address asset = assets[i];
            MpAsset memory a = IMultipool(multipool).getAsset(asset);
            if (a.quantity == 0 && a.targetShare == 0) revert InvalidAsset(asset);
            uint lastUpdatedTime = lastUpdated[multipool][asset];
            uint value = distributor.distribute(lastUpdatedTime, currentTime);
            lastUpdated[multipool][asset] = block.timestamp;
            IMultipool(multipool).increaseCashback{value: value}(asset);
            values[i] = value;
            unchecked {
                ++i;
            }
        }
        distributors[multipool] = distributor;
        emit CashbackPayed(multipool, assets, values);
    }

    function updateDistributionParams(
        address multipool,
        uint newCashbackPerSec,
        uint newCashbackLimit,
        int cashbackBalanceChange
    )
        external
        payable
        onlyOwner
    {
        if (cashbackBalanceChange > 0) {
            if (uint(cashbackBalanceChange) > msg.value) {
                revert InsufficientAmount();
            }
        }
        if (cashbackBalanceChange < 0) {
            payable(msg.sender).transfer(uint(-cashbackBalanceChange));
        }

        CashbackDistributor memory distributor = distributors[multipool];
        distributor.updateDistribution(newCashbackPerSec, newCashbackLimit, cashbackBalanceChange);
        distributors[multipool] = distributor;
    }

    function addBalance(address multipool) external payable notPaused {
        CashbackDistributor memory distributor = distributors[multipool];
        distributor.addBalance(msg.value);
        distributors[multipool] = distributor;
    }
}
