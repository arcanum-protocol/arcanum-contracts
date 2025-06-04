// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import {MultipoolRouter, SwapArgs, Call, CallType, TokenTransferParams, RouterApproveParams} from "../../src/multipool/MultipoolRouter.sol";
import {MockERC20, MockERC20WithDecimals} from "../../src/mocks/erc20.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {MultipoolFactory, MultipoolCreationParams} from "../../src/multipool/Factory.sol";
import {Trader, WETH} from "../../src/trader/Trader.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {IUniswapV3Pool} from "uniswapv3/interfaces/IUniswapV3Pool.sol";
import {ICashbackVault} from "../../src/interfaces/ICashbackVault.sol";
import {
    toX96,
    toX32,
    toX16,
    toX16RatioTick,
    updatePrice,
    AbstractFixedValueOracle,
    computeContractAddress
} from "../../test/MultipoolUtils.t.sol";

// forge script ./script/deploy/SwapWithRouter.s.sol --rpc-url=https://monad-testnet.g.alchemy.com/v2/c_34X8mrHf2CeUbKJyRn9El7loLauTbU --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerPublicKey = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        // ERC20(0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701).approve(0xd891511937A96Fb2c6439F52f76cD777D08e7E1C,
        // 5000000000000000000000000);

        // Trader t = Trader(payable(0xF69ae94063f4671Ea4e4b9f8c97eb1aAC1731cb8));
        // address[] memory assets = new address[](2);
        // assets[0] = 0xfe140e1dCe99Be9F4F15d657CD9b7BF622270C50;
        // assets[1] = 0x0F0BDEbF0F83cD1EE3974779Bcb7315f9808c714;
        // Trader.Call memory call;
        // OraclePrice memory op;

        // Trader.Args memory args = Trader.Args({
        //     tokenIn: IERC20(0xfe140e1dCe99Be9F4F15d657CD9b7BF622270C50),
        //     tokenOut: IERC20(0x0F0BDEbF0F83cD1EE3974779Bcb7315f9808c714),
        //     multipoolTokenIn: IERC20(0xfe140e1dCe99Be9F4F15d657CD9b7BF622270C50),
        //     multipoolTokenOut: IERC20(0x0F0BDEbF0F83cD1EE3974779Bcb7315f9808c714),
        //     firstCall: call,
        //     secondCall: call,
        //     tmpAmount: 7122037360531260792759,
        //     poolIn: IUniswapV3Pool(0xf5E71C63967570Ff6fa4Db961F95e612b54CBe47),
        //     zeroForOneIn: true,
        //     poolOut: IUniswapV3Pool(0xD3e12DA98c889f43e8Cc241fc928f9B46a28A89f),
        //     zeroForOneOut: true,
        //     multipoolFee: 0e18,
        //     multipool: Multipool(0x057A931a8Ab1111fF163745De18040dc0b35F153),
        //     // oraclePrice: OraclePrice ({ contractAddress:
        //     // 0x057a931a8ab1111ff163745de18040dc0b35f153, timestamp: 0, sharePrice:
        //     // 32397986637830420594633729233, signature: 0 }),
        //     oraclePrice: op,
        //     gasLimit: 4000000,
        //     weth: WETH(0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701),
        //     cashback: ICashbackVault(0x0000000000000000000000000000000000000000),
        //     assets: assets
        // });

        // Trader.Args memory args = Trader.Args ({
        //     tokenIn: IERC20(0x0F0BDEbF0F83cD1EE3974779Bcb7315f9808c714),
        //     tokenOut: IERC20(0xfe140e1dCe99Be9F4F15d657CD9b7BF622270C50),
        //     multipoolTokenIn: IERC20(0x0F0BDEbF0F83cD1EE3974779Bcb7315f9808c714),
        //     multipoolTokenOut: IERC20(0xfe140e1dCe99Be9F4F15d657CD9b7BF622270C50),
        //     firstCall: call,
        //     secondCall: call,
        //     tmpAmount: 6675866284633758348,
        //     poolIn: IUniswapV3Pool(0x00F26C926345D6F8e1BfCa684873C35070DC49Fd),
        //     zeroForOneIn: false,
        //     poolOut: IUniswapV3Pool(0x405442CAf9e121B2b3f69d1f4c89544d2b9582cf),
        //     zeroForOneOut: false,
        //     multipoolFee: 0e18,
        //     multipool: Multipool(0x057A931a8Ab1111fF163745De18040dc0b35F153),
        //     // oraclePrice: OraclePrice ({ contractAddress:
        // 0x057a931a8ab1111ff163745de18040dc0b35f153, timestamp: 0, sharePrice:
        // 32397986637830420594633729233, signature: 0 }),
        //     oraclePrice: op,
        //     gasLimit: 4000000,
        //     weth: WETH(0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701),
        //     cashback: ICashbackVault(0x0000000000000000000000000000000000000000),
        //     assets: assets
        // });

        // t.trade{value: 1e18}(args);
        // console.log(address(t));

        // MultipoolRouter r = new MultipoolRouter(0x7eFe6656d08f2d6689Ed8ca8b5A3DEA0efaa769f);
        // console.log(address(r));
        // Multipool mp = new Multipool();

        // MultipoolFactory mpF = new MultipoolFactory();
        // MultipoolFactory oldF =  MultipoolFactory(0x7eFe6656d08f2d6689Ed8ca8b5A3DEA0efaa769f);
        OraclePrice memory op;
        SwapArgs memory s = SwapArgs({
            oraclePrice: op,
            assetIn: 0xb2f82D0f38dc453D596Ad40A37799446Cc89274A,
            assetOut: 0x8435316b1408D0fF946a46A44BC3188202a37532,
            swapAmount: 652808536804149600,
            isExactInput: true,
            receiverAddress: 0xAd19c4Ac757CA1da80999E21Cf8955C6Ea5C6D80,
            refundAddress: 0xAd19c4Ac757CA1da80999E21Cf8955C6Ea5C6D80,
            refundEthToReceiver: true,
            ethValue: 10000000000000000,
            minimumReceive: 0

        });
        Call[] memory callsBefore = new Call[](3);
        callsBefore[0] = Call({
            callType: CallType.ERC20Transfer,
            data: abi.encode(
                TokenTransferParams({token: address(0xf817257fed379853cDe0fa4F97AB987181B1E5Ea), targetOrOrigin: 0xFcAe79Fd886a4D40aea47cf3EcA89fDE65B97A79, amount: 1e6})
            )
            // data: vm.parseBytes("0x000000000000000000000000f817257fed379853cde0fa4f97ab987181b1e5ea000000000000000000000000fcae79fd886a4d40aea47cf3eca89fde65b97a7900000000000000000000000000000000000000000000000000000000000f4240")
        });
        callsBefore[1] = Call({
            callType: CallType.ERC20Approve,
            data: abi.encode(
                RouterApproveParams({token: address(0xf817257fed379853cDe0fa4F97AB987181B1E5Ea), target: 0x4c4eABd5Fb1D1A7234A48692551eAECFF8194CA7, amount: 1e6})
            )
            // data: vm.parseBytes("0x000000000000000000000000f817257fed379853cde0fa4f97ab987181b1e5ea000000000000000000000000fcae79fd886a4d40aea47cf3eca89fde65b97a7900000000000000000000000000000000000000000000000000000000000f4240")
        });

        //         address tokenIn;
        // address tokenOut;
        // uint24 fee;
        // address recipient;
        // uint256 amountIn;
        // uint256 amountOutMinimum;
        // uint160 sqrtPriceLimitX96;
        // bytes memory call = abi.encodeWithSignature("exactInputSingle(address tokenIn,address tokenOut,uint24 fee,address recipient,uint256 amountIn,uint256 amountOutMinimum,uint160 sqrtPriceLimitX96)")
        callsBefore[2] = Call({
            callType: CallType.Any,
            data: vm.parseBytes("0x0000000000000000000000003ae6d8a282d67893e17aa70ebffb33ee5aa6589300000000000000000000000000000000000000000000000000000000000186a000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000144c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000008435316b1408d0ff946a46a44bc3188202a3753200000000000000000000000000000000000000000000000000000000684456cb00000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000903b40b96c293050000000000000000000000000000000000000000000000000000000000000042f817257fed379853cde0fa4f97ab987181b1e5ea000064760afe86e5de5fa0ee542fc7b7b713e1c5425701000064b2f82d0f38dc453d596ad40a37799446cc89274a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
        });
        Call[] memory callsAfter = new Call[](0);
        MockERC20(0xf817257fed379853cDe0fa4F97AB987181B1E5Ea).approve(0xFcAe79Fd886a4D40aea47cf3EcA89fDE65B97A79, 1e33);
        MultipoolRouter r =  MultipoolRouter(0xFcAe79Fd886a4D40aea47cf3EcA89fDE65B97A79);
        r.swap{value: 1e18}(0x8435316b1408D0fF946a46A44BC3188202a37532, s, callsBefore, callsAfter);

        
        // console2.log(oldF.owner());
        // console2.log(deployerPublicKey);
        // oldF.updateImplementationAddress(address(mp));
        // oldF.upgradeTo(address(mpF));
        // Multipool mp = Multipool(0x6360f1F5A784B4cf752bf136C62BC3e1E04fdD40);
        // (address[] memory a, uint o) = mp.getUsedAssets(1000, 0);
        // console2.log(a[0]);
        // console2.log(a[1]);
        // console2.log(a[2]);
        // console2.log(a[3]);
        // console2.log(a[4]);
        // console2.log(a[5]);
        // console2.log(a[6]);
        // (bytes32 mpFees1, bytes32 mpFees2, address managerFeeReceiver, address lpFeeReceiver, uint total) = mp.getConfig();
        // (        address oracleAddress,
        // uint deviationIncreaseFee,
        // uint feeToCashbackRatio,
        // uint baseFee,
        // uint lpFee,
        // uint managementFee
        // ) = unpackMpFees1(mpFees1);
        // console2.log(baseFee);

        vm.stopBroadcast();
    }
}
