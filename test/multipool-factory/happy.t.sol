// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MultipoolFactory} from "../../src/multipool/Factory.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

import {UniV3Feed} from "../../src/lib/Price.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract MultipoolCoreDeviationTests is Test {
    receive() external payable {}

    MultipoolFactory factory;

    function setUp() public {
        Multipool mpImpl = new Multipool();
        MultipoolFactory factoryImplementation = new MultipoolFactory();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(factoryImplementation),
            abi.encodeWithSignature("initialize(address,address)", address(this), mpImpl)
        );
        factory = MultipoolFactory(address(proxy));
    }

    function test_HappyPathBuildMultipoolWithFactory() public {
        address[] memory oracleAddresses = new address[](3);
        oracleAddresses[0] = address(1);
        oracleAddresses[1] = address(2);
        oracleAddresses[2] = address(3);

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(4);
        assetAddresses[1] = address(5);
        assetAddresses[2] = address(6);

        uint[] memory targetShares = new uint[](3);
        targetShares[0] = 1;
        targetShares[1] = 2;
        targetShares[2] = 3;

        FeedType[] memory feedTypes = new FeedType[](3);
        feedTypes[0] = FeedType.UniV3;
        feedTypes[1] = FeedType.UniV3;
        feedTypes[2] = FeedType.UniV3;

        bytes[] memory feedData = new bytes[](3);
        feedData[0] = abi.encode(
            UniV3Feed({
                oracle: address(0x1aEEdD3727A6431b8F070C0aFaA81Cc74f273882),
                reversed: true,
                twapInterval: 60
            })
        );
        feedData[1] = abi.encode(
            UniV3Feed({
                oracle: address(0x446BF9748B4eA044dd759d9B9311C70491dF8F29),
                reversed: false,
                twapInterval: 60
            })
        );
        feedData[2] = abi.encode(
            UniV3Feed({
                oracle: address(0xd3E11119d2680c963F1CDCffeCe0c4adE823Fb58),
                reversed: false,
                twapInterval: 60
            })
        );

        factory.spawnMultipool(
            MultipoolFactory.MultipoolSetupArgs({
                name: "Test multipool",
                symbol: "TMP",
                signatureThershold: 3,
                sharePriceValidity: 600,
                initialSharePrice: 123456,
                halfDeviationFee: 1,
                deviationLimit: 2,
                depegBaseFee: 3,
                baseFee: 4,
                developerBaseFee: 5,
                developerAddress: address(1),
                oracleAddresses: oracleAddresses,
                assetAddresses: assetAddresses,
                priceFeedKinds: feedTypes,
                feedData: feedData,
                targetShares: targetShares
            })
        );

        Multipool multipool = Multipool(factory.multipools(0));
        assertEq(multipool.isPaused(), false);
        (
            uint64 deviationParam,
            uint64 deviationLimit,
            uint64 depegBaseFee,
            uint64 baseFee,
            uint64 developerBaseFee,
            address developerAddress
        ) = multipool.getFeeParams();

        assertEq(deviationParam, 2147483648);
        assertEq(deviationLimit, 2);
        assertEq(depegBaseFee, 3);
        assertEq(baseFee, 4);
        assertEq(developerBaseFee, 5);
        assertEq(developerAddress, address(1));

        assertEq(multipool.getAsset(address(4)).targetShare, 1);
        assertEq(multipool.getAsset(address(5)).targetShare, 2);
        assertEq(multipool.getAsset(address(6)).targetShare, 3);

        assertEq(
            keccak256(abi.encode(multipool.getPriceFeed(address(4)))),
            keccak256(abi.encode(FeedInfo({kind: feedTypes[0], data: feedData[0]})))
        );
        assertEq(
            keccak256(abi.encode(multipool.getPriceFeed(address(5)))),
            keccak256(abi.encode(FeedInfo({kind: feedTypes[1], data: feedData[1]})))
        );
        assertEq(
            keccak256(abi.encode(multipool.getPriceFeed(address(6)))),
            keccak256(abi.encode(FeedInfo({kind: feedTypes[2], data: feedData[2]})))
        );

        assertEq(multipool.isTargetShareSetter(address(1)), false);
        assertEq(multipool.isTargetShareSetter(address(2)), false);
        assertEq(multipool.isTargetShareSetter(address(3)), false);

        assertEq(multipool.isPriceSetter(address(1)), true);
        assertEq(multipool.isPriceSetter(address(2)), true);
        assertEq(multipool.isPriceSetter(address(3)), true);
    }
}
