// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedInfo, FeedType, PriceMath} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32} from "../MultipoolUtils.t.sol";

interface AaveV3 is IERC20 {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    )
        external;
    function withdraw(address asset, uint256 amount, address to) external;
    function symbol() external returns (string memory symbol);
}

interface WETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract MultipoolPriceFetching is Test {
    receive() external payable {}

    uint mainnetFork;
    uint arbitrumFork;

    function setUp() public {
        mainnetFork = vm.createFork("https://eth.llamarpc.com", 18649943);
        arbitrumFork = vm.createFork("https://rpc.ankr.com/arbitrum", 163110835);
    }

    function test_UniswapMakesAnOLDError() public {
        vm.selectFork(arbitrumFork);
        uint value = PriceMath.getTwapX96(0x1eE25aDA6ee9Aa7B2c56d05DAb5Be476752605Fd, false, 10);
        assertEq(value, 486107010125295881900198823811751);
    }

    function test_FetchUniV3BtcUsdcPriceFromFork() public {
        vm.selectFork(mainnetFork);
        uint value = PriceMath.getTwapX96(0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16, false, 10);
        assertEq(value, 29858810448917344803265037855156);
        value = PriceMath.getTwapX96(0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16, false, 0);
        assertEq(value, 29859308799385945179161724149505);
        value = PriceMath.getTwapX96(0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16, true, 0);
        assertEq(value, 210222606878152818093314633);
    }

    function test_CheckAvaraGas() public {
        vm.selectFork(mainnetFork);
        IERC20 aaveETH = IERC20(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);

        console.log("balance", address(this).balance);
        WETH weth = WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        weth.deposit{value: 20e18}();
        uint bal = weth.balanceOf(address(this));
        console.log("balance", bal);
        AaveV3 ethPool = AaveV3(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);

        weth.approve(address(ethPool), 10e18);
        ethPool.supply(address(weth), 5e18, address(this), 0);
        ethPool.supply(address(weth), 5e18, address(this), 0);

        console.log("A balance: ", aaveETH.balanceOf(address(this)));

        ethPool.withdraw(address(weth), 10e18, address(this));

        console.log("A balance: ", aaveETH.balanceOf(address(this)));
    }
}
