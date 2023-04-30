import * as Parallel from 'async-parallel';
import { expect } from 'chai';
import { assert } from 'console';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';

import { toDecimal } from '../utils/numbers';

describe("Multipool", function() {
    let alice: any;
    let bob: any;
    let carol: any;
    let owner: any;
    let treasury: any;
    let ETF: any;
    let ERC20: any;
    // without fees and mutability
    let etf: any;
    // with 1% fees
    let assets: any[] = [];

    async function batchGetBalance(address: string): Promise<BigNumber[]> {
        const balances = await Parallel.map(assets, async asset => {
            return asset.balanceOf(address);
        });

        return balances;
    }

    async function batchCheckBalance(address: string, expected: BigNumber) {
        const balances = await batchGetBalance(address);

        await Parallel.map(balances, async (balance) => {
            expect(balance).to.be.equal(expected);
        });
    }

    before(async () => {
        [owner, alice, bob, carol, treasury] = await ethers.getSigners();
        ETF = await ethers.getContractFactory("Multipool");
        ERC20 = await ethers.getContractFactory("MockERC20");
    });

    beforeEach(async function() {
        let tokenAddresses: string[] = [];

        assets = await Parallel.map([1, 2, 3, 4], async (i) => {
            const asset = await ERC20.deploy("asset" + i, "a" + i, toDecimal(100000000000));
            await asset.transfer(alice.address, toDecimal(10000000));
            await asset.transfer(bob.address, toDecimal(10000000));
            await asset.transfer(carol.address, toDecimal(10000000));
            tokenAddresses.push(asset.address);

            return asset;
        });

        etf = await ETF.deploy(
            "ETF1",
            "ETF1",
        );
    });

    it("ETF mint should work", async function() {

        await etf.connect(owner).updateAssetPercents(assets[0].address, toDecimal(10));
        await etf.connect(owner).updateAssetPercents(assets[1].address, toDecimal(10));
        await etf.connect(owner).updateAssetPercents(assets[2].address, toDecimal(10));
        await etf.connect(owner).updateAssetPercents(assets[3].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10000));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));

        await etf.connect(alice).mint(assets[0].address, alice.address);

        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[1].connect(alice).transfer(etf.address, toDecimal(1));

        await etf.connect(alice).mint(assets[1].address, alice.address);

        await assets[1].connect(alice).transfer(etf.address, toDecimal(1));

        let balanceBef = await assets[0].balanceOf(alice.address);
        let returnVal = await etf.drySwap(toDecimal(1), assets[1].address, assets[0].address);
        await etf.connect(alice).swap(assets[1].address, assets[0].address, alice.address);
        let balanceAft = await assets[0].balanceOf(alice.address);
        assert(balanceAft.eq(returnVal.add(balanceBef)));

        //expect(await etf.balanceOf(alice.address)).to.equal(toDecimal(100));


        /// await Parallel.map(assets, async asset => {
        //   asset.connect(alice).transfer(etf.address, toDecimal(100));
        // });

        // await etf.connect(alice).mint(toDecimal(400), alice.address);

        // await batchCheckBalance(etf.address, toDecimal(100));
        // await batchCheckBalance(alice.address, toDecimal(0));

        // // check alice has minted share of etf
        // expect(await etf.balanceOf(alice.address)).to.equal(toDecimal(400));

        // // bob transfer 100 tokens to etf
        // await Parallel.map(assets, async asset => {
        //   asset.connect(bob).transfer(etf.address, toDecimal(100));
        // });

        // await etf.connect(bob).mint(toDecimal(40), bob.address);
        // await batchCheckBalance(etf.address, toDecimal(200));
        // await batchCheckBalance(bob.address, toDecimal(0));

        // expect(await etf.balanceOf(bob.address)).to.equal(toDecimal(40));

        // await batchCheckBalance(carol.address, toDecimal(100));
        // await etf.connect(carol).mint(toDecimal(200), carol.address);
        // await batchCheckBalance(etf.address, toDecimal(200));

        // expect(await etf.balanceOf(carol.address)).to.equal(toDecimal(200));

        // await etf.connect(carol).mint(toDecimal(160), carol.address);
        // await batchCheckBalance(etf.address, toDecimal(200));

        // expect(await etf.balanceOf(carol.address)).to.equal(toDecimal(360));
    });

    it("ETF mint should work #2", async function() {

        await etf.connect(owner).updateAssetPercents(assets[0].address, 18);
        await etf.connect(owner).updateAssetPercents(assets[1].address, 31);
        await etf.connect(owner).updateAssetPercents(assets[2].address, 14);
        await etf.connect(owner).updateAssetPercents(assets[3].address, 36);

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(1));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(1));
        await etf.connect(owner).updatePrice(assets[2].address, toDecimal(1));
        await etf.connect(owner).updatePrice(assets[3].address, toDecimal(1));

        await assets[0].connect(alice).transfer(etf.address, 123);
        await etf.connect(alice).mint(assets[0].address, alice.address);

        let val = await etf.connect(alice).burn(12, assets[0].address, alice.address);
        console.log(val);
        //expect().to.be.equal(22);
        expect(await etf.balanceOf(alice.address)).to.be.equal(111);

        await assets[1].connect(alice).transfer(etf.address, toDecimal(1));
        await etf.connect(alice).mint(assets[1].address, alice.address);


    });

    it.skip("ETF mint should be reverted due not enough balance", async function() {
        // mint for alice
        await Promise.all(
            assets.map(async (a) =>
                a.connect(alice).transfer(etf.address, toDecimal(100))
            )
        );

        await etf.connect(alice).mint(toDecimal(400), alice.getAddress());


        (await Promise.all(assets.map((a) => a.balanceOf(etf.address)))).map((b) =>
            expect(b).to.equal(toDecimal(100))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(alice.address)))).map(
            (b) => expect(b).to.equal(toDecimal(0))
        );


        // can't mint now
        await expect(
            etf.connect(carol).mint(toDecimal(40), carol.getAddress())
        ).to.be.revertedWith("ETF: not enough of token balance");
        await expect(
            etf.connect(alice).mint(toDecimal(40), alice.getAddress())
        ).to.be.revertedWith("ETF: not enough of token balance");
        await expect(
            etf.connect(bob).mint(toDecimal(40), bob.getAddress())
        ).to.be.revertedWith("ETF: not enough of token balance");
    });

    it.skip("ETF balance should be zero after all ETF tokens burned", async function() {
        // mint for alice
        await Promise.all(
            assets.map(async (a) =>
                a.connect(alice).transfer(etf.address, toDecimal(100))
            )
        );

        await etf.connect(alice).mint(toDecimal(400), alice.getAddress());

        (await Promise.all(assets.map((a) => a.balanceOf(etf.address)))).map((b) =>
            expect(b).to.equal(toDecimal(100))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(alice.address)))).map(
            (b) => expect(b).to.equal(toDecimal(0))
        );

        expect(await etf.balanceOf(alice.address)).to.equal(toDecimal(400));

        await etf.connect(alice).burn(toDecimal(400), alice.getAddress());

        expect(await etf.balanceOf(alice.address)).to.equal(toDecimal(0));

        (await Promise.all(assets.map((a) => a.balanceOf(alice.address)))).map(
            (b) => expect(b).to.equal(toDecimal(100))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(etf.address)))).map((b) =>
            expect(b).to.equal(toDecimal(0))
        );
    });

    it.skip("User should get tokens back after burn", async function() {
        // mint for alice
        await Promise.all(
            assets.map(async (a) =>
                a.connect(alice).transfer(etf.address, toDecimal(100))
            )
        );

        await etf.connect(alice).mint(toDecimal(400), alice.getAddress());

        (await Promise.all(assets.map((a) => a.balanceOf(etf.address)))).map((b) =>
            expect(b).to.equal(toDecimal(100))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(alice.address)))).map(
            (b) => expect(b).to.equal(toDecimal(0))
        );

        expect(await etf.balanceOf(alice.address)).to.equal(toDecimal(400));

        // burn tokens for alice
        await etf.connect(alice).burn(toDecimal(400), alice.getAddress());

        expect(await etf.balanceOf(alice.address)).to.equal(toDecimal(0));

        (await Promise.all(assets.map((a) => a.balanceOf(alice.address)))).map(
            (b) => expect(b).to.equal(toDecimal(100))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(etf.address)))).map((b) =>
            expect(b).to.equal(toDecimal(0))
        );

        // mint for bob
        await Promise.all(
            assets.map(async (a) =>
                a.connect(bob).transfer(etf.address, toDecimal(100))
            )
        );

        await etf.connect(bob).mint(toDecimal(400), bob.getAddress());
        (await Promise.all(assets.map((a) => a.balanceOf(etf.address)))).map((b) =>
            expect(b).to.equal(toDecimal(100))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(bob.address)))).map((b) =>
            expect(b).to.equal(toDecimal(0))
        );

        expect(await etf.balanceOf(bob.address)).to.equal(toDecimal(400));

        // burn tokens for bob to alice
        await etf.connect(bob).burn(toDecimal(400), alice.getAddress());

        expect(await etf.balanceOf(alice.address)).to.equal(toDecimal(0));

        (await Promise.all(assets.map((a) => a.balanceOf(bob.address)))).map((b) =>
            expect(b).to.equal(toDecimal(0))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(alice.address)))).map(
            (b) => expect(b).to.equal(toDecimal(200))
        );

        (await Promise.all(assets.map((a) => a.balanceOf(etf.address)))).map((b) =>
            expect(b).to.equal(toDecimal(0))
        );
    });
})
