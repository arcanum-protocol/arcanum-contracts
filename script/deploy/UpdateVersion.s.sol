// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../../src/multipool/MultipoolRouter.sol";
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

// forge script ./script/deploy/UpdateVersion.s.sol --rpc-url=https://monad-testnet.g.alchemy.com/v2/c_34X8mrHf2CeUbKJyRn9El7loLauTbU --broadcast -vvvv
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
        Multipool mp = new Multipool();

        // MultipoolFactory mpF = new MultipoolFactory();
        MultipoolFactory oldF =  MultipoolFactory(0x7eFe6656d08f2d6689Ed8ca8b5A3DEA0efaa769f);
        // console2.log(oldF.owner());
        // console2.log(deployerPublicKey);
        oldF.updateImplementationAddress(address(mp));
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
