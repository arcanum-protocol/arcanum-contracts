// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
// Multipool can't be understood by your mind, only your heart

import {ERC20, IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Multipool} from "./Multipool.sol";
import {FeedInfo, FeedType} from "../lib/Price.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/// @custom:security-contact badconfig@arcanum.to
contract MultipoolFactory {
    mapping(uint => address) multipools;
    uint multipoolsNumber;
    address latestImplementation;

    function setImplementation(address newImplementation) external {
        latestImplementation = newImplementation;
    }

    struct SetupAsset {
        address asset;
        FeedInfo priceFeed;
        uint targetShare;
    }

    struct DeployArgs {
        string name;
        string symbol;
        uint startPrice;
        uint[] targetShares;
        address[] assets;
        FeedInfo[] priceFeeds;
        bool[] isPriceReversed;
    }

    function deployMultipool(DeployArgs memory args) external returns (address multipool) {
        // Multipool mpImpl = new Multipool();
        // ERC1967Proxy proxy =
        //     new ERC1967Proxy(address(mpImpl), abi.encode(args.name, args.symbol, args.startPrice));
        // Multipool mp = Multipool(address(proxy));
        // mp.setSharePriceTTL(60);
        // mp.updateTargetShares(args.assets, args.targetShares);
        // return address(mp);
    }
}
