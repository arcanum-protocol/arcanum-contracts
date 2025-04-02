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
import {Slot, OracleData, StakeOptions} from "../../src/types/Oracle.sol";
import {MultipoolUtils, toX96, toX32, vec, updatePrice, SigUtils} from "../MultipoolUtils.t.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract OracleTests is Test {
    using ECDSA for bytes32;

    receive() external payable {}

    Oracle oracle;

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

    Oracle oracleImpl;
    SigUtils internal sigUtils;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("Owner");
        (alice,) = makeAddrAndKey("Alice");
        (bob,) = makeAddrAndKey("Bob");
        (provider1, provider1Pk) = makeAddrAndKey("PriceProvider1");
        (provider2, provider2Pk) = makeAddrAndKey("PriceProvider2");
        (provider3, provider3Pk) = makeAddrAndKey("PriceProvider3");

        vm.startPrank(owner);

        oracleImpl = new Oracle();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(oracleImpl), abi.encodeWithSignature("initialize()"));

        oracle = Oracle(payable(address(proxy)));

        sigUtils = new SigUtils(oracle.DOMAIN_SEPARATOR());

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
        oracle.updateFraudData(false, 100);
        vm.stopPrank();
    }

    function test_OracleTokenOps() public {
        Oracle newOracleImpl = new Oracle{salt: keccak256(abi.encode("NewOracle"))}();

        vm.prank(owner);
        oracle.upgradeTo(address(newOracleImpl));

        assertEq(oracle.name(), "Arcanum Revenue Token");
        assertEq(oracle.symbol(), "AREV");
        assertEq(oracle.decimals(), 18);
        assertEq(oracle.decimals(), 18);
        assertEq(oracle.totalSupply(), 10000000e18);
        assertEq(oracle.nonces(bob), 0);
        assertEq(
            oracle.DOMAIN_SEPARATOR(),
            0x56f5319c05977890bdb387360d6f285e08dbd9cf2b2d9a5ad71377e5946f722d
        );

        vm.prank(owner);
        vm.expectRevert();
        oracle.transfer(address(0), 1e18);

        vm.prank(address(0));
        vm.expectRevert();
        oracle.transfer(owner, 1e18);

        vm.prank(owner);
        vm.expectRevert();
        oracle.approve(address(0), 1e18);

        vm.prank(address(0));
        vm.expectRevert();
        oracle.approve(owner, 1e18);

        vm.prank(owner);
        oracle.approve(bob, 1e18);

        vm.prank(address(0));
        vm.expectRevert();
        oracle.increaseAllowance(owner, 1e18);

        vm.prank(owner);
        oracle.increaseAllowance(bob, 1e18);

        vm.prank(bob);
        vm.expectRevert();
        oracle.decreaseAllowance(owner, 1e18);

        vm.prank(owner);
        oracle.decreaseAllowance(bob, 1e18);

        uint allowance = oracle.allowance(owner, bob);

        assertEq(allowance, 1e18);

        vm.prank(bob);
        oracle.transferFrom(owner, bob, 5e17);

        vm.prank(bob);
        vm.expectRevert();
        oracle.transferFrom(owner, bob, 1e18);

        ERC1967Proxy newProxy = new ERC1967Proxy(address(oracleImpl), "");
        Oracle newOracle = Oracle(payable(address(newProxy)));

        vm.prank(address(0));
        // mint zero
        vm.expectRevert();
        newOracle.initialize();

        // burn zero
        vm.prank(address(0));
        vm.expectRevert();
        oracle.burn(payable(address(0)), 1e18);

        // insufficient
        vm.prank(alice);
        vm.expectRevert();
        oracle.burn(payable(address(0)), 1e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: bob,
            value: 1e18,
            nonce: oracle.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);
        uint ts = block.timestamp;

        vm.warp(ts + 10000000);

        vm.expectRevert();
        oracle.permit(owner, bob, 1e18, 1 days, v, r, s);

        vm.warp(ts);

        // invalid signature
        vm.expectRevert();
        oracle.permit(alice, bob, 1e18, 1 days, v, r, s);

        oracle.permit(owner, bob, 1e18, 1 days, v, r, s);
    }

    function test_OracleRedeem() public {
        baseSetup();
        vm.deal(address(oracle), 5e18);

        vm.prank(owner);
        oracle.transfer(bob, 30e18);

        vm.startPrank(bob);

        assertEq(oracle.balanceOf(bob), 30e18);
        assertEq(alice.balance, 100e18);

        oracle.burn(payable(alice), 1e18);
        assertEq(oracle.balanceOf(bob), 29e18);
        assertEq(alice.balance, 100000000500000000000);

        oracle.burn(payable(alice), 1e18);

        assertEq(oracle.balanceOf(bob), 28e18);
        assertEq(alice.balance, 100000001000000000000);

        vm.stopPrank();
    }

    function test_OracleUnstake() public {
        baseSetup();
        vm.warp(100000);

        vm.prank(owner);
        oracle.transfer(bob, 30e18);

        vm.startPrank(bob);

        oracle.stake(provider1, 10e18, bob);
        oracle.stake(provider2, 10e18, alice);

        vm.stopPrank();

        vm.startPrank(alice);

        // cannot unstake
        vm.expectRevert();
        oracle.unstake(provider1, 1, 10e18, bob);

        assertEq(oracle.balanceOf(bob), 10e18);

        // can unstake
        oracle.unstake(provider2, 1, 5e18, bob);

        // withdrawal is not empty
        vm.expectRevert();
        oracle.unstake(provider2, 1, 5e18, bob);

        assertEq(oracle.balanceOf(bob), 10e18);

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

        assertEq(oracle.balanceOf(bob), 15e18);
        vm.stopPrank();
    }

    function test_OracleHappyPath() public {
        baseSetup();
        vm.deal(address(oracle), 5e18);

        // no balance
        vm.expectRevert();
        vm.prank(bob);
        oracle.stake(provider1, 10e18, bob);

        vm.prank(owner);
        oracle.transfer(bob, 10e18);

        vm.startPrank(bob);

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

        vm.prank(owner);
        oracle.transfer(alice, 50e18);

        vm.startPrank(alice);

        oracle.stake(provider1, 10e18, alice);

        vm.stopPrank();

        vm.prank(owner);
        oracle.toggleOracle(provider1);
        vm.prank(owner);
        oracle.togglePanicAuthority(provider1);

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
        oracle.updateFraudData(false, 100);

        vm.prank(alice);
        oracle.stake(provider2, 20e18, alice);

        vm.prank(owner);
        oracle.toggleOracle(provider2);
        vm.prank(owner);
        oracle.togglePanicAuthority(provider2);

        // stake is too big
        vm.prank(alice);
        vm.expectRevert();
        oracle.stake(provider3, 30e18, alice);

        vm.prank(alice);
        oracle.stake(provider3, 20e18, alice);

        vm.prank(owner);
        oracle.toggleOracle(provider3);
        vm.prank(owner);
        oracle.togglePanicAuthority(provider3);

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

        vm.prank(owner);
        oracle.transfer(bob, 20e18);

        vm.startPrank(bob);

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
        vm.prank(owner);
        oracle.togglePanicAuthority(provider1);

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

        vm.prank(owner);
        oracle.transfer(bob, 20e18);

        vm.startPrank(bob);

        oracle.stake(provider1, 10e18, bob);
        oracle.unstake(provider1, 1, 5e18, bob);
        vm.stopPrank();

        vm.prank(owner);
        oracle.toggleOracle(provider1);
        vm.prank(owner);
        oracle.togglePanicAuthority(provider1);

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
        oracle.updateFraudData(false, 100);

        vm.startPrank(bob);
        oracle.stake(provider1, 10e18, bob);
        oracle.unstake(provider1, 2, 5e18, bob);
        oracle.withdraw(provider1, 1, bob);
        vm.stopPrank();

        vm.prank(provider1);
        oracle.commitPrice(op);
    }

    function test_OracleAccess() public {
        vm.prank(bob);
        vm.expectRevert();
        oracle.updateRewardPerSecond(12);

        vm.prank(owner);
        oracle.updateRewardPerSecond(12);

        Slot memory slot = oracle.getSlot();
        assertEq(slot.rewardPerSecond, uint256(12));

        vm.prank(bob);
        vm.expectRevert();
        oracle.updateStakeLimits(10, 500, 1400);

        vm.prank(owner);
        oracle.updateStakeLimits(10, 500, 1400);
        StakeOptions memory so = oracle.getStakeOptions();
        slot = oracle.getSlot();

        assertEq(so.minStake, uint256(10));
        assertEq(so.maxStake, uint256(500));
        assertEq(slot.withdrawalDuration, uint256(1400));

        vm.prank(bob);
        vm.expectRevert();
        oracle.updateFraudData(false, 100);

        vm.prank(owner);
        oracle.updateFraudData(true, 100);
        slot = oracle.getSlot();
        assertEq(slot.lastClaimedTimestamp, 0);
        assertEq(slot.sharePriceValidityDuration, 100);
        assertEq(slot.weArePanicking, true);

        vm.prank(bob);
        vm.expectRevert();
        oracle.toggleOracle(bob);

        vm.prank(owner);
        oracle.toggleOracle(bob);

        vm.prank(bob);
        vm.expectRevert();
        oracle.togglePanicAuthority(bob);

        vm.prank(owner);
        oracle.togglePanicAuthority(bob);

        vm.prank(bob);
        vm.expectRevert();
        oracle.updateStake(bob, 1e18);

        vm.prank(owner);
        oracle.updateFraudData(false, 100);

        vm.prank(owner);
        oracle.stake(bob, 499, owner);

        vm.prank(owner);
        oracle.updateStake(bob, 1e18);

        vm.prank(owner);
        oracle.updateStake(bob, -1e18);

        vm.prank(owner);
        oracle.transfer(address(oracle), 1e18);

        vm.prank(bob);
        vm.expectRevert();
        oracle.transferToGovernance(bob, 1e18);

        vm.prank(owner);
        oracle.transferToGovernance(bob, 1e18);
    }

    function test_OracleStake() public {
        baseSetup();

        // must have some token on balance
        vm.deal(address(oracle), 5e18);

        vm.prank(owner);
        oracle.updateRewardPerSecond(1e8);

        vm.prank(owner);
        oracle.transfer(bob, 30e18);

        vm.startPrank(bob);

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

        vm.prank(owner);
        oracle.transfer(alice, 20e18);

        vm.startPrank(alice);

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

        uint88 balance = uint88(oracle.balanceOf(owner));

        vm.prank(owner);
        oracle.transfer(bob, balance);

        balance = uint88(oracle.balanceOf(bob));
        // stake - full token supply
        vm.prank(bob);
        oracle.stake(provider3, balance, bob);

        vm.prank(owner);
        oracle.toggleOracle(provider3);

        vm.warp(block.timestamp + 10000000);
        // 2777 hours ~ 115 days

        op = createPrice(provider3Pk, provider3, 49432170733128933655371916);

        vm.prank(provider3);
        oracle.commitPrice{value: 10e18}(op);

        od = oracle.getOracle(provider3);
        // 1e25
        assertEq(od.stake, 14294927295000000000000000);
        assertEq(od.totalShares, 9999960000000000000000000);

        vm.warp(block.timestamp + 100000000000);
        // 3168 years

        op = createPrice(provider3Pk, provider3, 49432170733128933655371916);
        vm.prank(provider3);
        oracle.commitPrice{value: 50e18}(op);

        od = oracle.getOracle(provider3);

        assertEq(od.stake, 47606053211055962691538974);
        assertEq(od.totalShares, 9999960000000000000000000);

        vm.warp(block.timestamp + 100000000000);
        op = createPrice(provider3Pk, provider3, 49432170733128933655371916);

        vm.prank(provider3);
        oracle.commitPrice(op);
        // we do not buy anything
        od = oracle.getOracle(provider3);
        assertEq(od.stake, 47606053211055962691538974);

        // basic overflow is impossible
        // available 128 size of stake + 112 max stake restriction
    }

    // pending withdraw slash
    // basic slash
    // add tests on updated pending stake
    // on allowedToValidate

    function test_OracleSlash() public {
        baseSetup();

        vm.prank(owner);
        oracle.updateStakeLimits(10e18, 100e18, 86400);

        // must have some token on balance
        vm.deal(address(oracle), 5e18);

        vm.prank(owner);
        oracle.updateRewardPerSecond(1e8);

        vm.prank(owner);
        oracle.transfer(bob, 30e18);

        vm.prank(owner);
        oracle.transfer(alice, 30e18);

        vm.startPrank(bob);

        oracle.stake(provider1, 10e18, bob);
        oracle.stake(provider2, 15e18, bob);

        vm.stopPrank();

        OracleData memory od;

        vm.prank(alice);
        oracle.stake(provider2, 15e18, alice);

        vm.prank(owner);
        oracle.toggleOracle(provider1);

        vm.prank(owner);
        oracle.togglePanicAuthority(provider1);

        od = oracle.getOracle(provider2);
        assertEq(od.totalShares, 30e18);
        assertEq(od.stake, 30e18);
        assertEq(od.allowedToValidate, true);

        vm.prank(owner);
        oracle.updateStake(provider2, -1e18);

        od = oracle.getOracle(provider2);
        assertEq(od.totalShares, 30e18);
        assertEq(od.stake, 29e18);
        assertEq(od.allowedToValidate, true);

        vm.prank(alice);
        oracle.unstake(provider2, 0, 10e18, alice);

        vm.warp(block.timestamp + 86400);

        od = oracle.getOracle(provider2);
        assertEq(od.totalShares, 30e18);
        assertEq(od.stake, 29e18);
        assertEq(od.allowedToValidate, true);

        vm.prank(owner);
        oracle.updateStake(provider2, -15e18);

        od = oracle.getOracle(provider2);
        assertEq(od.totalShares, 30e18);
        assertEq(od.stake, 14e18);
        assertEq(od.allowedToValidate, false);

        uint aliceBalance = oracle.balanceOf(alice);
        assertEq(aliceBalance, 15e18);

        vm.prank(alice);
        oracle.withdraw(provider2, 0, alice);
        aliceBalance = oracle.balanceOf(alice);
        // unstaked half of requested share
        assertEq(aliceBalance, 19666666666666666666);

        vm.prank(alice);
        oracle.unstake(provider2, 1, 5e18, alice);

        od = oracle.getOracle(provider2);
        assertEq(od.totalShares, 20e18);
        assertEq(od.stake, 14e18);
        // actual stake - (20 - 5) * 14 / 20 = 10.5
        assertEq(od.allowedToValidate, false);

        vm.prank(owner);
        oracle.updateStake(provider2, -1e18);

        od = oracle.getOracle(provider2);
        assertEq(od.totalShares, 20e18);
        assertEq(od.stake, 13e18);
        // actual stake - (20 - 5) * 13 / 20 = 9.75
        assertEq(od.allowedToValidate, false);
    }
}
