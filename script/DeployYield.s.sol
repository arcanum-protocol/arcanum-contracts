// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/multipool/Multipool.sol";
import "../src/multipool/MultipoolRouter.sol";
import "../src/multipool/SiloAdapter.sol";
import {MockERC20, MockERC20WithDecimals} from "../src/mocks/erc20.sol";
import {UniV3Feed} from "../src/lib/Price.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {toX96, toX32, sort, dynamic, updatePrice} from "../test/MultipoolUtils.t.sol";

contract MigrateYieldAdapter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SiloPriceAdapter siloAdapterImpl = new SiloPriceAdapter();
        SiloPriceAdapter siloAdapter =
            SiloPriceAdapter(address(0x5F127Aedf5A31E2F2685E49618D4f4809205fd62));
        siloAdapter.upgradeTo(address(siloAdapterImpl));
        vm.stopBroadcast();
    }
}

contract MintYield is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        Multipool yield = Multipool(0x71b9d28384aEb0949Fe9Ee3a1d52F27034E1F976);

        MultipoolRouter router = MultipoolRouter(0x36eBe888Dc501e3A764f1c4910B13AAF8efD0583);

        address asset = address(0x96E1301bd2536A3C56EBff8335FD892dD9bD02dC);

        ERC20(asset).transfer(address(yield), 29135778);

        ForcePushArgs memory fp;
        MultipoolRouter.SwapArgs memory ar = MultipoolRouter.SwapArgs({
            forcePushArgs: fp,
            assetsToSwap: sort(
                dynamic(
                    [
                        AssetArgs({assetAddress: address(asset), amount: int(29135778)}),
                        AssetArgs({assetAddress: address(yield), amount: -1e10})
                    ]
                )
            ),
            isExactInput: true,
            refundAddress: deployerPublicKey,
            refundEthToReceiver: true,
            receiverAddress: deployerPublicKey,
            ethValue: 0.1e18
        });

        MultipoolRouter.Call[] memory params;

        router.swap{value: 0.1e18}(address(yield), ar, params, params);
        console.log(yield.balanceOf(deployerPublicKey));
        vm.stopBroadcast();
    }
}

contract UpdateYieldPrices is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Multipool yield = Multipool(0x71b9d28384aEb0949Fe9Ee3a1d52F27034E1F976);

        address[] memory tokenAddresses = new address[](4);
        tokenAddresses[0] = address(0x96E1301bd2536A3C56EBff8335FD892dD9bD02dC);
        tokenAddresses[1] = address(0xE9B35c753b6Ec9b5a4bBd8c385d16cDb19517185);
        tokenAddresses[2] = address(0xAf06C6106D3a202AD53a4584189e3Dd37E4D2735);
        tokenAddresses[3] = address(0x51DdFa50752782089d032DD293e4650dAf16F151);

        FeedType[] memory feedTypes = new FeedType[](4);
        feedTypes[0] = FeedType.Adapter;
        feedTypes[1] = FeedType.Adapter;
        feedTypes[2] = FeedType.Adapter;
        feedTypes[3] = FeedType.Adapter;

        address siloAdapter = address(0x5F127Aedf5A31E2F2685E49618D4f4809205fd62);

        bytes[] memory feedData = new bytes[](4);
        feedData[0] = abi.encode(address(siloAdapter), uint256(0));
        feedData[1] = abi.encode(address(siloAdapter), uint256(1));
        feedData[2] = abi.encode(address(siloAdapter), uint256(2));
        feedData[3] = abi.encode(address(siloAdapter), uint256(3));

        yield.updatePrices(tokenAddresses, feedTypes, feedData);
        vm.stopBroadcast();
    }
}

contract DeployYield is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("ORACLE_PUBLIC_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        Multipool mpImpl = Multipool(0xb2720Db48102082AE1278D03150d804E71529997);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(mpImpl),
            abi.encodeWithSignature(
                "initialize(string,string,uint128)",
                "Arcanum Yielded ETF",
                "YIELD",
                uint128(toX96(0.0004e18))
            )
        );
        Multipool mp = Multipool(address(proxy));

        console.log("YIELD address: ", address(mp));
        console.log("Instructions address: ", address(mpImpl));

        mp.setAuthorityRights(deployerPublicKey, false, true);
        mp.setAuthorityRights(oracleAddress, true, false);
        mp.setSharePriceParams(600, 0);

        address[] memory tokenAddresses = new address[](4);
        tokenAddresses[0] = address(0x96E1301bd2536A3C56EBff8335FD892dD9bD02dC);
        tokenAddresses[1] = address(0xE9B35c753b6Ec9b5a4bBd8c385d16cDb19517185);
        tokenAddresses[2] = address(0xAf06C6106D3a202AD53a4584189e3Dd37E4D2735);
        tokenAddresses[3] = address(0x51DdFa50752782089d032DD293e4650dAf16F151);

        FeedType[] memory feedTypes = new FeedType[](4);
        feedTypes[0] = FeedType.Adapter;
        feedTypes[1] = FeedType.Adapter;
        feedTypes[2] = FeedType.Adapter;
        feedTypes[3] = FeedType.Adapter;

        address siloAdapter = address(0xe20e7B352283b8735D85C9138b02d33016370635);

        bytes[] memory feedData = new bytes[](4);
        feedData[0] = abi.encode(address(siloAdapter), uint256(0));
        feedData[1] = abi.encode(address(siloAdapter), uint256(1));
        feedData[2] = abi.encode(address(siloAdapter), uint256(2));
        feedData[3] = abi.encode(address(siloAdapter), uint256(3));

        uint[] memory targetShares = new uint[](4);
        targetShares[0] = 100;
        targetShares[1] = 100;
        targetShares[2] = 100;
        targetShares[3] = 100;

        mp.updatePrices(tokenAddresses, feedTypes, feedData);
        mp.updateTargetShares(tokenAddresses, targetShares);

        mp.setFeeParams(
            toX32(0.15e18),
            toX32(0.0003e18),
            toX32(0.6e18),
            toX32(0.0001e18),
            toX32(0.15e18),
            deployerPublicKey
        );
        vm.stopBroadcast();
    }
}

contract DeploySiloAdapter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        address siloLens = address(0xBDb843c7a7e48Dc543424474d7Aa63b61B5D9536);

        SiloPriceAdapter siloAdapterImpl = new SiloPriceAdapter();
        ERC1967Proxy siloAdapterProxy = new ERC1967Proxy(
            address(siloAdapterImpl),
            abi.encodeWithSignature("initialize(address,address)", deployerPublicKey, siloLens)
        );
        SiloPriceAdapter siloAdapter = SiloPriceAdapter(address(siloAdapterProxy));

        console.log("Silo adapter address: ", address(siloAdapter));
        console.log("Silo adapter impl address: ", address(siloAdapterImpl));

        address usdc = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

        FeedInfo memory baseFeed = FeedInfo({
            kind: FeedType.UniV3,
            data: abi.encode(
                UniV3Feed({
                    oracle: address(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443),
                    reversed: true,
                    twapInterval: 60
                })
            )
        });

        siloAdapter.createFeed(usdc, ISilo(0xDe998E5EeF06dD09fF467086610B175F179A66A0), baseFeed);
        siloAdapter.createFeed(usdc, ISilo(0x19d3F8D09773065867e9fD11716229e73481c55A), baseFeed);
        siloAdapter.createFeed(usdc, ISilo(0xaee935408b94bae1Ce4eA15d22b3cA33c91eFe81), baseFeed);
        siloAdapter.createFeed(usdc, ISilo(0x5C2B80214c1961dB06f69DD4128BcfFc6423d44F), baseFeed);

        vm.stopBroadcast();
    }
}

contract AddSiloAdapterPrices is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SiloPriceAdapter siloAdapter =
            SiloPriceAdapter(address(0x5F127Aedf5A31E2F2685E49618D4f4809205fd62));

        address usdc = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

        FeedInfo memory baseFeed = FeedInfo({
            kind: FeedType.UniV3,
            data: abi.encode(
                UniV3Feed({
                    oracle: address(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443),
                    reversed: false,
                    twapInterval: 60
                })
            )
        });

        siloAdapter.createFeed(usdc, ISilo(0xDe998E5EeF06dD09fF467086610B175F179A66A0), baseFeed);
        siloAdapter.createFeed(usdc, ISilo(0x19d3F8D09773065867e9fD11716229e73481c55A), baseFeed);
        siloAdapter.createFeed(usdc, ISilo(0xaee935408b94bae1Ce4eA15d22b3cA33c91eFe81), baseFeed);
        siloAdapter.createFeed(usdc, ISilo(0x5C2B80214c1961dB06f69DD4128BcfFc6423d44F), baseFeed);

        Multipool yield = Multipool(0x71b9d28384aEb0949Fe9Ee3a1d52F27034E1F976);

        address[] memory tokenAddresses = new address[](4);
        tokenAddresses[0] = address(0x96E1301bd2536A3C56EBff8335FD892dD9bD02dC);
        tokenAddresses[1] = address(0xE9B35c753b6Ec9b5a4bBd8c385d16cDb19517185);
        tokenAddresses[2] = address(0xAf06C6106D3a202AD53a4584189e3Dd37E4D2735);
        tokenAddresses[3] = address(0x51DdFa50752782089d032DD293e4650dAf16F151);

        FeedType[] memory feedTypes = new FeedType[](4);
        feedTypes[0] = FeedType.Adapter;
        feedTypes[1] = FeedType.Adapter;
        feedTypes[2] = FeedType.Adapter;
        feedTypes[3] = FeedType.Adapter;

        bytes[] memory feedData = new bytes[](4);
        feedData[0] = abi.encode(address(siloAdapter), uint256(4));
        feedData[1] = abi.encode(address(siloAdapter), uint256(5));
        feedData[2] = abi.encode(address(siloAdapter), uint256(6));
        feedData[3] = abi.encode(address(siloAdapter), uint256(7));

        yield.updatePrices(tokenAddresses, feedTypes, feedData);

        vm.stopBroadcast();
    }
}
