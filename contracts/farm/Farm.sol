// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LpFarm is Ownable {
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint lastRewardBlock;
        uint distributeTill;
        uint distributionAmountLeft;
        uint arps; // Accumulated rewards per share, times 1e12. See below.
        uint totalLpSupply;
    }

    IERC20 public rewardToken;

    mapping(uint => PoolInfo) public poolInfo;
    mapping(uint => mapping(address => UserInfo)) public userInfo;

    uint public poolNumber;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(IERC20 _rewardToken) {
        rewardToken = _rewardToken;
    }

    function calculateReward(
        PoolInfo memory pool,
        uint blockNumber
    ) internal pure returns (uint rewards) {
        rewards =
            ((blockNumber - pool.lastRewardBlock) *
                1e12 *
                pool.distributionAmountLeft) /
            (pool.distributeTill - pool.lastRewardBlock);
    }

    function updatePool(uint _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (
            pool.distributeTill > pool.lastRewardBlock &&
            pool.totalLpSupply != 0
        ) {
            uint newRewards = calculateReward(pool, block.number);
            pool.arps += newRewards / pool.totalLpSupply;
        }
        pool.lastRewardBlock = block.number;
    }

    function pendingRewards(
        uint _pid,
        address _user
    ) external view returns (uint amount) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        if (
            pool.distributeTill > pool.lastRewardBlock &&
            pool.totalLpSupply != 0
        ) {
            uint newRewards = calculateReward(pool, block.number);
            pool.arps += newRewards / pool.totalLpSupply;
        }
        amount = (user.amount * pool.arps) / 1e12 - user.rewardDebt;
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint pending = (user.amount * pool.arps) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                rewardToken.transfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount += _amount;
            pool.totalLpSupply += _amount;
        }
        user.rewardDebt = (user.amount * pool.arps) / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint pending = (user.amount * pool.arps) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            rewardToken.transfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount -= _amount;
            pool.totalLpSupply -= _amount;
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        user.rewardDebt = (user.amount * pool.arps) / 1e12;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function setDistribution(
        uint _pid,
        uint _amount,
        uint _distributionTime
    ) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        updatePool(_pid);
        rewardToken.transferFrom(msg.sender, address(this), _amount);
        pool.distributionAmountLeft += _amount;
        pool.distributeTill += _distributionTime;
    }

    function add(IERC20 _lpToken) public onlyOwner {
        poolInfo[poolNumber] = PoolInfo({
            lpToken: _lpToken,
            lastRewardBlock: block.number,
            distributeTill: block.number,
            distributionAmountLeft: 0,
            totalLpSupply: 0,
            arps: 0
        });
        poolNumber += 1;
    }
}
