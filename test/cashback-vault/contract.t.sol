// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {FeedInfo, FeedType} from "../../src/lib/Price.sol";
import {MultipoolUtils, toX96, toX32, sort, dynamic, updatePrice} from "../MultipoolUtils.t.sol";
import {ForcePushArgs, AssetArgs} from "../../src/types/SwapArgs.sol";

import {CashbackVault} from "../../src/cashback-vault/CashbackVault.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract MultipoolCoreDeviationTests is Test, MultipoolUtils {
    receive() external payable {}

    function test_CheckCashbackIncreaseForRealMultipool() public {
        bootstrapTokens([uint(400e18), 300e18, 400e18, 300e18, 300e18], users[3]);

        skip(10000);

        CashbackVault vaultImpl = new CashbackVault();
        CashbackVault vault = CashbackVault(
            address(
                new ERC1967Proxy(
                    address(vaultImpl),
                    abi.encodeWithSignature("initialize(address)", address(this))
                )
            )
        );

        vm.expectRevert();
        vault.updateDistributionParams{value: 1e18}(address(mp), 0.01e18, 2e18, 10e18);

        vault.updateDistributionParams{value: 10e18}(address(mp), 0.01e18, 2e18, 10e18);

        address[] memory cbTokens = new address[](2);
        cbTokens[0] = address(tokens[0]);
        cbTokens[1] = address(tokens[1]);

        uint[] memory cashbackValue = vault.payCashback(address(mp), cbTokens);
        assertEq(2, cashbackValue.length);
        assertEq(2e18, cashbackValue[0]);
        assertEq(2e18, cashbackValue[1]);

        cashbackValue = vault.payCashback(address(mp), cbTokens);
        assertEq(2, cashbackValue.length);
        assertEq(0e18, cashbackValue[0]);
        assertEq(0e18, cashbackValue[1]);

        skip(2);

        address[] memory cbTokens1 = new address[](1);
        cbTokens1[0] = address(tokens[0]);

        cashbackValue = vault.payCashback(address(mp), cbTokens1);
        assertEq(1, cashbackValue.length);
        assertEq(0.02e18, cashbackValue[0]);

        skip(4);

        cashbackValue = vault.payCashback(address(mp), cbTokens);
        assertEq(2, cashbackValue.length);
        assertEq(0.04e18, cashbackValue[0]);
        assertEq(0.06e18, cashbackValue[1]);

        skip(100000000);

        cashbackValue = vault.payCashback(address(mp), cbTokens);
        assertEq(2, cashbackValue.length);
        assertEq(2e18, cashbackValue[0]);
        assertEq(2e18, cashbackValue[1]);

        skip(100000000);

        vault.updateDistributionParams{value: 10e18}(address(mp), 0.01e18, 2e18, -1.87e18);

        cashbackValue = vault.payCashback(address(mp), cbTokens);
        assertEq(2, cashbackValue.length);
        assertEq(0.01e18, cashbackValue[0]);
        assertEq(0e18, cashbackValue[1]);

        vm.prank(users[0]);
        vm.expectRevert();
        vault.updateDistributionParams{value: 10e18}(address(mp), 0.01e18, 2e18, -1.87e18);

        skip(100000000);

        deal(users[0], 10e18);
        vm.prank(users[0]);
        vault.addBalance{value: 10e18}(address(mp));

        cashbackValue = vault.payCashback(address(mp), cbTokens1);
        assertEq(1, cashbackValue.length);
        assertEq(2e18, cashbackValue[0]);

        cashbackValue = vault.payCashback(address(mp), cbTokens);
        assertEq(2, cashbackValue.length);
        assertEq(0e18, cashbackValue[0]);
        assertEq(2e18, cashbackValue[1]);
    }
}
