// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {MultipoolFactory} from "../../src/multipool/Factory.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract MultipoolCoreDeviationTests is Test {
    receive() external payable {}

    MultipoolFactory factory;
    address owner;
    uint ownerPk;

    address bob;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("Factory owner");
        (bob,) = makeAddrAndKey("Factory worker");
        vm.startPrank(owner);

        Multipool mpImpl = new Multipool();
        MultipoolFactory factoryImplementation = new MultipoolFactory();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(factoryImplementation),
            abi.encodeWithSignature("initialize(address,address)", address(this), mpImpl)
        );
        factory = MultipoolFactory(address(proxy));
        vm.stopPrank();
    }

    function test_HappyPathBuildMultipoolWithFactory() public {
        address[] memory tokens = new address[](3);
        bytes32[] memory prices = new bytes32[](3);
        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = address(4);
        assetAddresses[1] = address(5);
        assetAddresses[2] = address(6);

        uint16[] memory targetShares = new uint16[](3);
        targetShares[0] = 1;
        targetShares[1] = 2;
        targetShares[2] = 3;

        bytes32 val;
        bytes memory data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18)));
        assembly {
            val := mload(add(data, 32))
        }
        prices[0] = val;
        data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(20e18)));
        assembly {
            val := mload(add(data, 32))
        }
        prices[1] = val;
        data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(30e18)));
        assembly {
            val := mload(add(data, 32))
        }
        prices[2] = val;

       Multipool multipool = factory.createMultipool(
           MultipoolFactory.MultipoolCreationParams({
                name: "Test multipool",
                symbol: "TMP",
                initialSharePrice: 123456,
                deviationIncreaseFee: 1,
                deviationLimit: 2,
                feeToCashbackRatio: 1e4,
                baseFee: 4,
                managementFeeRecepient: address(1),
                managementFee: 1,
                oracleAddress: address(0),
                strategyManager: address(0),
                assetAddresses: assetAddresses,
                priceData: prices,
                targetShares: targetShares
           })
       );
       assertEq(multipool.strategyManager(), address(0));

       OraclePrice memory op;
       MpContext memory mc = multipool.getContext(op);

       assertEq(mc.deviationLimit, 429496);
       assertEq(mc.baseFee, 858993);
       assertEq(mc.managementFeeRecepient, address(1));

       assertEq(multipool.getAsset(address(4)).targetShare, 1);
       assertEq(multipool.getAsset(address(5)).targetShare, 2);
       assertEq(multipool.getAsset(address(6)).targetShare, 3);

        data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(10e18)));
        assembly {
            val := mload(add(data, 32))
        }

       assertEq(
           multipool.getPriceFeed(address(4)),
           val
       );
        data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(20e18)));
        assembly {
            val := mload(add(data, 32))
        }
       assertEq(
           multipool.getPriceFeed(address(5)),
           val
       );
        data = abi.encodePacked(FeedType.FixedValue, uint128(toX96(30e18)));
        assembly {
            val := mload(add(data, 32))
        }
       assertEq(
           multipool.getPriceFeed(address(6)),
           val
       );

        multipool = factory.createMultipool(
           MultipoolFactory.MultipoolCreationParams({
                name: "Test multipool",
                symbol: "TMP",
                initialSharePrice: 123456,
                deviationIncreaseFee: 1,
                deviationLimit: 2,
                feeToCashbackRatio: 1e4,
                baseFee: 4,
                managementFeeRecepient: address(1),
                managementFee: 1,
                oracleAddress: address(0),
                strategyManager: address(1),
                assetAddresses: assetAddresses,
                priceData: prices,
                targetShares: targetShares
           })
       );
       assertEq(multipool.strategyManager(), address(1));
       
    }

    function testFail_Permissions() public {
        vm.prank(owner);
        factory.updateImplementationAddress(address(0));
        assertEq(factory.implementationAddress(), address(0));

        vm.prank(bob);
        factory.updateImplementationAddress(address(1));
    }
}
