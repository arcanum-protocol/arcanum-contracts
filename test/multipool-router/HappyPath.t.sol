// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool} from "../../src/multipool/Multipool.sol";
import {Farm} from "../../src/farm/Farm.sol";
import {MultipoolFactory, MultipoolCreationParams} from "../../src/multipool/Factory.sol";
import {
    MultipoolRouter,
    TokenTransferParams,
    Call,
    CallType,
    SwapArgs
} from "../../src/multipool/MultipoolRouter.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {
    MultipoolUtils,
    toX96,
    toX32,
    vec,
    updatePrice,
    computeContractAddress
} from "../MultipoolUtils.t.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract MultipoolRouterTests is Test, MultipoolUtils {
    receive() external payable {}

    function test_HappyPathDeployMPViaRouter() public {
        Farm farm = new Farm();
        MultipoolFactory f = new MultipoolFactory{salt: keccak256("Factory")}();
        Multipool mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy{salt: keccak256("FactoryProxy")}(
            address(f),
            abi.encodeWithSignature("initialize(address,address,address)", address(this), address(mpImpl), address(farm))
        );
        f = MultipoolFactory(address(proxy));
        // f.initialize(owner, address(mpImpl));
        address[] memory assetAddresses = vec([token0, token1, token2]);
        uint16[] memory targetShares = vec([1000, 1000, 1000]);
        bytes32[] memory prices = new bytes32[](3);

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

        vm.prank(owner);
        MultipoolRouter r = new MultipoolRouter(address(f));
        MultipoolCreationParams memory p = MultipoolCreationParams({
            name: "Test multipool",
            symbol: "TMP",
            deviationIncreaseFee: 1,
            deviationLimit: 2,
            feeToCashbackRatio: 1e4,
            baseFee: 4,
            lpFee: 4,
            _managerFeeReceiver: address(0),
            _lpFeeReceiver: address(0),
            managerFee: 1,
            oracleAddress: address(0),
            assetAddresses: assetAddresses,
            priceData: prices,
            targetShares: targetShares,
            initialLiquidityAsset: assetAddresses[0],
            nonce: 1,
            owner: owner,
            protocolFeeReceiver: address(0)
        });

        // get new pool address
        address newPool = computeContractAddress(address(f), address(mpImpl), 1, address(r));
        Call memory c = Call({
            callType: CallType.ERC20Transfer,
            data: abi.encode(
                TokenTransferParams({token: assetAddresses[0], targetOrOrigin: newPool, amount: 1e18})
            )
        });
        Call[] memory preCalls = new Call[](1);
        preCalls[0] = c;
        Call[] memory afterCalls = new Call[](0);

        MockERC20(assetAddresses[0]).mint(user0, 1e18);

        vm.prank(user0);
        MockERC20(assetAddresses[0]).approve(address(r), 10e18);

        vm.prank(user0);
        r.createMultipool(p, preCalls, afterCalls);
    }

    function test_HappyPathSwapViaRouter() public {
        Farm farm = new Farm();
        MultipoolFactory f = new MultipoolFactory{salt: keccak256("Factory")}();
        Multipool mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy{salt: keccak256("FactoryProxy")}(
            address(f),
            abi.encodeWithSignature("initialize(address,address,address)", address(this), address(mpImpl), address(farm))
        );
        f = MultipoolFactory(address(proxy));
        vm.prank(owner);
        MultipoolRouter r = new MultipoolRouter(address(f));
        {
            {
                // f.initialize(owner, address(mpImpl));
                address[] memory assetAddresses = vec([token0, token1, token2]);
                uint16[] memory targetShares = vec([1000, 1000, 1000]);
                bytes32[] memory prices = new bytes32[](3);

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

                MultipoolCreationParams memory p = MultipoolCreationParams({
                    name: "Test multipool",
                    symbol: "TMP",
                    assetAddresses: assetAddresses,
                    priceData: prices,
                    deviationIncreaseFee: 1,
                    deviationLimit: 2,
                    feeToCashbackRatio: 1e4,
                    baseFee: 4,
                    managerFee: 1,
                    lpFee: 1,
                    _managerFeeReceiver: address(0),
                    _lpFeeReceiver: address(0),
                    oracleAddress: address(0),
                    targetShares: targetShares,
                    initialLiquidityAsset: address(0),
                    nonce: 1,
                    owner: owner,
                    protocolFeeReceiver: address(0)
                });

                Call[] memory preCalls = new Call[](0);
                Call[] memory afterCalls = new Call[](0);

                vm.prank(user0);
                r.createMultipool(p, preCalls, afterCalls);
            }
        }

        address newPool = computeContractAddress(address(f), address(mpImpl), 1, address(r));
        MockERC20(token0).mint(user0, 1e18);

        vm.prank(user0);
        MockERC20(token0).approve(address(r), 10e18);

        OraclePrice memory op;
        SwapArgs memory sa = SwapArgs({
            oraclePrice: op,
            assetIn: address(token0),
            assetOut: address(newPool),
            swapAmount: 1e10,
            isExactInput: true,
            receiverAddress: user0,
            refundAddress: address(0),
            refundEthToReceiver: true,
            ethValue: 1e9,
            minimumReceive: 0
        });

        Call memory c = Call({
            callType: CallType.ERC20Transfer,
            data: abi.encode(
                TokenTransferParams({token: address(token0), targetOrOrigin: newPool, amount: 1e18})
            )
        });
        Call[] memory preSwapCalls = new Call[](1);
        preSwapCalls[0] = c;
        Call[] memory afterSwapCalls = new Call[](0);
        console2.log("here");
        vm.prank(user0);
        r.swap{value: 1e10}(newPool, sa, preSwapCalls, afterSwapCalls);
    }
}
