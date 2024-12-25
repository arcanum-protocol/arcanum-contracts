// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little defi explorer
// oh, if you wana fork, fuck you

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {FixedPoint96} from "../lib/FixedPoint96.sol";

import {IStaker} from "../interfaces/IStaker.sol";

import {ForcePushArgs, AssetArgs} from "../types/SwapArgs.sol";

import {ERC20Upgradeable} from "oz-proxy/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "oz-proxy/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

/// @custom:security-contact badconfig@arcanum.to
contract Staker is
    IStaker,
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

    struct OracleData {
        uint128 stake;
        uint128 unrealizedQuota;
    }

    mapping(address => OracleData) oracles;

    address tokenAddress;
    uint96  sharePriceValidityDuration;

    uint128 rewardPerBlock;
    uint128 lastClaimedBlock;

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function commitPrice(ForcePushArgs calldata forcePushArgs) external payable {
    }

    function commitPrice1(ForcePushArgs calldata forcePushArgs) external payable {
            // 1 is added to thershold to prevent it being zeroed.
            // This makes sense to prevent passing price with no signatures
            bytes memory data = abi.encodePacked(
                address(forcePushArgs.contractAddress),
                uint(forcePushArgs.timestamp),
                uint(forcePushArgs.sharePrice),
                uint(block.chainid)
            );
            address oracleAddress = keccak256(data).toEthSignedMessageHash().recover(forcePushArgs.signature);
            OracleData memory oracle = oracles[oracleAddress];

            if (forcePushArgs.contractAddress != msg.sender) {
                revert InvalidSender();
            }

            if (oracle.stake == 0) {
                revert InvalidForcePushAuthority();
            }

            if (forcePushArgs.timestamp + sharePriceValidityDuration < block.timestamp) {
                revert ForcePushPriceExpired(block.timestamp, forcePushArgs.timestamp);
            }

            oracle.stake += (uint128(block.number) - lastClaimedBlock) * rewardPerBlock;
    }
}
