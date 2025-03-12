// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";
import {ReceiverData} from "../../src/types/ReceiverData.sol";
import {MultipoolUtils, toX96, toX32, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract HappyPathTests is Test, MultipoolUtils {
    receive() external payable {}

    function test_SimpleSwap() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );
        vm.prank(user0);
        tokens[1].transfer(address(mp), 2e6);

        snapMultipool("SimpleSwap1");
        swap(user0, token1, token0, true, 1e6);
        snapMultipool("SimpleSwap2");
        swap(user0, token1, token0, true, 1e6);
        snapMultipool("SimpleSwap3");
    }

    function test_BasicErrors() public {
        bootstrapMultipool(
            vec([token0, token1, token2, token3, token4]),
            vec([uint(400e18), 300e18, 300e18, 300e18, 300e18]),
            vec([toX96(10e18), toX96(20e18), toX96(5e18), toX96(2.5e18), toX96(10e18)]),
            vec([1000, 1000, 1000, 1000, 1000])
        );
        vm.prank(user0);
        tokens[1].transfer(address(mp), 2e6);

        vm.expectRevert(abi.encodeWithSignature("AssetsAreSame()"));
        swap(user0, token1, token1, true, 1e6);

        vm.expectRevert(abi.encodeWithSignature("ZeroAmountSupplied()"));
        swap(user0, token1, token0, true, 0);

        vm.expectRevert();
        mp.initialize("Name", "SYMBOL", address(0), uint96(toX32(0.1e18)));

        ERC1967Proxy proxy = new ERC1967Proxy(address(mpImpl), "");

        Multipool notInitialized = Multipool(address(proxy));

        ReceiverData memory rd;
        rd.receiverAddress = user0;
        rd.refundAddress = user0;
        rd.refundEthToReceiver = true;

        // vm.expectRevert();
        notInitialized.initialize("Name", "SYMBOL", address(1), uint96(toX32(0.1e18)));

        // vm.expectRevert("Initializable: contract is already initialized");
        // notInitialized.swap{value: 0.2e18}(op, address(token0), address(token1), 1e18, true, rd);
    }
}
