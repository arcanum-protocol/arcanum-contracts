// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IArcanumOracle} from "../interfaces/IArcanumOracle.sol";
import {OraclePrice} from "../types/OraclePrice.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import "forge-std/Test.sol";

/// @custom:security-contact badconfig@arcanum.to
contract DummyOracle is
    IArcanumOracle,
    Ownable
{
    using ECDSA for bytes32;

    address public oracle;
    uint96 public priceValidityDuration;

    constructor(address _oracle, uint96 _priceValidityDuration) {
        oracle = _oracle;
        priceValidityDuration = _priceValidityDuration;
    }

    function updateParams(address _oracle, uint96 _priceValidityDuration) external onlyOwner {
        oracle = _oracle;
        priceValidityDuration = _priceValidityDuration;
    }

    function commitPrice(OraclePrice calldata oraclePrice) external payable {
        bytes memory data = abi.encodePacked(
            address(msg.sender),
            uint(oraclePrice.timestamp),
            uint(oraclePrice.sharePrice),
            uint(block.chainid)
        );

        address oracleAddress = keccak256(data).toEthSignedMessageHash().recover(oraclePrice.signature);

        address _oracle = oracle;
        uint96 _priceValidityDuration = priceValidityDuration;

        if (oracleAddress != _oracle) {
            revert InvalidForcePushAuthority(oracleAddress, _oracle);
        }

        if (oraclePrice.timestamp + _priceValidityDuration < block.timestamp) {
            revert ForcePushPriceExpired(block.timestamp, oraclePrice.timestamp);
        }
        payable(_oracle).transfer(msg.value);
    }
}
