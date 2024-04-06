// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only by your heart
// good luck little defi explorer
// oh, if you wana fork, fuck you

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {FeedInfo, FeedType, UniV3Feed, PriceMath} from "../lib/Price.sol";
import {IPriceAdapter} from "../interfaces/IPriceAdapter.sol";
import {IWrapper} from "../interfaces/IWrapper.sol";
import {ISilo, ISiloLens} from "../interfaces/ISiloPool.sol";

import {OwnableUpgradeable} from "oz-proxy/access/OwnableUpgradeable.sol";
import {Initializable} from "oz-proxy/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "oz-proxy/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "oz-proxy/security/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact badconfig@arcanum.to
contract SiloPriceAdapter is
    IPriceAdapter,
    IWrapper,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using PriceMath for FeedInfo;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address _siloLens) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(owner);
        siloLens = _siloLens;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    struct Feed {
        address baseToken;
        FeedInfo baseFeed;
        ISilo siloAddress;
        IERC20 siloCollateralToken;
    }

    mapping(uint => Feed) internal feeds;
    address siloLens;
    uint feedNumber;

    function createFeed(address baseToken, ISilo siloPool, FeedInfo calldata baseFeed) external {
        feeds[feedNumber] = Feed({
            baseToken: baseToken,
            baseFeed: baseFeed,
            siloAddress: siloPool,
            siloCollateralToken: IERC20(siloPool.assetStorage(baseToken).collateralToken)
        });
        feedNumber += 1;
    }

    function getPrice(uint feedId) external view override returns (uint priceX96) {
        Feed memory feed = feeds[feedId];
        uint quoteValue =
            ISiloLens(siloLens).totalDepositsWithInterest(feed.siloAddress, feed.baseToken);
        uint totalSupply = IERC20(feed.siloCollateralToken).totalSupply();
        uint basePrice = feed.baseFeed.getPrice();
        priceX96 = basePrice * quoteValue / totalSupply;
    }

    function wrap(
        uint baseAmount,
        address to,
        bytes calldata data
    )
        external
        override
        returns (uint wrappedAmount)
    {
        (address pool, address baseToken, address wrappedToken) =
            abi.decode(data, (address, address, address));
        IERC20(baseToken).approve(pool, baseAmount);
        (, wrappedAmount) = ISilo(pool).deposit(baseToken, baseAmount, false);
        IERC20(wrappedToken).transfer(to, wrappedAmount);
    }

    function unwrap(
        uint wrappedAmount,
        address to,
        bytes calldata data
    )
        external
        override
        returns (uint baseAmount)
    {
        (address pool, address baseToken, address wrappedToken) =
            abi.decode(data, (address, address, address));
        IERC20(wrappedToken).approve(pool, wrappedAmount);
        (baseAmount,) = ISilo(pool).withdraw(baseToken, wrappedAmount, false);
        IERC20(baseToken).transfer(to, baseAmount);
    }
}
