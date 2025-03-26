// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {FixedPoint96} from "../lib/FixedPoint.sol";
import {setBits, getBits} from "../lib/Binary.sol";
import "forge-std/Script.sol";

import {IArcanumOracle} from "../interfaces/IArcanumOracle.sol";
import {OraclePrice} from "../types/OraclePrice.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

import {
    FraudSlot,
    WithdrawRequest,
    OracleData,
    unpackWithdrawRequest,
    packWithdrawRequest,
    unpackFraudSlot,
    packFraudSlot,
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

    function initialize(string memory name_, string memory symbol_) public payable initializer {
        _name = name_;
        _symbol = symbol_;
        __Ownable_init();
        _mint(msg.sender, _totalSupply);
    }

    // user -> oracle
    mapping(address => mapping(address => uint)) stakers;
    // user -> oracle -> WithdrawRequest
    mapping(address => mapping(address => mapping(uint => bytes32))) withdrawals;
    // oracle -> OracleData
    mapping(address => bytes32) oracles;

    uint32 internal constant rewardPerSecondPrecision = 1e8;

    uint112 public minStake;
    uint112 public maxStake;
    uint32 public withdrawalDuration;

    uint112 public spareReward;
    uint112 public totalBurnedAssets;
    uint32 public rewardPerSecond;

    bytes32 fraudSlot;

    // ERC20

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    // Hardcoded AREV token total supply of 10 mil
    uint256 private constant _totalSupply = 10000000e18;

    string private _name;
    string private _symbol;

    function getFraudSlot() public view returns (FraudSlot memory slot) {
        slot = unpackFraudSlot(fraudSlot);
    }

    function getOracle(address oracle) public view returns (OracleData memory od) {
        od = unpackOracleData(oracles[oracle]);
    }

    function updateRewardPerSecond(uint32 _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
    }

    function updateStakeLimits(
        uint112 _minStake,
        uint112 _maxStake,
        uint32 _withdrawalDuration
    )
        public
        onlyOwner
    {
        minStake = _minStake;
        maxStake = _maxStake;
        withdrawalDuration = _withdrawalDuration;
    }

    function updateFraudSlot(
        bool weArePanicking,
        uint16 sharePriceValidityDuration
    )
        public
        onlyOwner
    {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        slot.weArePanicking = weArePanicking;
        slot.sharePriceValidityDuration = sharePriceValidityDuration;
        fraudSlot = packFraudSlot(slot);
        emit UpdateFraudSlot(slot.sharePriceValidityDuration, slot.weArePanicking);
    }

    function toggleOracle(address oracleAddress) public onlyOwner {
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);
        oracle.enabled = !oracle.enabled;
        oracles[oracleAddress] = packOracleData(oracle);
        emit ToggleOracle(oracleAddress, oracle.enabled);
    }

    function slash(address governance, address oracleAddress, uint percent) public onlyOwner {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);
        uint amountToSlash = oracle.stake * percent / 10000;
        uint share = amountToSlash * oracle.totalShares / oracle.stake;
        oracle.totalShares = oracle.totalShares - uint128(share);
        oracle.stake = oracle.stake - uint128(amountToSlash);
        _transfer(address(this), governance, amountToSlash);
        oracles[oracleAddress] = packOracleData(oracle);
        emit Slahed(governance, oracleAddress, amountToSlash);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    error WeAreCurrentlyInPanic();
    error StakeIsTooBig();
    error StakeIsTooSmall();
    error WithdrawalDelayed();
    error WithdrawalIsNotEmpty();
    error InvalidPanicAuthority();
    error WithdrawalIsEmpty();

    event PanicCreated(bytes reason);
    event ToggleOracle(address oracleAddress, bool enabled);
    event UpdateFraudSlot(uint16 sharePriceValidityDuration, bool weArePanicking);
    event Slahed(address governance, address oracleAddress, uint amountToSlash);
    event Staked(address to, address oracleAddress, uint amount);
    event Withdraw(address to, address oracleAddress, uint amount);
    event Unstake(address to, address oracleAddress, uint amount, uint nonce);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function startPanic(bytes calldata reason) external {
        if (!unpackOracleData(oracles[msg.sender]).enabled) revert InvalidPanicAuthority();
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        slot.weArePanicking = true;
        fraudSlot = packFraudSlot(slot);
        emit PanicCreated(reason);
    }

    function stake(address oracleAddress, uint amount, address to) external {
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);

        if (oracle.stake + amount > maxStake) revert StakeIsTooBig();
        if (oracle.stake + amount < minStake) revert StakeIsTooSmall();

        FraudSlot memory slot = unpackFraudSlot(fraudSlot);

        if (slot.weArePanicking) revert WeAreCurrentlyInPanic();

        _transfer(msg.sender, address(this), amount);

        uint newShare;
        if (oracle.totalShares == 0) {
            newShare = amount;
        } else {
            newShare = amount * oracle.totalShares / oracle.stake;
        }
        oracle.totalShares = oracle.totalShares + uint128(newShare);
        oracle.stake = oracle.stake + uint128(amount);
        stakers[to][oracleAddress] += newShare;

        oracles[oracleAddress] = packOracleData(oracle);
        emit Staked(to, oracleAddress, amount);
    }

    function withdraw(address oracleAddress, uint nonce, address to) external {
        WithdrawRequest memory req = unpackWithdrawRequest(withdrawals[to][oracleAddress][nonce]);
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        if (req.timestamp == 0) revert WithdrawalIsEmpty();
        if (slot.weArePanicking) revert WeAreCurrentlyInPanic();
        if (block.timestamp - req.timestamp < withdrawalDuration) revert WithdrawalDelayed();
        _transfer(address(this), to, req.amount);
        emit Withdraw(to, oracleAddress, req.amount);
        delete withdrawals[to][oracleAddress][nonce];
    }

    function unstake(address oracleAddress, uint nonce, uint share, address to) external {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
        if (slot.weArePanicking) revert WeAreCurrentlyInPanic();
        OracleData memory oracle = unpackOracleData(oracles[oracleAddress]);
        uint amountToRedeem = share * oracle.stake / oracle.totalShares;

        oracle.totalShares = oracle.totalShares - uint128(share);
        oracle.stake = oracle.stake - uint128(amountToRedeem);
        stakers[msg.sender][oracleAddress] -= share;

        if (oracle.stake < minStake) {
            oracle.enabled = false;
        }

        WithdrawRequest memory req = unpackWithdrawRequest(withdrawals[to][oracleAddress][nonce]);
        if (req.timestamp != 0) revert WithdrawalIsNotEmpty();

        req.amount = uint128(amountToRedeem);
        req.timestamp = uint64(block.timestamp);

        oracles[oracleAddress] = packOracleData(oracle);
        withdrawals[to][oracleAddress][nonce] = packWithdrawRequest(req);
        emit Unstake(to, oracleAddress, amountToRedeem, nonce);
    }

    function burn(address payable to, uint amountToBurn) external {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);

        _burn(msg.sender, amountToBurn);

        uint amountToRedeem = amountToBurn * (_totalSupply - totalBurnedAssets) / _totalSupply;

        to.transfer(amountToRedeem);

        totalBurnedAssets += uint112(amountToBurn);
    }

    function commitPrice(OraclePrice calldata oraclePrice) external payable {
        FraudSlot memory slot = unpackFraudSlot(fraudSlot);
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

        if (!oracle.enabled) {
            revert InvalidForcePushAuthority(oracleAddress, address(msg.sender));
        }

        if (oraclePrice.timestamp + slot.sharePriceValidityDuration < block.timestamp) {
            revert ForcePushPriceExpired(block.timestamp, oraclePrice.timestamp);
        }

        uint _spareReward = spareReward;
        uint _totalBurnedAssets = totalBurnedAssets;
        uint _rewardPerSecond = rewardPerSecond;
        // avb tokens
        uint availableReward = (block.timestamp - slot.lastClaimedTimestamp) * _rewardPerSecond
            * rewardPerSecondPrecision + _spareReward;

        uint income = msg.value;
        // how much to buy with income max
        uint valueToBuy =
            income * (_totalSupply - _totalBurnedAssets) / (address(this).balance - income);

        if (availableReward > valueToBuy) {
            spareReward = uint112(availableReward - valueToBuy);
            oracle.stake += uint128(valueToBuy);
        } else {
            spareReward = 0;
            oracle.stake += uint128(availableReward);
        }

        slot.lastClaimedTimestamp = block.timestamp;
        fraudSlot = packFraudSlot(slot);
        oracles[oracleAddress] = packOracleData(oracle);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
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

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
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

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        // _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is
            // checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            // _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
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
