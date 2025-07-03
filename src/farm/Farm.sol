// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {UserInfo, PoolInfo, FarmingMath} from "../lib/Farm.sol";
import {Multipool} from "../multipool/Multipool.sol";
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

    function initialize(address owner, address _protocolToken) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(owner);
        protocolToken = _protocolToken;
    }

    receive() external payable {}

    // poolAddress => info
    mapping(address => PoolInfo) private poolInfo;
    // poolAddress => userAddress => info
    mapping(address => mapping(address => UserInfo)) private userInfo;
    bool public isPaused;
    address public protocolToken;


    error IsPaused();
    error CantCompound();

    event Deposit(address indexed user, address indexed pool, uint256 amount);
    event Withdraw(address indexed user, address indexed pool, uint256 amount);
    event PauseChange(bool isPaused);

    modifier notPaused() {
        if (isPaused) revert IsPaused();
        _;
    }

    function getUser(
        address multipool,
        address userAddress
    )
        external
        view
        returns (UserInfo memory user)
    {
        user = userInfo[multipool][userAddress];
    }

    function getPool(
        address multipool
    )
        external
        view
        returns (PoolInfo memory pool)
    {
        pool = poolInfo[multipool];
    }

    function availableRewards(
        address poolAddress,
        address userAddress
    )
        public
        view
        returns (uint reward, uint rewardProtocol)
    {
        PoolInfo memory pool = poolInfo[poolAddress];
        UserInfo memory user = userInfo[poolAddress][userAddress];
        uint newRewards = Multipool(pool.multipoolAddress).lpFeesBalance();
        (reward, rewardProtocol) = pool.updateRewards(user, block.number, newRewards);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function deposit(
        address poolAddress,
        uint256 depositAmount
    )
        external
        notPaused
        nonReentrant
    {
        PoolInfo memory pool = poolInfo[poolAddress];
        UserInfo memory user = userInfo[poolAddress][msg.sender];

        if (depositAmount > 0) {
            IERC20(pool.multipoolAddress).safeTransferFrom(msg.sender, address(this), depositAmount);
        }
        uint newRewards = Multipool(pool.multipoolAddress).claimLpFees(address(this));
        (uint reward, uint protocolReward) = pool.deposit(user, block.number, depositAmount, newRewards);
        
        payable(msg.sender).transfer(reward);
        
        if (protocolReward > 0) {
            IERC20(protocolToken).safeTransfer(msg.sender, protocolReward);
        }

        poolInfo[poolAddress] = pool;
        userInfo[poolAddress][msg.sender] = user;

        emit Deposit(msg.sender, poolAddress, depositAmount);
    }

    function withdraw(
        address poolAddress,
        uint256 withdrawAmount
    )
        external
        payable
        notPaused
        nonReentrant
    {
        PoolInfo memory pool = poolInfo[poolAddress];
        UserInfo memory user = userInfo[poolAddress][msg.sender];

        uint newRewards = Multipool(pool.multipoolAddress).claimLpFees(address(this));
        (uint reward, uint protocolReward) = pool.withdraw(user, block.number, withdrawAmount, newRewards);

        payable(msg.sender).transfer(reward);

        if (protocolReward > 0) {
            IERC20(protocolToken).safeTransfer(msg.sender, protocolReward);
        }

        if (withdrawAmount > 0) {
            IERC20(pool.multipoolAddress).safeTransfer(msg.sender, withdrawAmount);
        }

        poolInfo[poolAddress] = pool;
        userInfo[poolAddress][msg.sender] = user;

        emit Withdraw(msg.sender, poolAddress, withdrawAmount);
    }

    function updateDistribution(address poolAddress, int rewardsDelta, uint newRpb) external payable onlyOwner {
        PoolInfo memory pool = poolInfo[poolAddress];

        uint newRewards = Multipool(pool.multipoolAddress).claimLpFees(address(this));
        pool.updateDistribution(block.number, rewardsDelta, newRpb, newRewards);

        if (rewardsDelta >= 0) {
            IERC20(protocolToken).safeTransferFrom(msg.sender, address(this), uint(rewardsDelta));
        } else {
            IERC20(protocolToken).safeTransfer(msg.sender, uint(-rewardsDelta));
        }
        pool.multipoolAddress = poolAddress;
        poolInfo[poolAddress] = pool;
    }

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
        emit PauseChange(isPaused);
    }
}
