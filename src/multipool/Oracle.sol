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
    StakeOptions,
    Slot,
    WithdrawRequest,
    OracleData,
    unpackWithdrawRequest,
    packWithdrawRequest,
    unpackSlot,
    packSlot,
    unpackOracleData,
    packOracleData
} from "../types/Oracle.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Oracle is IArcanumOracle, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize() public payable initializer {
        __Ownable_init();
        _mint(msg.sender, 10000000e18);
    }

    bytes32 _slot0;

    // user -> oracle
    mapping(address => mapping(address => uint)) stakers;
    // user -> oracle -> WithdrawRequest
    mapping(address => mapping(address => mapping(uint => bytes32))) withdrawals;
    // oracle -> OracleData
    mapping(address => bytes32) oracles;
    // oracle -> amount
    mapping(address => uint) pendingStakes;

    // add different mapping for actual shares
    // счетчик не виздровнутых шейров
    // шейры которые не виздровнуты - текущий стейк относительн оминимальноего
    // unstake - уменьшаем этот счетчик
    // withdraw - уменьшаем настоящий счетчик

    // добавить бул на оракла тип чтобы не позволять
    // валидировать (при пересечении стейком нижней границы,
    // мб юзеры захотели вывести - он сможет вернуть)

    mapping(address => bool) panicAuthorities;

    uint32 internal constant rewardPerSecondPrecision = 1e8;

    uint112 minStake;
    uint112 maxStake;

    // ERC20

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    string private constant _name = "Arcanum Revenue Token";
    string private constant _symbol = "AREV";

    function getSlot() public view returns (Slot memory slot) {
        slot = unpackSlot(_slot0);
    }

    function getOracle(address oracle) public view returns (OracleData memory od) {
        od = unpackOracleData(oracles[oracle]);
    }

    function getStakeOptions() public view returns (StakeOptions memory so) {
        so.maxStake = maxStake;
        so.minStake = minStake;
    }

    function updateRewardPerSecond(uint32 _rewardPerSecond) public onlyOwner {
        Slot memory slot = unpackSlot(_slot0);
        slot.rewardPerSecond = _rewardPerSecond;
        _slot0 = packSlot(slot);
    }

    function updateStakeLimits(
        uint112 _minStake,
        uint112 _maxStake,
        uint32 _withdrawalDuration
    )
        public
        onlyOwner
    {
        Slot memory slot = unpackSlot(_slot0);
        minStake = _minStake;
        maxStake = _maxStake;
        slot.withdrawalDuration = _withdrawalDuration;
        _slot0 = packSlot(slot);
    }

    function updateFraudData(
        bool weArePanicking,
        uint16 sharePriceValidityDuration
    )
        public
        onlyOwner
    {
        Slot memory slot = unpackSlot(_slot0);
        slot.weArePanicking = weArePanicking;
        slot.sharePriceValidityDuration = sharePriceValidityDuration;
        _slot0 = packSlot(slot);
        emit UpdateFraudData(slot.sharePriceValidityDuration, slot.weArePanicking);
    }

    function toggleOracle(address oracleAddress) public onlyOwner {
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);
        oracle.enabled = !oracle.enabled;
        oracles[oracleAddress] = packOracleData(oracle);
        emit ToggleOracle(oracleAddress, oracle.enabled);
    }

    function togglePanicAuthority(address authority) public onlyOwner {
        panicAuthorities[authority] = !panicAuthorities[authority];
        emit TogglePanicAuthority(authority, panicAuthorities[authority]);
    }

    function slash(address governance, address oracleAddress, int88 amount) public onlyOwner {
        Slot memory slot = unpackSlot(_slot0);
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);
        oracle.stake = uint88(int88(oracle.stake) + amount);
        pendingStakes[oracleAddress] = uint(int(pendingStakes[oracleAddress]) + int(amount));

        if (oracle.stake < minStake) {
            oracle.allowedToValidate = false;
        }

        oracles[oracleAddress] = packOracleData(oracle);
        emit Slahed(governance, oracleAddress, amount);
    }

    function transferToGovernance(address governance, uint amount) public onlyOwner {
        _transfer(address(this), governance, amount);
        emit TransferToGovernance(governance, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    error WeAreCurrentlyInPanic();
    error StakeIsTooBig();
    error StakeIsTooSmall();
    error WithdrawalDelayed();
    error WithdrawalIsNotEmpty();
    error InvalidAuthority();
    error WithdrawalIsEmpty();

    event PanicCreated(bytes reason);
    event ToggleOracle(address oracleAddress, bool enabled);
    event TogglePanicAuthority(address authority, bool enabled);
    event UpdateFraudData(uint16 sharePriceValidityDuration, bool weArePanicking);
    event Slahed(address governance, address oracleAddress, int amountToSlash);
    event Staked(address to, address oracleAddress, uint amount);
    event Withdraw(address to, address oracleAddress, uint amount);
    event Unstake(address to, address oracleAddress, uint amount, uint nonce);
    event TransferToGovernance(address governance, uint amount);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function startPanic(bytes calldata reason) external {
        if (!panicAuthorities[msg.sender]) revert InvalidAuthority();
        Slot memory slot = unpackSlot(_slot0);
        slot.weArePanicking = true;
        _slot0 = packSlot(slot);
        emit PanicCreated(reason);
    }

    function stake(address oracleAddress, uint88 amount, address to) external {
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);

        if (oracle.stake + amount > maxStake) revert StakeIsTooBig();
        if (oracle.stake + amount < minStake) revert StakeIsTooSmall();
        // according to the error above it is always stake > maxStake
        oracle.allowedToValidate = true;

        Slot memory slot = unpackSlot(_slot0);

        if (slot.weArePanicking) revert WeAreCurrentlyInPanic();

        _transfer(msg.sender, address(this), amount);

        uint newShare;
        if (oracle.totalShares == 0) {
            newShare = amount;
        } else {
            newShare = amount * oracle.totalShares / oracle.stake;
        }
        oracle.totalShares = oracle.totalShares + uint128(newShare);
        stakers[to][oracleAddress] += newShare;

        pendingStakes[oracleAddress] += amount;
        oracle.stake = oracle.stake + amount;

        oracles[oracleAddress] = packOracleData(oracle);
        emit Staked(to, oracleAddress, amount);
    }

    function withdraw(address oracleAddress, uint nonce, address to) external {
        WithdrawRequest memory req = unpackWithdrawRequest(withdrawals[to][oracleAddress][nonce]);
        Slot memory slot = unpackSlot(_slot0);
        if (req.timestamp == 0) revert WithdrawalIsEmpty();
        if (slot.weArePanicking) revert WeAreCurrentlyInPanic();
        if (block.timestamp - req.timestamp < slot.withdrawalDuration) revert WithdrawalDelayed();
        // underflow on trying to withdraw after slash
        pendingStakes[oracleAddress] -= req.amount;
        _transfer(address(this), to, req.amount);
        emit Withdraw(to, oracleAddress, req.amount);
        delete withdrawals[to][oracleAddress][nonce];
    }

    function unstake(address oracleAddress, uint nonce, uint share, address to) external {
        Slot memory slot = unpackSlot(_slot0);
        if (slot.weArePanicking) revert WeAreCurrentlyInPanic();
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);
        uint88 amountToRedeem = uint88(share * oracle.stake / oracle.totalShares);

        oracle.totalShares = oracle.totalShares - uint128(share);
        oracle.stake = oracle.stake - amountToRedeem;
        stakers[msg.sender][oracleAddress] -= share;

        if (oracle.stake < minStake) {
            oracle.allowedToValidate = false;
        }

        WithdrawRequest memory req = unpackWithdrawRequest(withdrawals[to][oracleAddress][nonce]);
        if (req.timestamp != 0) revert WithdrawalIsNotEmpty();

        req.amount = uint128(amountToRedeem);
        req.timestamp = uint64(block.timestamp);

        oracles[oracleAddress] = packOracleData(oracle);
        withdrawals[to][oracleAddress][nonce] = packWithdrawRequest(req);
        emit Unstake(to, oracleAddress, amountToRedeem, nonce);
    }

    function burn(address payable to, uint88 amountToBurn) external {
        Slot memory slot = unpackSlot(_slot0);
        uint amountToRedeem = amountToBurn * address(this).balance / slot.totalSupply;
        to.transfer(amountToRedeem);
        _burn(msg.sender, amountToBurn);
    }

    function commitPrice(OraclePrice calldata oraclePrice) external payable {
        Slot memory slot = unpackSlot(_slot0);
        if (slot.weArePanicking) revert WeAreCurrentlyInPanic();

        bytes memory data = abi.encodePacked(
            address(msg.sender),
            uint(oraclePrice.timestamp),
            uint(oraclePrice.sharePrice),
            uint(block.chainid)
        );
        address oracleAddress =
            keccak256(data).toEthSignedMessageHash().recover(oraclePrice.signature);
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);

        if (!oracle.allowedToValidate) {
            revert InvalidForcePushAuthority(oracleAddress, address(msg.sender));
        }
        if (oraclePrice.timestamp + slot.sharePriceValidityDuration < block.timestamp) {
            revert ForcePushPriceExpired(block.timestamp, oraclePrice.timestamp);
        }

        // avb tokens
        uint88 availableReward = uint88(
            (block.timestamp - slot.lastClaimedTimestamp) * slot.rewardPerSecond
                * rewardPerSecondPrecision
        );

        uint income = msg.value;
        // how much to buy with income max
        uint88 valueToBuy = uint88(income * slot.totalSupply / (address(this).balance - income));

        uint secs = 0;

        if (availableReward > valueToBuy) {
            secs = (availableReward - valueToBuy) / slot.rewardPerSecond / rewardPerSecondPrecision;
            oracle.stake += valueToBuy;
        } else {
            oracle.stake += availableReward;
        }

        slot.lastClaimedTimestamp = uint64(block.timestamp - secs);

        _slot0 = packSlot(slot);
        oracles[oracleAddress] = packOracleData(oracle);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return unpackSlot(_slot0).totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    )
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum
            // is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint88 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        Slot memory slot = unpackSlot(_slot0);

        slot.totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is
            // checked above.
            _balances[account] += amount;
        }
        _slot0 = packSlot(slot);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint88 amount) internal virtual {
        Slot memory slot = unpackSlot(_slot0);
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        slot.totalSupply -= amount;
        _slot0 = packSlot(slot);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
