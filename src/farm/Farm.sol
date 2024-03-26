// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {FarmingMath, PoolInfo, UserInfo} from "../lib/Farm.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Farm is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using FarmingMath for PoolInfo;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(owner);
    }

    mapping(uint => PoolInfo) private poolInfo;
    mapping(uint => mapping(address => UserInfo)) private userInfo;
    uint public poolNumber;
    bool public isPaused;

    error IsPaused();
    error CantCompound();

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event PauseChange(bool isPaused);

    modifier notPaused() {
        if (isPaused) revert IsPaused();
        _;
    }

    function getUser(
        uint poolId,
        address userAddress
    )
        external
        view
        returns (UserInfo memory user)
    {
        user = userInfo[poolId][userAddress];
    }

    function getPool(uint poolId) external view returns (PoolInfo memory pool) {
        pool = poolInfo[poolId];
    }

    function availableRewards(
        uint poolId,
        address userAddress
    )
        external
        view
        returns (uint reward, uint reward2)
    {
        PoolInfo memory pool = poolInfo[poolId];
        UserInfo memory user = userInfo[poolId][userAddress];
        (reward, reward2) = pool.updateRewards(user, block.timestamp);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function deposit(uint256 poolId, uint256 depositAmount) external notPaused nonReentrant {
        PoolInfo memory pool = poolInfo[poolId];
        UserInfo memory user = userInfo[poolId][msg.sender];

        if (depositAmount > 0) {
            IERC20(pool.lockAsset).safeTransferFrom(msg.sender, address(this), depositAmount);
        }

        (uint rewards, uint rewards2) = pool.deposit(user, block.timestamp, depositAmount);

        if (rewards > 0) {
            IERC20(pool.rewardAsset).safeTransfer(msg.sender, rewards);
        }

        if (rewards2 > 0) {
            IERC20(pool.rewardAsset2).safeTransfer(msg.sender, rewards2);
        }

        poolInfo[poolId] = pool;
        userInfo[poolId][msg.sender] = user;

        emit Deposit(msg.sender, poolId, depositAmount);
    }

    function withdraw(
        uint256 poolId,
        uint256 withdrawAmount,
        bool compoundRewards
    )
        external
        payable
        notPaused
        nonReentrant
    {
        PoolInfo memory pool = poolInfo[poolId];
        UserInfo memory user = userInfo[poolId][msg.sender];

        (uint rewards, uint rewards2) = pool.withdraw(user, block.timestamp, withdrawAmount);

        if (rewards > 0) {
            if (!compoundRewards) {
                IERC20(pool.rewardAsset).safeTransfer(msg.sender, rewards);
            } else if (pool.lockAsset == pool.rewardAsset) {
                pool.deposit(user, block.timestamp, rewards);
            } else {
                revert CantCompound();
            }
        }

        if (rewards2 > 0) {
            IERC20(pool.rewardAsset2).safeTransfer(msg.sender, rewards2);
        }

        if (withdrawAmount > 0) {
            IERC20(pool.lockAsset).safeTransfer(msg.sender, withdrawAmount);
        }

        poolInfo[poolId] = pool;
        userInfo[poolId][msg.sender] = user;

        emit Withdraw(msg.sender, poolId, withdrawAmount);
    }

    function updateDistribution(uint poolId, int rewardsDelta, uint newRpb) external onlyOwner {
        PoolInfo memory pool = poolInfo[poolId];

        pool.updateDistribution(block.timestamp, rewardsDelta, newRpb);

        if (rewardsDelta >= 0) {
            IERC20(pool.rewardAsset).safeTransferFrom(msg.sender, address(this), uint(rewardsDelta));
        } else {
            IERC20(pool.rewardAsset).safeTransfer(msg.sender, uint(-rewardsDelta));
        }

        poolInfo[poolId] = pool;
    }

    function updateDistribution2(uint poolId, int rewardsDelta, uint newRpb) external onlyOwner {
        PoolInfo memory pool = poolInfo[poolId];

        pool.updateDistribution2(block.timestamp, rewardsDelta, newRpb);

        if (rewardsDelta >= 0) {
            IERC20(pool.rewardAsset2).safeTransferFrom(
                msg.sender, address(this), uint(rewardsDelta)
            );
        } else {
            IERC20(pool.rewardAsset2).safeTransfer(msg.sender, uint(-rewardsDelta));
        }

        poolInfo[poolId] = pool;
    }

    function addPool(
        address lockAsset,
        address rewardAsset,
        address rewardAsset2
    )
        external
        onlyOwner
    {
        PoolInfo memory pool;
        pool.lockAsset = lockAsset;
        pool.rewardAsset = rewardAsset;
        pool.rewardAsset2 = rewardAsset2;
        poolInfo[poolNumber] = pool;
        poolNumber += 1;
    }

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
        emit PauseChange(isPaused);
    }
}
