// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {FixedPoint96} from "../lib/FixedPoint.sol";

import {IArcanumOracle} from "../interfaces/IArcanumOracle.sol";
import {OraclePrice} from "../types/OraclePrice.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Oracle is
    IArcanumOracle,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{

    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(
    )
        public
        initializer
    {
        __ReentrancyGuard_init();
        __Ownable_init();
    }

    struct StakeData {
        uint128 privateStake;
        uint128 publicStake;
    }

    struct OracleData {
        uint128 stake;
        bool enabled;
    }

    mapping(address => mapping(address => StakeData)) stakers;

    mapping(address => OracleData) oracles;

    // Hardcoded AREV token total supply
    uint internal constant tokenTotalSupply = 10e18;

    uint128 oraclesCount;
    uint128 oraclesToSlash;

    uint128 minStake;
    uint128 maxStake;

    address tokenAddress;
    uint96  sharePriceValidityDuration;

    uint128 collectedReward;
    uint128 totalBurnedAssets;

    uint128 rewardPerBlock;
    uint128 lastClaimedBlock;

    struct SlashProposal {
        address oracleToSlash;
        uint96 votes;
        uint128 proposalCreationTime;
    }

    mapping(uint => SlashProposal) slashProposals;
    uint slashProposalCount;
    mapping(bytes32 => bool) authorityDidVote;

    event ProposalCreated(address indexed oracleToSlash, bytes reason);

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function startSlashProposal(address oracleToSlash, bytes calldata reason) external {
        slashProposalCount += 1;
        slashProposals[slashProposalCount] = SlashProposal(oracleToSlash, 0, uint128(block.timestamp));

        emit ProposalCreated(oracleToSlash, reason);
    }

    function voteSlashProposal() external {
    }

    function _voteSlashProposal(address voter, uint96 proposalNum) internal {
        bytes32 voteId = bytes32(abi.encode(voter, proposalNum));
        if (authorityDidVote[voteId]) revert();
        authorityDidVote[voteId] = true;

        SlashProposal memory proposal = slashProposals[slashProposalCount];
        proposal.votes += 1;

        if (proposal.votes < oraclesToSlash) return;

    }

    function stake() external {
    }

    function unstake() external {
    }

    function redeemCollateral(address payable to, uint amountToBurn) external {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amountToBurn);

        uint amountToRedeem = amountToBurn * (tokenTotalSupply - totalBurnedAssets) / tokenTotalSupply;
        to.transfer(amountToRedeem);

        totalBurnedAssets += uint128(amountToBurn);
    }

    function commitPrice(OraclePrice calldata oraclePrice) external payable {
            bytes memory data = abi.encodePacked(
                address(msg.sender),
                uint(oraclePrice.timestamp),
                uint(oraclePrice.sharePrice),
                uint(block.chainid)
            );
            address oracleAddress = keccak256(data).toEthSignedMessageHash().recover(oraclePrice.signature);
            OracleData memory oracle = oracles[oracleAddress];

            if (oracle.enabled) {
                revert InvalidForcePushAuthority();
            }

            if (oraclePrice.timestamp + sharePriceValidityDuration < block.timestamp) {
                revert ForcePushPriceExpired(block.timestamp, oraclePrice.timestamp);
            }

            uint availableReward = (uint128(block.number) - lastClaimedBlock) * rewardPerBlock + collectedReward;
            uint income = msg.value;
            uint contractBalance = address(this).balance - income;
            uint valueToBuy = income * (tokenTotalSupply - totalBurnedAssets) / contractBalance;

            if (availableReward > valueToBuy) {
                collectedReward = uint128(availableReward - valueToBuy);
                oracle.stake += uint128(valueToBuy);
            } else {
                oracle.stake = uint128(availableReward);
            }
    }
}
