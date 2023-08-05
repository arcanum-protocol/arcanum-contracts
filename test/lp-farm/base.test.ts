import * as Parallel from 'async-parallel';
import { expect } from 'chai';
import { assert } from 'console';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { deployEtf } from '../fixtures/etf';
import { mine } from "@nomicfoundation/hardhat-network-helpers";

import { toDecimal } from '../utils/numbers';
import { Pool, deployUniswapV2Pool } from "../fixtures/UniV2";
import { MockERC20 } from '../../typechain-types/contracts/mocks/erc20.sol';
import { LpFarm } from "../../typechain-types/contracts/farm/Farm.sol/LpFarm";

describe("Farm", function() {
    let alice: any;
    let bob: any;
    let carol: any;
    let owner: any;
    let FARM: any;
    let ERC20: any;
    let rewardToken: MockERC20;
    let farm: LpFarm;
    let pool: Pool;
    let assets: any[] = [];

    async function batchGetBalance(address: string): Promise<BigNumber[]> {
        const balances = await Parallel.map(assets, async asset => {
            return asset.balanceOf(address);
        });

        return balances;
    }

    before(async () => {
        [owner, alice, bob, carol] = await ethers.getSigners();
        ERC20 = await ethers.getContractFactory("MockERC20");
        FARM = await ethers.getContractFactory("LpFarm");
    });

    beforeEach(async function() {
        rewardToken = await ERC20.deploy("reward", "RWD", toDecimal(100000000000));
        pool = await deployUniswapV2Pool(toDecimal(10000000), toDecimal(10000), alice.address);
        farm = await FARM.deploy(rewardToken.address);
    });

    it("Happy path", async function() {
        await farm.connect(owner).add(pool.pool.address);
        await rewardToken.approve(farm.address, toDecimal(10000));
        // 1 token per block
        await farm.connect(owner).setDistribution(0, toDecimal(10000), 10000);

        // deposited balance doesn't matter for one user, because the user will earn all awailable rewards
        const poolBalance = await pool.pool.balanceOf(alice.address);
        await pool.pool.connect(alice).approve(farm.address, poolBalance);
        await farm.connect(alice).deposit(0, poolBalance);

        expect(await pool.pool.balanceOf(alice.address)).to.be.eq(0);
        expect(await rewardToken.balanceOf(alice.address)).to.be.eq(0);
        expect(await farm.pendingRewards(0, alice.address)).to.be.eq(0);

        await mine(100);
        // available totalDistribution / distributionBlocks * blockDelta = 1000
        const rewards = await farm.pendingRewards(0, alice.address);
        expect(rewards).to.be.closeTo(toDecimal(100), toDecimal(1, 17));
        await farm.connect(alice).withdraw(0, poolBalance);

        expect(await pool.pool.balanceOf(alice.address)).to.be.eq(poolBalance);
        expect(await farm.pendingRewards(0, alice.address)).to.be.eq(0);
        // 101 block
        expect(await rewardToken.balanceOf(alice.address)).to.be.closeTo(toDecimal(101), toDecimal(1, 17));
    });

    it("Other users affect outcoming earn", async function() {
        await farm.connect(owner).add(pool.pool.address);
        await rewardToken.approve(farm.address, toDecimal(10000));
        // 1 token per block
        await farm.connect(owner).setDistribution(0, toDecimal(10000), 10000);

        // deposited balance doesn't matter for one user, because the user will earn all awailable rewards
        const totalBalance = await pool.pool.balanceOf(alice.address);
        // alice has 2/3 of total
        const aliceBalance = totalBalance.div(3).mul(2);
        // bob has 1/3 of total balance
        const bobBalance = totalBalance.div(3);
        await pool.pool.connect(alice).transfer(bob.address, bobBalance);

        await pool.pool.connect(alice).approve(farm.address, aliceBalance);
        await farm.connect(alice).deposit(0, aliceBalance);

        await pool.pool.connect(bob).approve(farm.address, bobBalance);
        await farm.connect(bob).deposit(0, bobBalance);

        // alice has +1 block difference
        expect(await farm.pendingRewards(0, alice.address)).to.be.closeTo(toDecimal(2), toDecimal(1, 16));
        expect(await farm.pendingRewards(0, bob.address)).to.be.eq(0);

        expect(await pool.pool.balanceOf(alice.address)).to.be.eq(0);
        expect(await rewardToken.balanceOf(alice.address)).to.be.eq(0);

        expect(await pool.pool.balanceOf(bob.address)).to.be.eq(0);
        expect(await rewardToken.balanceOf(bob.address)).to.be.eq(0);

        await mine(100);

        // ~66.66
        expect(await farm.pendingRewards(0, alice.address)).to.be.closeTo(toDecimal(687, 17), toDecimal(1, 17));
        expect(await farm.pendingRewards(0, bob.address)).to.be.closeTo(toDecimal(333, 17), toDecimal(1, 17));

        await farm.connect(alice).withdraw(0, aliceBalance);
        await farm.connect(bob).withdraw(0, bobBalance);

        expect(await pool.pool.balanceOf(alice.address)).to.be.eq(aliceBalance);
        expect(await farm.pendingRewards(0, alice.address)).to.be.eq(0);
        expect(await rewardToken.balanceOf(alice.address)).to.be.closeTo(toDecimal(693, 17), toDecimal(1, 17));

        expect(await pool.pool.balanceOf(bob.address)).to.be.eq(bobBalance);
        expect(await farm.pendingRewards(0, bob.address)).to.be.eq(0);
        expect(await rewardToken.balanceOf(bob.address)).to.be.closeTo(toDecimal(347, 17), toDecimal(1, 17));
    });

    it("Cannot earn without initialized distribution", async function() {
        await farm.connect(owner).add(pool.pool.address);

        const poolBalance = await pool.pool.balanceOf(alice.address);
        await pool.pool.connect(alice).approve(farm.address, poolBalance);
        await farm.connect(alice).deposit(0, poolBalance);

        expect(await farm.pendingRewards(0, alice.address)).to.be.eq(0);

        await mine(100);

        expect(await farm.pendingRewards(0, alice.address)).to.be.eq(0);
    });

    it("Change distribution whilst farming", async function() {
        await farm.connect(owner).add(pool.pool.address);
        await rewardToken.approve(farm.address, toDecimal(10000));
        // 2 token per block
        await farm.connect(owner).setDistribution(0, toDecimal(10000), 5000);

        // deposited balance doesn't matter for one user, because the user will earn all awailable rewards
        const poolBalance = await pool.pool.balanceOf(alice.address);
        await pool.pool.connect(alice).approve(farm.address, poolBalance);
        await farm.connect(alice).deposit(0, poolBalance);

        expect(await pool.pool.balanceOf(alice.address)).to.be.eq(0);
        expect(await rewardToken.balanceOf(alice.address)).to.be.eq(0);
        expect(await farm.pendingRewards(0, alice.address)).to.be.eq(0);

        await mine(100);
        // available totalDistribution / distributionBlocks * blockDelta = 1000
        const rewards = await farm.pendingRewards(0, alice.address);
        expect(rewards).to.be.closeTo(toDecimal(2001, 17), toDecimal(1, 17));

        await rewardToken.approve(farm.address, toDecimal(5000));
        // 0.5 token per block
        await farm.connect(owner).setDistribution(0, toDecimal(5000), 10000);

        await mine(100);

        const newRewards = await farm.pendingRewards(0, alice.address);
        expect(newRewards).to.be.closeTo(toDecimal(3048, 17), toDecimal(1, 17));

    });

    it("Check private methods", async function() {
        await expect(farm.connect(alice).add(pool.pool.address)).to.be.revertedWith("Ownable: caller is not the owner")
        // 0 id
        await farm.connect(owner).add(pool.pool.address)
        await rewardToken.connect(alice).approve(farm.address, toDecimal(10));
        await rewardToken.connect(owner).approve(farm.address, toDecimal(10));
        await expect(farm.connect(alice).setDistribution(0, toDecimal(10), 15)).to.be.revertedWith("Ownable: caller is not the owner");
        await farm.connect(owner).setDistribution(0, toDecimal(10), 15);
    });

})
