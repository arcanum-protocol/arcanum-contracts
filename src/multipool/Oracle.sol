// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {FixedPoint96} from "../lib/FixedPoint.sol";
import {setBits, getBits} from "../lib/Binary.sol";

import {IArcanumOracle} from "../interfaces/IArcanumOracle.sol";
import {OraclePrice} from "../types/OraclePrice.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

import {
    FraudSlot, WithdrawRequest, 
    OracleData, unpackWithdrawRequest, 
    packWithdrawRequest, unpackFraudSlot, 
    packFraudSlot, unpackOracleData, packOracleData
} from "../types/Oracle.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Oracle is
    IArcanumOracle,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
    }

    // user -> oracle
    mapping(address => mapping(address => uint)) stakers;
    // user -> oracle -> WithdrawRequest
    mapping(address => mapping(address => mapping(uint => bytes32))) withdrawals;
    // oracle -> OracleData
    mapping(address => bytes32) oracles;

    // Hardcoded AREV token total supply of 10 mil
    uint internal constant tokenTotalSupply = 10000000e18;

    uint112 minStake;
    uint112 maxStake;
    uint32  withdrawalDuration;

    uint112 collectedReward;
    uint112 totalBurnedAssets;
    uint32  rewardPerSecond;

    bytes32 fraudSlot;

    function updateRewardPerSecond(uint32 _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
    }

    function updateStakeLimits(uint112 _minStake, uint112 _maxStake, uint32 _withdrawalDuration) public onlyOwner {
        minStake = _minStake;
        maxStake = _maxStake;
        withdrawalDuration = _withdrawalDuration;
    }

    function updateFraudSlot(address tokenAddress, bool weArePanicing, uint32 sharePriceValidityDuration) public onlyOwner {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        slot.tokenAddress = tokenAddress;
        slot.weArePanicing = weArePanicing;
        slot.sharePriceValidityDuration = sharePriceValidityDuration;
        fraudSlot = packFraudSlot(slot);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    error WeAreCurrentlyInPanic();
    error StakeIsTooBig();
    error WithdrawalDelayed();
    error WithdrawalIsNotEmpty();

    event PanicCreated(bytes reason);

    function startPanicing(bytes calldata reason) external {
        if (!unpackOracleData(oracles[msg.sender]).enabled) revert();
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        slot.weArePanicing = true;
        fraudSlot = packFraudSlot(slot);
        emit PanicCreated(reason);
    }

    function stake(address oracleAddress, uint amount, address to) external {
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);

        if (oracle.stake + amount > maxStake) revert StakeIsTooBig();

        FraudSlot memory slot = unpackFraudSlot(fraudSlot);

        IERC20(slot.tokenAddress).safeTransferFrom(msg.sender, address(this), amount); 
        uint newShare = amount * oracle.totalShares / oracle.stake;
        
        oracle.totalShares = oracle.totalShares + uint128(newShare);
        oracle.stake = oracle.stake + uint128(amount);
        stakers[to][oracleAddress] += newShare;
        
        oracles[oracleAddress] = packOracleData(oracle);
    }

    function withdraw(address oracleAddress, uint nonce, address to) external {
        WithdrawRequest memory req = unpackWithdrawRequest(withdrawals[to][oracleAddress][nonce]);
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);

        if (slot.weArePanicing) revert WeAreCurrentlyInPanic();
        if (block.timestamp - req.timestamp < withdrawalDuration) revert WithdrawalDelayed();

        IERC20(slot.tokenAddress).safeTransfer(to, req.amount);
        delete withdrawals[to][oracleAddress][nonce];
    }

    function unstake(address oracleAddress, uint nonce, uint share, address to) external {
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);
        uint amountToRedeem = share * oracle.stake / oracle.totalShares;

        oracle.totalShares = oracle.totalShares - uint128(share);
        oracle.stake = oracle.stake - uint128(amountToRedeem);
        stakers[to][oracleAddress] -= share;

        if (oracle.stake < minStake) {
            oracle.enabled = false; 
        }

        WithdrawRequest memory req = unpackWithdrawRequest(withdrawals[to][oracleAddress][nonce]);
        if (req.timestamp != 0) revert WithdrawalIsNotEmpty();

        req.amount = uint128(amountToRedeem);
        req.timestamp = uint64(block.timestamp);

        oracles[oracleAddress] = packOracleData(oracle);
        withdrawals[to][oracleAddress][nonce] = packWithdrawRequest(req);

    }

    function redeemCollateral(address payable to, uint amountToBurn) external {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        IERC20(slot.tokenAddress).transferFrom(msg.sender, address(this), amountToBurn);

        uint amountToRedeem =
            amountToBurn * (tokenTotalSupply - totalBurnedAssets) / tokenTotalSupply;
        to.transfer(amountToRedeem);

        totalBurnedAssets += uint112(amountToBurn);
    }

    function commitPrice(OraclePrice calldata oraclePrice) external payable {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        if (slot.weArePanicing) revert WeAreCurrentlyInPanic();

        bytes memory data = abi.encodePacked(
            address(msg.sender),
            uint(oraclePrice.timestamp),
            uint(oraclePrice.sharePrice),
            uint(block.chainid)
        );
        address oracleAddress =
            keccak256(data).toEthSignedMessageHash().recover(oraclePrice.signature);
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);

        if (oracle.enabled) {
            revert InvalidForcePushAuthority(address(0), address(0));
        }

        if (oraclePrice.timestamp + slot.sharePriceValidityDuration < block.timestamp) {
            revert ForcePushPriceExpired(block.timestamp, oraclePrice.timestamp);
        }

        uint _collectedReward = collectedReward;
        uint _totalBurnedAssets = totalBurnedAssets;
        uint _rewardPerSecond = rewardPerSecond;

        // avb tokens
        uint availableReward =
            (block.timestamp - slot.lastClaimedTimestamp) * _rewardPerSecond + _collectedReward;

        uint income = msg.value;
        // how much to buy with income max
        uint valueToBuy = income * (tokenTotalSupply - _totalBurnedAssets) / (address(this).balance - income);

        if (availableReward > valueToBuy) {
            collectedReward = uint112(availableReward - valueToBuy);
            oracle.stake += uint128(valueToBuy);
        } else {
            collectedReward = 0;
            oracle.stake += uint128(availableReward);
        }

        slot.lastClaimedTimestamp = block.timestamp;
        fraudSlot = packFraudSlot(slot);
    }

}
