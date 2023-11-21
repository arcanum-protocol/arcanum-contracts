//// SPDX-License-Identifier: GPL-3.0
//pragma solidity ^0.8.0;
//
//import {Test} from "forge-std/Test.sol";
//
//import {CommonBase} from "forge-std/Base.sol";
//import {StdCheats} from "forge-std/StdCheats.sol";
//import {StdUtils} from "forge-std/StdUtils.sol";
//
//import {MockERC20} from "../src/mocks/erc20.sol";
//import {Multipool, MpContext, MpAsset} from "../src/multipool/Multipool.sol";
//import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
//import {FeedInfo, FeedType} from "../src/multipool/PriceMath.sol";
//
//import { ECDSA } from "openzeppelin/utils/cryptography/ECDSA.sol";
//import { MessageHashUtils } from "openzeppelin/utils/cryptography/MessageHashUtils.sol";
//
//import { toX96, toX32 } from "./MultipoolUtils.t.sol";
//
//contract Handler is CommonBase, StdCheats, StdUtils {
//    Multipool mp;
//    MockERC20[] tokens;
//    address[] users;
//    uint tokenNum;
//    uint userNum;
//    address owner;
//    uint ownerPk;
//
//    address[] actors;
//    address[] assets;
//
//    address internal currentActor;
//
//    modifier useActor(uint256 actorIndexSeed) {
//        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
//        vm.startPrank(currentActor);
//        _;
//        vm.stopPrank();
//    }
//
//    constructor () {
//        Multipool mpImpl = new Multipool();
//        ERC1967Proxy proxy = new ERC1967Proxy(address(mpImpl), "");
//        mp = Multipool(address(proxy));
//        mp.initialize("Name", "SYMBOL", address(this), toX96(0.1e18));
//
//        tokenNum = 5;
//        userNum = 4;
//
//        (owner, ownerPk) = makeAddrAndKey("Multipool owner");
//        mp.transferOwnership(owner);
//       
//        actors.push(owner);
//
//        for (uint i; i < tokenNum; i++) {
//            tokens.push(new MockERC20('token', 'token', 0));
//            assets.push(address(tokens[i]));
//        }
//        for (uint i; i < userNum; i++) {
//            users.push(makeAddr(string(abi.encode(i))));
//            actors.push(users[i]);
//        }
//        for (uint u; u < userNum; u++) {
//            for (uint t; t < tokenNum; t++) {
//                tokens[t].mint(users[u], 10000000000e18);
//            }
//        }
//        assets.push(address(mp));
//    }
//
//   // function swap(uint quoteValue, uint receiverIndex) external {
//   //     Multipool.AssetArg[] memory args = new Multipool.AssetArg[](assetNumber);
//   //     for(uint i; i < assetsIndexes.length; ++i)
//   //         assetsIndexes[i] = bound(assetsIndexes[i], 0, assets.length - 1);
//
//   //     assetNumber = bound(assetNumber, 0, 6);
//   //     for(uint i; i < assetNumber; ++i) {
//   //         args[i] = Multipool.AssetArg({
//   //             addr: assets[assetsIndexes[i]],
//   //             amount: amounts[i]
//   //             //amount: bound(amounts[i]),
//   //         });
//   //     }
//   //     receiverIndex = bound(receiverIndex, 0, actors.length-1);
//   //     Multipool.FPSharePriceArg memory fp;
//   //     mp.swap(fp, args, false, actors[receiverIndex], true, address(0));
//   // }
//
//    function updatePrice() external {
//    }
//
//    function updateCurveParams() external {
//    }
//}
//
//contract MultipoolInvariantTests is Test {
//
//    Handler h;
//
//    function setUp() public {
//        h = new Handler();
//        targetContract(address(h));
//    }
//
//    function invariant_multipool() external {
//        
//    }
//}
