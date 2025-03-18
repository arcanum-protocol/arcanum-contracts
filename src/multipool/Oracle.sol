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

    struct OracleData {
        uint128 stake;
        uint128 totalShares;
        bool enabled;
    }

    struct WithdrawRequest {
        uint128 amount;
        uint64 timestamp;
    }

    // user -> oracle
    mapping(address => mapping(address => uint)) stakers;
    // user -> oracle
    mapping(address => mapping(address => mapping(uint => WithdrawRequest))) withdrawals;
    mapping(address => OracleData) oracles;

    // Hardcoded AREV token total supply of 10 mil
    uint internal constant tokenTotalSupply = 10000000e18;

    uint112 minStake;
    uint112 maxStake;
    uint32  withdrawalDuration;

    uint112 collectedReward;
    uint112 totalBurnedAssets;
    uint32  rewardPerSecond;

    // we need to parse this guy manyally as weArePanicing is either bool or 1 bit
    // it's hard to pack this all up without carrying about this guy
    // tokenAddress - 160 bits
    // sharePriceValidityDuration - 31 bits
    // weArePanicing - 1 bit
    // lastClaimedTimestamp - 64 bits
    bytes32 fraudSlot;

    struct FraudSlot {
        address tokenAddress;
        uint sharePriceValidityDuration;
        bool weArePanicing;
        uint lastClaimedTimestamp;
    }

    function unpackFraudSlot(bytes32 packedSlot) pure internal returns(FraudSlot memory slot) {
        slot.tokenAddress = address(uint160(getBits(packedSlot, 0, 160)));
        slot.sharePriceValidityDuration = uint(getBits(packedSlot, 160, 31));
        slot.weArePanicing = getBits(packedSlot, 191, 1) == 1;
        slot.lastClaimedTimestamp = uint(getBits(packedSlot, 192, 64));
    }

    function packFraudSlot(FraudSlot memory slot) pure internal returns(bytes32 packedSlot) {
        packedSlot = setBits(packedSlot, bytes32(uint(uint160(slot.tokenAddress))), 0, 160);
        packedSlot = setBits(packedSlot, bytes32(uint(slot.sharePriceValidityDuration)), 160, 31);
        packedSlot = setBits(packedSlot, bytes32(slot.weArePanicing == true ? uint(1) : 0), 191, 1);
        packedSlot = setBits(packedSlot, bytes32(uint(uint64(slot.lastClaimedTimestamp))), 192, 64);
    }

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
        if (!oracles[msg.sender].enabled) revert();
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        slot.weArePanicing = true;
        fraudSlot = packFraudSlot(slot);
        emit PanicCreated(reason);
    }

    function stake(address oracleAddress, uint amount, address to) external {
        OracleData memory oracle = oracles[oracleAddress];

        if (oracle.stake + amount > maxStake) revert StakeIsTooBig();

        FraudSlot memory slot = unpackFraudSlot(fraudSlot);

        IERC20(slot.tokenAddress).safeTransferFrom(msg.sender, address(this), amount); 
        uint newShare = amount * oracle.totalShares / oracle.stake;
        
        oracle.totalShares = oracle.totalShares + uint128(newShare);
        oracle.stake = oracle.stake + uint128(amount);
        stakers[to][oracleAddress] += newShare;
        
        oracles[oracleAddress] = oracle;
    }

    function withdraw(address oracleAddress, uint nonce, address to) external {
        WithdrawRequest memory req = withdrawals[to][oracleAddress][nonce];
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);

        if (slot.weArePanicing) revert WeAreCurrentlyInPanic();
        if (block.timestamp - req.timestamp < withdrawalDuration) revert WithdrawalDelayed();

        IERC20(slot.tokenAddress).safeTransfer(to, req.amount);
        delete withdrawals[to][oracleAddress][nonce];
    }

    function unstake(address oracleAddress, uint nonce, uint share, address to) external {
        OracleData memory oracle = oracles[oracleAddress];
        uint amountToRedeem = share * oracle.stake / oracle.totalShares;

        oracle.totalShares = oracle.totalShares - uint128(share);
        oracle.stake = oracle.stake - uint128(amountToRedeem);
        stakers[to][oracleAddress] -= share;

        if (oracle.stake < minStake) {
            oracle.enabled = false; 
        }

        WithdrawRequest memory req = withdrawals[to][oracleAddress][nonce];
        if (req.timestamp != 0) revert WithdrawalIsNotEmpty();

        req.amount = uint128(amountToRedeem);
        req.timestamp = uint64(block.timestamp);

        oracles[oracleAddress] = oracle;
        withdrawals[to][oracleAddress][nonce] = req;

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
        OracleData memory oracle = oracles[oracleAddress];

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
        uint contractBalance = address(this).balance - income;

        // how much to buy with income max
        uint valueToBuy = income * (tokenTotalSupply - _totalBurnedAssets) / contractBalance;

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
