import * as Parallel from "async-parallel";
import { expect } from "chai";
import { ethers } from "hardhat";
import "@nomicfoundation/hardhat-chai-matchers";

import { toDecimal } from "../utils/numbers";

describe("Multipool base", function() {
    let alice: any;
    let bob: any;
    let carol: any;
    let owner: any;
    let ETF: any;
    let ERC20: any;
    // without fees and mutability
    let etf: any;
    // with 1% fees
    let assets: any[] = [];

    before(async () => {
        [owner, alice, bob, carol] = await ethers.getSigners();
        ETF = await ethers.getContractFactory("Multipool");
        ERC20 = await ethers.getContractFactory("MockERC20");
    });

    beforeEach(async function() {
        let tokenAddresses: string[] = [];

        assets = await Parallel.map([1, 2, 3, 4], async (i) => {
            const asset = await ERC20.deploy(
                "asset" + i,
                "a" + i,
                toDecimal(100000000000),
            );
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
        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).setBaseTradeFee(toDecimal(5, 13));
        await etf.connect(owner).setBaseBurnFee(toDecimal(1, 14));
        await etf.connect(owner).setBaseMintFee(toDecimal(1, 14));
    });

    it("ETF mint and swap should work", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));

        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(10),
            alice.address,
        );

        await assets[1].connect(alice).transfer(etf.address, toDecimal(1001, 15));

        await etf.connect(alice).mint(
            assets[1].address,
            toDecimal(1),
            alice.address,
        );

        await etf.connect(alice).transfer(etf.address, toDecimal(1));

        await etf.connect(alice).burn(
            assets[0].address,
            toDecimal(1),
            alice.address,
        );

        await assets[1].connect(alice).transfer(etf.address, toDecimal(1001, 15));

        const result = await etf.connect(alice).swap(
            assets[1].address,
            assets[0].address,
            toDecimal(10001, 14),
            alice.address,
        );

        await expect(result).to.changeTokenBalances(assets[0], [
            etf.address,
            alice.address,
        ], ["-1000049997500124993", "1000049997500124993"]);
    });

    it("Mint return unused transfer", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));

        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(10),
            alice.address,
        );
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(10));
        expect((await etf.assets(assets[0].address)).quantity).to.eq(toDecimal(10));
        expect(await assets[0].balanceOf(etf.address)).to.eq(toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(1000));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(10),
            alice.address,
        );
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(20));
        expect((await etf.assets(assets[0].address)).quantity).to.eq(toDecimal(20));
        // unused amount reterns to caller. Should be used withing router
        expect(await assets[0].balanceOf(etf.address)).to.eq(toDecimal(20001, 15));
    });

    it("Mint more than transfer", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));

        // initial mint
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(11),
            alice.address,
        );

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));
        await expect(
            etf.connect(alice).mint(assets[0].address, toDecimal(11), alice.address),
        ).to.be.revertedWith("MULTIPOOL: mint amount in exeeded");
    });

    it("Mint zero amount doesn't increase balance", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));

        // initial mint
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(11),
            alice.address,
        );

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));
        await expect(
            etf.connect(alice).mint(assets[0].address, toDecimal(11), alice.address),
        ).to.be.revertedWith("MULTIPOOL: mint amount in exeeded");
        const balanceBefore = await etf.balanceOf(alice.address);

        await etf.connect(alice).mint(assets[0].address, 0, alice.address);
        expect(await etf.balanceOf(alice.address)).to.eq(balanceBefore);
    });

    it("Burn return unused transfer", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(1000));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(1000),
            alice.address,
        );
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(1000));
        expect((await etf.assets(assets[0].address)).quantity).to.eq(
            toDecimal(1000),
        );
        expect(await assets[0].balanceOf(etf.address)).to.eq(toDecimal(1000));

        await etf.connect(alice).transfer(etf.address, toDecimal(1000));
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(0));
        await etf.connect(alice).burn(
            assets[0].address,
            toDecimal(10),
            alice.address,
        );
        expect((await etf.assets(assets[0].address)).quantity).to.eq(
            toDecimal(990),
        );
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(990));
    });

    it("Burn more than transfer", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));

        // initial mint
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(1000),
            alice.address,
        );

        await assets[0].connect(alice).transfer(etf.address, toDecimal(1000));

        await etf.connect(alice).transfer(etf.address, toDecimal(10));
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(990));
        await expect(
            etf.connect(alice).burn(assets[0].address, toDecimal(15), alice.address),
        ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });

    it("Burn zero amount doesn't affect balance", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(1000),
            alice.address,
        );

        await etf.connect(alice).transfer(etf.address, toDecimal(10));
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(990));
        await etf.connect(alice).burn(
            assets[0].address,
            toDecimal(0),
            alice.address,
        );
        // returned transfered tokens
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(1000));
    });

    it("Ops in curve applies cashback or fee", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        expect(await assets[0].balanceOf(alice.address)).to.eq(toDecimal(10000000));
        expect(await assets[1].balanceOf(alice.address)).to.eq(toDecimal(10000000));
        expect(await assets[0].balanceOf(bob.address)).to.eq(toDecimal(10000000));
        expect(await assets[1].balanceOf(bob.address)).to.eq(toDecimal(10000000));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(10),
            alice.address,
        );
        expect(await assets[0].balanceOf(alice.address)).to.eq(toDecimal(9999990));

        //mint with fee
        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(9),
            alice.address,
        );
        expect(await assets[0].balanceOf(alice.address)).to.eq(
            "9999980999100000000000000",
        );

        await assets[1].connect(bob).transfer(etf.address, toDecimal(25));
        await etf.connect(bob).mint(assets[1].address, toDecimal(24), bob.address);
        expect(await assets[1].balanceOf(bob.address)).to.eq(
            "9999975997600000000000000",
        );

        await etf.connect(bob).transfer(etf.address, toDecimal(4));
        await etf.connect(bob).burn(assets[1].address, toDecimal(4), bob.address);
        expect(await assets[1].balanceOf(bob.address)).to.eq(
            "9999979997200039996000399",
        );

        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(30),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(70),
        );

        await assets[1].connect(bob).transfer(etf.address, toDecimal(30005, 15));
        await etf.connect(bob).mint(assets[1].address, toDecimal(30), bob.address);
        expect(await assets[1].balanceOf(bob.address)).to.eq(
            "9999949994200039996000400",
        );
    });

    it("Swap can be performed without any part of etf", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(1000));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(1000),
            alice.address,
        );

        await assets[1].connect(bob).transfer(etf.address, toDecimal(1100));
        await etf.connect(bob).mint(
            assets[1].address,
            toDecimal(1000),
            bob.address,
        );

        const assetABefore = await assets[0].balanceOf(carol.address);
        const assetBBefore = await assets[1].balanceOf(carol.address);
        await assets[0].connect(carol).transfer(etf.address, toDecimal(1000));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(100));
        await etf.connect(carol).swap(
            assets[0].address,
            assets[1].address,
            toDecimal(5),
            carol.address,
        );
        // whole positive swap with cashback??
        expect(await assets[0].balanceOf(carol.address)).to.eq(
            assetABefore.add("94999560606060606061"),
        );
        expect(await assets[1].balanceOf(carol.address)).to.eq(
            assetBBefore.add("4999365465152499879"),
        );
    });

    it("Update price", async function() {
        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).setHalfDeviationFeeRatio(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(1000));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(1000),
            alice.address,
        );
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(15));
        const assetBefore = await assets[0].balanceOf(alice.address);

        await assets[0].connect(alice).transfer(etf.address, toDecimal(30));
        await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(29),
            alice.address,
        );
        // returned transfered tokens
        expect(await etf.balanceOf(alice.address)).to.eq(toDecimal(1029));
        // amount of refund
        expect(await assets[0].balanceOf(alice.address)).to.eq(
            assetBefore.sub(toDecimal(30)).add("997100000000000000"),
        );
    });

    // // TODO! unimplemented in contract
    // it("Fee transfers to the owner of contract in each tx", async function() {
    //     await etf.connect(owner).updateAssetPercents(assets[0].address, toDecimal(50));
    //     await etf.connect(owner).updateAssetPercents(assets[1].address, toDecimal(50));

    //     await etf.connect(owner).setCurveCoef(toDecimal(3, 14));
    //     await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

    //     await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
    //     await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

    //     const assetABefore = await assets[0].balanceOf(owner.address);
    //     const assetBBefore = await assets[1].balanceOf(owner.address);

    //     await assets[0].connect(alice).transfer(etf.address, toDecimal(1000));
    //     await etf.connect(alice).mint(assets[0].address, toDecimal(1000), alice.address);

    //     expect(await assets[0].balanceOf(owner.address))

    //     await assets[1].connect(bob).transfer(etf.address, toDecimal(1100));
    //     await etf.connect(bob).mint(assets[1].address, toDecimal(1000), bob.address);

    //     await assets[0].connect(alice).transfer(etf.address, toDecimal(100));
    //     await etf.connect(carol).swap(assets[0].address, assets[1].address, toDecimal(5), carol.address);
    // })
});
