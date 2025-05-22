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

    receive() external payable nonReentrant {}

//     - Ферма в идеале одна на чейн
// - Ферма в идеале умеет максимально дешево на ресив принимать токены от юзеров, либо же придется делать разными адресами, чтоб работать с address(this).balance и знать что все деньги на ее адресе - ее, но я думаю вариант 1 норм
// - У фермы как и сейчас есть маппинг в котором есть адрес мультипула -> адрес юзера -> депозит и реворд дебт (или че там еще нам нужно сохранить) 
// - Овнер решает сколько денег пойдет в реварды а сколько пойдет ему в корман, овнер определяется делая запрос к тому, кто овнер мультипула
// - Есть второй токен который тоже дается как реворд опционально - это наш протокольный токен. 
// Можно теоретически сделать чтоб в ферму можно было как в массив добавлять разные эти токены, 
// или просто дать овнеру возможность включать 3й кастомынй токен (чисто юзлес фича пришла в голову). 
// Но самое важное что второй токен точно должен быть, его  должны настраивать как-то мы, полагаю лучше всего это делать так, 
// чтоб мы настраивали сколько токенов в секунду (как овнеры контракта) 
// а депать сами токены мог любой адрес пермишнлесс (но это явно будем мы)

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

    // TODO possibly modifies the state

    // function availableRewards(
    //     address poolAddress,
    //     address userAddress
    // )
    //     public
    //     view
    //     returns (uint reward, uint rewardProtocol)
    // {
    //     PoolInfo memory pool = poolInfo[poolAddress];
    //     UserInfo memory user = userInfo[poolAddress][userAddress];
    //     uint newRewards = Multipool(pool.multipoolAddress).claimLpFees(address(this));
    //     (reward, rewardProtocol) = pool.updateRewards(user, block.timestamp, newRewards);
    // }

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
        (uint reward, uint protocolReward) = pool.deposit(user, block.timestamp, depositAmount, newRewards);

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
        (uint reward, uint protocolReward) = pool.withdraw(user, block.timestamp, withdrawAmount, newRewards);

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

    function updateDistribution(address poolAddress, int rewardsDelta, uint newRpb) external onlyOwner {
        PoolInfo memory pool = poolInfo[poolAddress];

        pool.updateDistribution(block.timestamp, rewardsDelta, newRpb);

        if (rewardsDelta >= 0) {
            IERC20(protocolToken).safeTransferFrom(msg.sender, address(this), uint(rewardsDelta));
        } else {
            IERC20(protocolToken).safeTransfer(msg.sender, uint(-rewardsDelta));
        }

        poolInfo[poolAddress] = pool;
    }

    function togglePause() external onlyOwner {
        isPaused = !isPaused;
        emit PauseChange(isPaused);
    }
}
