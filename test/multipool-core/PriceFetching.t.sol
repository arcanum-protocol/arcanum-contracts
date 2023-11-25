// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedInfo, FeedType, PriceMath} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32} from "../MultipoolUtils.t.sol";

contract MultipoolPriceFetching is Test {
    receive() external payable {}

    uint mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("https://eth.llamarpc.com", 18649943);
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
}
