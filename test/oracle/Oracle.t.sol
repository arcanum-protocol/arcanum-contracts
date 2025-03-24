// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import {Oracle} from "../../src/multipool/Oracle.sol";
import {FeedType} from "../../src/lib/Price.sol";
import {OraclePrice} from "../../src/types/OraclePrice.sol";
import {FraudSlot, OracleData} from "../../src/types/Oracle.sol";
import {MultipoolUtils, toX96, toX32, vec, updatePrice} from "../MultipoolUtils.t.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract OracleTests is Test {
    using ECDSA for bytes32;

    receive() external payable {}

    Oracle oracle;
    MockERC20 token;

    address owner;
    uint ownerPk;

    address alice;
    address bob;

    address provider1;
    uint provider1Pk;

    address provider2;
    uint provider2Pk;

    address provider3;
    uint provider3Pk;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("Owner");
        (alice,) = makeAddrAndKey("Alice");
        (bob,) = makeAddrAndKey("Bob");
        (provider1, provider1Pk) = makeAddrAndKey("PriceProvider1");
        (provider2, provider2Pk) = makeAddrAndKey("PriceProvider2");
        (provider3, provider3Pk) = makeAddrAndKey("PriceProvider3");

        vm.startPrank(owner);

        token = new MockERC20("token", "token", 0);
        token.mint(alice, 2000e18);
        token.mint(bob, 2000e18);

        Oracle oracleImpl = new Oracle();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(oracleImpl), abi.encodeWithSignature("initialize()"));

        oracle = Oracle(address(proxy));

        vm.deal(address(oracle), 5e18);
        vm.deal(address(owner), 100e18);
        vm.deal(address(alice), 100e18);
        vm.deal(address(bob), 100e18);
        vm.deal(address(provider1), 100e18);
        vm.deal(address(provider2), 100e18);
        vm.deal(address(provider3), 100e18);
        vm.stopPrank();
    }

    function createPrice(
        uint signer,
        address signerAddress,
        uint128 price
    )
        internal
        returns (OraclePrice memory op)
    {
        uint256 ts = block.timestamp;
        bytes memory data =
            abi.encodePacked(address(signerAddress), uint(ts), uint(price), uint(block.chainid));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, keccak256(data).toEthSignedMessageHash());
        op.timestamp = uint128(ts);
        op.sharePrice = uint128(price);
        op.contractAddress = address(owner);
        op.signature = abi.encodePacked(r, s, v); // bytes32 -> bytes conversion
    }

    function baseSetup() internal {
        vm.startPrank(owner);
        oracle.updateRewardPerSecond(12);
        oracle.updateStakeLimits(1e18, 20e18, 86400);
        oracle.updateFraudSlot(address(token), false, 100);
        vm.stopPrank();
    }

    function test_OracleRedeem() public {
        baseSetup();
        vm.deal(address(oracle), 5e18);

        vm.startPrank(bob);

        token.approve(address(oracle), 30e18);

        assertEq(token.balanceOf(bob), 2000e18);
        assertEq(alice.balance, 100e18);

        oracle.redeemCollateral(payable(alice), 1e18);
        assertEq(token.balanceOf(bob), 1999e18);
        assertEq(alice.balance, 101e18);

        oracle.redeemCollateral(payable(alice), 1e18);

        assertEq(token.balanceOf(bob), 1998e18);
        assertEq(alice.balance, 1019999999e11);

        vm.stopPrank();
    }

    function test_OracleUnstake() public {
        baseSetup();
        vm.warp(100000);

        vm.startPrank(bob);

        token.approve(address(oracle), 30e18);

        oracle.stake(provider1, 10e18, bob);
        oracle.stake(provider2, 10e18, alice);

        vm.stopPrank();

        vm.startPrank(alice);

        // cannot unstake
        vm.expectRevert();
        oracle.unstake(provider1, 1, 10e18, bob);

        assertEq(token.balanceOf(bob), 1980e18);

        // can unstake
        oracle.unstake(provider2, 1, 5e18, bob);

        assertEq(token.balanceOf(bob), 1980e18);

        uint ts = vm.getBlockTimestamp();

        vm.warp(ts + 86400);

        // cannot claim withdraw to bob
        vm.expectRevert();
        oracle.withdraw(provider1, 1, bob);

        // can claim with same nonce
        oracle.unstake(provider2, 1, 5e18, alice);

        vm.stopPrank();

        vm.warp(ts - 86400);

        vm.startPrank(bob);

        // not yet
        vm.expectRevert();
        oracle.withdraw(provider2, 1, bob);

        vm.warp(ts + 86400);

        oracle.withdraw(provider2, 1, bob);

        assertEq(token.balanceOf(bob), 1985e18);
        vm.stopPrank();
    }

    function test_OracleHappyPath() public {
        baseSetup();
        vm.deal(address(oracle), 5e18);

        vm.startPrank(bob);

        // no approve
        vm.expectRevert();
        oracle.stake(provider1, 10e18, bob);

        token.approve(address(oracle), 10e18);
        oracle.stake(provider1, 10e18, bob);

        oracle.unstake(provider1, 1, 10e18, bob);

        // WithdrawalDelayed
        vm.expectRevert();
        oracle.withdraw(provider1, 1, bob);

        uint ts = vm.getBlockTimestamp();

        vm.warp(ts + 86401);
        oracle.withdraw(provider1, 1, bob);

        vm.stopPrank();

        OraclePrice memory op;

        vm.startPrank(alice);

        token.approve(address(oracle), 50e18);
        oracle.stake(provider1, 10e18, alice);

        vm.stopPrank();

        vm.prank(owner);
        oracle.toggleOracle(provider1);

        vm.expectRevert();
        vm.prank(alice);
        oracle.startPanic("Fraud situation");

        vm.prank(provider2);
        vm.expectRevert();
        oracle.startPanic("Fraud situation");

        vm.prank(provider1);
        oracle.startPanic("Fraud situation");

        // we are in panic
        vm.prank(alice);
        vm.expectRevert();
        oracle.stake(provider2, 20e18, alice);

        vm.prank(owner);
        oracle.updateFraudSlot(address(token), false, 100);

        vm.prank(alice);
        oracle.stake(provider2, 20e18, alice);

        vm.prank(owner);
        oracle.toggleOracle(provider2);

        // stake is too big
        vm.prank(alice);
        vm.expectRevert();
        oracle.stake(provider3, 30e18, alice);

        vm.prank(alice);
        oracle.stake(provider3, 20e18, alice);

        vm.prank(owner);
        oracle.toggleOracle(provider3);

        op = createPrice(ownerPk, owner, 49432770753888933655371916);

        // owner cannot provide signed price
        vm.expectRevert();
        vm.prank(alice);
        oracle.commitPrice(op);

        op = createPrice(provider1Pk, provider1, 49432770753888933655371916);

        vm.prank(provider1);
        oracle.commitPrice(op);
    }

    function test_PriceCommiting() public {
        baseSetup();
        vm.startPrank(bob);

        token.approve(address(oracle), 20e18);
        oracle.stake(provider1, 10e18, bob);
        vm.stopPrank();

        OraclePrice memory op;

        op = createPrice(provider1Pk, provider1, 49432770753888933655371916);

        // price provider is not toggled
        vm.expectRevert();
        vm.prank(provider1);
        oracle.commitPrice{value: 1e16}(op);

        vm.prank(owner);
        oracle.toggleOracle(provider1);

        // only the provider commits price
        vm.expectRevert();
        vm.prank(bob);
        oracle.commitPrice{value: 1e16}(op);

        vm.prank(provider1);
        oracle.commitPrice(op);

        OracleData memory odNew = oracle.getOracle(provider1);

        assertEq(odNew.stake, 10000000000000000000);

        vm.warp(block.timestamp + 1000);
        op = createPrice(provider1Pk, provider1, 49432770753888933655371916);

        // with increasing stake
        vm.prank(provider1);
        oracle.commitPrice{value: 1e17}(op);

        odNew = oracle.getOracle(provider1);

        assertEq(odNew.stake, 10000001201200000000);

        vm.warp(block.timestamp + 1000);

        // price expired
        vm.expectRevert();
        vm.prank(provider1);
        oracle.commitPrice{value: 1e16}(op);
    }

    function test_Panic() public {
        baseSetup();

        vm.startPrank(bob);

        token.approve(address(oracle), 20e18);
        oracle.stake(provider1, 10e18, bob);
        oracle.unstake(provider1, 1, 5e18, bob);
        vm.stopPrank();

        vm.prank(owner);
        oracle.toggleOracle(provider1);

        vm.prank(provider1);
        oracle.startPanic("Some reason");

        vm.startPrank(bob);

        vm.expectRevert();
        oracle.stake(provider1, 10e18, bob);

        vm.expectRevert();
        oracle.unstake(provider1, 2, 5e18, bob);

        uint ts = block.timestamp;
        vm.warp(ts + 86400);

        vm.expectRevert();
        oracle.withdraw(provider1, 1, bob);

        vm.stopPrank();

        OraclePrice memory op;

        op = createPrice(provider1Pk, provider1, 49432770753888933655371916);

        vm.expectRevert();
        vm.prank(provider1);
        oracle.commitPrice(op);

        vm.prank(owner);
        oracle.updateFraudSlot(address(token), false, 100);

        vm.startPrank(bob);
        oracle.stake(provider1, 10e18, bob);
        oracle.unstake(provider1, 2, 5e18, bob);
        oracle.withdraw(provider1, 1, bob);
        vm.stopPrank();

        vm.prank(provider1);
        oracle.commitPrice(op);
    }

    function test_Access() public {
        vm.prank(bob);
        vm.expectRevert();
        oracle.updateRewardPerSecond(12);

        vm.prank(owner);
        oracle.updateRewardPerSecond(12);
        assertEq(oracle.rewardPerSecond(), uint256(12));

        vm.prank(bob);
        vm.expectRevert();
        oracle.updateStakeLimits(10, 500, 1400);

        vm.prank(owner);
        oracle.updateStakeLimits(10, 500, 1400);
        assertEq(oracle.minStake(), uint256(10));
        assertEq(oracle.maxStake(), uint256(500));
        assertEq(oracle.withdrawalDuration(), uint256(1400));

        vm.prank(bob);
        vm.expectRevert();
        oracle.updateFraudSlot(address(1), false, 100);

        vm.prank(owner);
        oracle.updateFraudSlot(address(1), true, 100);
        FraudSlot memory slot = oracle.getFraudSlot();
        assertEq(slot.lastClaimedTimestamp, 0);
        assertEq(slot.sharePriceValidityDuration, 100);
        assertEq(slot.tokenAddress, address(1));
        assertEq(slot.weArePanicking, true);

        vm.prank(bob);
        vm.expectRevert();
        oracle.toggleOracle(bob);

        vm.prank(owner);
        oracle.toggleOracle(bob);
    }

    function test_OracleStake() public {
        baseSetup();

        // must have some token on balance
        vm.deal(address(oracle), 5e18);

        vm.prank(owner);
        oracle.updateRewardPerSecond(1e8);

        vm.startPrank(bob);

        token.approve(address(oracle), 30e18);

        // stake is too small
        vm.expectRevert();
        oracle.stake(provider1, 1e17, bob);

        oracle.stake(provider1, 10e18, bob);
        oracle.stake(provider2, 10e18, alice);

        // stake is too big
        vm.expectRevert();
        oracle.stake(provider2, 10e18 + 1, alice);

        vm.stopPrank();

        OracleData memory od;
        od = oracle.getOracle(provider1);

        assertEq(od.stake, 10000000000000000000);
        assertEq(od.totalShares, 10000000000000000000);
        // oracles should be approved by owner multisig
        assertEq(od.enabled, false);

        vm.prank(owner);
        oracle.toggleOracle(provider1);

        vm.prank(owner);
        oracle.toggleOracle(provider2);

        vm.startPrank(alice);

        token.approve(address(oracle), 20e18);
        oracle.stake(provider1, 5e18, alice);
        oracle.stake(provider2, 1e18, alice);

        vm.stopPrank();

        od = oracle.getOracle(provider1);
        assertEq(od.stake, 15000000000000000000);
        assertEq(od.totalShares, 15000000000000000000);
        // oracles should be approved by owner multisig
        assertEq(od.enabled, true);

        od = oracle.getOracle(provider2);
        assertEq(od.stake, 11000000000000000000);
        assertEq(od.totalShares, 11000000000000000000);
        // oracles should be approved by owner multisig
        assertEq(od.enabled, true);

        OraclePrice memory op;
        op = createPrice(provider1Pk, provider1, 49432170733128933655371916);

        vm.prank(provider1);
        oracle.commitPrice(op);

        vm.warp(block.timestamp + 10000);
        // 10000 secs * 1e8 of reward per token = 1e12 + 1e8 of createPrice call

        op = createPrice(provider1Pk, provider1, 49432170733128933655371916);

        vm.prank(provider1);
        oracle.commitPrice{value: 1e16}(op);

        od = oracle.getOracle(provider1);

        assertEq(od.stake, 115010000000000000000);
        // share do not change on buy
        assertEq(od.totalShares, 15000000000000000000);

        // crazy mode
        vm.prank(owner);
        // u32 max - 4294967295 * 1e8 precision = 429496729500000000 - 14e17
        oracle.updateRewardPerSecond(type(uint32).max);

        // u128 max - 340282366920938463463374607431768211455 - 34e37
        vm.prank(owner);
        oracle.updateStakeLimits(1e18, type(uint112).max, 86400);

        token.mint(bob, type(uint112).max);

        vm.prank(bob);
        token.approve(address(oracle), type(uint112).max);

        // stake - 5192296858534827628530496329220095 - 5e33
        vm.prank(bob);
        oracle.stake(provider3, type(uint112).max - 1, bob);

        vm.prank(owner);
        oracle.toggleOracle(provider3);

        vm.warp(block.timestamp + 10000000);
        // 10000000 * 429496729500000000 = 4294967295000000000000000 (~4,000,000e18)
        // 2777 hours ~ 115 days

        op = createPrice(provider3Pk, provider3, 49432170733128933655371916);

        vm.prank(provider3);
        oracle.commitPrice{value: 10e18}(op);

        od = oracle.getOracle(provider3);
        // 5e33
        assertEq(od.stake, 5192296862829794923530496329220094);
        assertEq(od.totalShares, 5192296858534827628530496329220094);

        vm.warp(block.timestamp + 100000000000);
        // 100000000000 * 429496729500000000 = 42949672950000000000000000000 (~4e28)
        // 3168 years

        op = createPrice(provider3Pk, provider3, 49432170733128933655371916);
        vm.prank(provider3);
        oracle.commitPrice{value: 50e18}(op);

        od = oracle.getOracle(provider3);

        assertEq(od.stake, 5192296896140920839586459020759068);
        assertEq(od.totalShares, 5192296858534827628530496329220094);

        vm.warp(block.timestamp + 100000000000);
        op = createPrice(provider3Pk, provider3, 49432170733128933655371916);

        vm.prank(provider3);
        oracle.commitPrice(op);
        // we do not buy anything
        od = oracle.getOracle(provider3);
        assertEq(od.stake, 5192296896140920839586459020759068);

        // basic overflow is impossible
        // available 128 size of stake + 112 max stake restriction
    }
}
