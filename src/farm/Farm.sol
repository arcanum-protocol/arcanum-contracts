// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {FarmingMath, PoolInfo, UserInfo} from "../lib/Farm.sol";

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

contract Farm is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using FarmingMath for PoolInfo;

    constructor() {
        _disableInitializers();
    }

    function initialize()
        public
        initializer
    {
        __ReentrancyGuard_init();
        __Ownable_init();
    }

    mapping(uint => PoolInfo) private poolInfo;
    mapping(uint => mapping(address => UserInfo)) private userInfo;
    uint public poolNumber;
    bool public isPaused;

    error IsPaused();
    error CallbackFailed(bytes reason);

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event PauseChange(bool isPaused);

    modifier notPaused() {
        if (isPaused) revert IsPaused();
        _;
    }

    function getUser(uint poolId, address userAddress) external view returns (UserInfo memory user) {
        user = userInfo[poolId][userAddress];
    }

    function getPool(uint poolId) external view returns (PoolInfo memory pool) {
        pool = poolInfo[poolId];
    }

    function availableRewards(uint poolId, address userAddress) external view returns (uint rewards) {
        PoolInfo memory pool = poolInfo[poolId];
        UserInfo memory user = userInfo[poolId][userAddress];
        pool.updateRewards(user, block.timestamp);
        rewards = user.accRewards;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function deposit(uint256 poolId, uint256 depositAmount) 
        external
        notPaused
        nonReentrant
    {
        PoolInfo memory pool = poolInfo[poolId];
        UserInfo memory user = userInfo[poolId][msg.sender];

        IERC20(pool.lockAsset).safeTransferFrom(msg.sender, address(this), depositAmount);
        pool.deposit(user, block.timestamp, depositAmount);

        poolInfo[poolId] = pool;
        userInfo[poolId][msg.sender] = user;
        
        emit Deposit(msg.sender, poolId, depositAmount);
    }

    function withdraw(
        uint256 poolId, 
        uint256 withdrawAmount, 
        bool claimRewards, 
        address callback, 
        bytes calldata callbackData
    ) 
        external 
        payable 
        notPaused
        nonReentrant
    {
        PoolInfo memory pool = poolInfo[poolId];
        UserInfo memory user = userInfo[poolId][msg.sender];

        pool.withdraw(user, block.timestamp, withdrawAmount);

        uint rewards;
        if (claimRewards) {
            rewards = user.accRewards;
            user.accRewards = 0;
        }

        poolInfo[poolId] = pool;
        userInfo[poolId][msg.sender] = user;
        
        emit Withdraw(msg.sender, poolId, withdrawAmount);

        IERC20(pool.lockAsset).safeTransfer(msg.sender, withdrawAmount);
        if (rewards != 0) {
            if (callback == address(0)) {
                IERC20(pool.rewardAsset).safeTransfer(msg.sender, rewards);
            } else {
                IERC20(pool.rewardAsset).safeTransfer(callback, rewards);
                (bool success, bytes memory data) = callback.call{value: msg.value}(callbackData);
                if (!success) {
                    revert CallbackFailed(data);
                }
            }
        }
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

    function addPool(address lockAsset, address rewardAsset) external onlyOwner {
        PoolInfo memory pool;
        pool.lockAsset = lockAsset;
        pool.rewardAsset = rewardAsset;
        poolInfo[poolNumber] = pool;
        poolNumber += 1;
    }

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
        emit PauseChange(isPaused);
    }
}
