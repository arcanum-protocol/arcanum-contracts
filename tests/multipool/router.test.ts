import * as Parallel from 'async-parallel';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import '@nomicfoundation/hardhat-chai-matchers';

import { toDecimal } from '../utils/numbers';

describe.only("MultipoolRouter", function() {
    let alice: any;
    let bob: any;
    let carol: any;
    let owner: any;
    let ETF: any;
    let ETFRouter: any;
    let ERC20: any;
    // without fees and mutability
    let etf: any;
    let etf1: any;
    let router: any;
    // with 1% fees
    let assets: any[] = [];
    let deadline: any;

    before(async () => {
        [owner, alice, bob, carol] = await ethers.getSigners();
        ETF = await ethers.getContractFactory("Multipool");
        ETFRouter = await ethers.getContractFactory("MultipoolRouter");
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
            "ETF",
            "ETF",
        );

        await etf.connect(owner).updateAssetPercents(assets[0].address, toDecimal(40));
        await etf.connect(owner).updateAssetPercents(assets[1].address, toDecimal(60));

        await etf.connect(owner).setCurveCoef(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(15));

        etf1 = await ETF.deploy(
            "ETF1",
            "ETF1",
        );

        await etf1.connect(owner).updateAssetPercents(assets[0].address, toDecimal(40));
        await etf1.connect(owner).updateAssetPercents(assets[1].address, toDecimal(60));

        await etf1.connect(owner).setCurveCoef(toDecimal(3, 14));
        await etf1.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf1.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf1.connect(owner).updatePrice(assets[1].address, toDecimal(15));

        router = await ETFRouter.deploy();
        deadline = (await ethers.provider.getBlock("latest")).timestamp + 70000;
    });

    it("ETF mint and swap should work", async function() {
        const amountIn = toDecimal(100);
        await assets[0].connect(alice).approve(router.address, amountIn);
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[0].address, 
            toDecimal(10), 
            amountIn, 
            alice.address,
            deadline
        );

        const secondAmountIn = amountIn.add(toDecimal(1, 17));
        await assets[1].connect(alice).approve(router.address, secondAmountIn);
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[1].address, 
            toDecimal(10), 
            secondAmountIn, 
            alice.address,
            deadline
        );

        await etf.connect(alice).approve(router.address, toDecimal(10));
        await router.connect(alice).burnWithSharesIn(
            etf.address,
            assets[0].address, 
            toDecimal(5), 
            toDecimal(5).sub(toDecimal(5,17)), 
            alice.address,
            deadline
        );

    });

    it("Ops return refund for not used amount to user", async function() {
        await assets[0].connect(alice).approve(router.address, toDecimal(100));
        // first mint will not refund
        // initializes pool with 1 share per 10 tokens
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[0].address, 
            toDecimal(10), 
            toDecimal(100), 
            alice.address,
            deadline
        );
        const balanceBefore = await assets[1].balanceOf(alice.address);
        // trying to send 5000
        await assets[1].connect(alice).approve(router.address, toDecimal(5000));
        // trying to mint 10 shares, approximately ...
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[1].address, 
            toDecimal(30), 
            toDecimal(5000), 
            alice.address,
            deadline
        );
        // potential spend is near 300, including fees
        expect(await assets[1].balanceOf(alice.address)).to.be.closeTo(balanceBefore, toDecimal(300));

        const balance = await etf.balanceOf(alice.address);
        expect(balance).to.eq(toDecimal(40));

        await etf.connect(alice).approve(router.address, balance);
        await router.connect(alice).burnWithSharesIn(
            etf.address,
            assets[1].address, 
            toDecimal(10), 
            balance, 
            alice.address,
            deadline
        );
       
        expect(await etf.balanceOf(alice.address)).to.be.eq(toDecimal(30));
    });

    it("Estimates works", async function() {
        const amountIn = toDecimal(100);
        await assets[0].connect(alice).approve(router.address, amountIn);
        // initial mint
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[0].address, 
            toDecimal(10), 
            amountIn, 
            alice.address,
            deadline
        );

        const estimatedSharesOut = await router.estimateMintSharesOut(
            etf.address,
            assets[0].address,
            amountIn,
        );
        const etfAliceBalance = toDecimal(10).add(estimatedSharesOut);

        await assets[0].connect(alice).approve(router.address, amountIn);
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[0].address, 
            estimatedSharesOut, 
            amountIn, 
            alice.address,
            deadline
        );

        // same amount, but less shares because of fees
        expect(estimatedSharesOut).to.be.lt(toDecimal(10))
        expect(await etf.balanceOf(alice.address)).to.be.closeTo(etfAliceBalance, 0);

        const sharesIn = toDecimal(30);
        const estimatedMintAmount = router.estimateMintAmountIn(
            etf.address,
            assets[1].address,
            sharesIn,
        );

        await assets[1].connect(alice).approve(router.address, estimatedMintAmount);
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[1].address, 
            sharesIn, 
            estimatedMintAmount, 
            alice.address,
            deadline
        );

        expect(await etf.balanceOf(alice.address)).to.eq(etfAliceBalance.add(sharesIn));
    })

    it("Reversed methods", async function() {
        const amountIn = toDecimal(100);
        await assets[0].connect(alice).approve(router.address, amountIn.mul(2));
        // initial mint
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[0].address, 
            toDecimal(10), 
            amountIn, 
            alice.address,
            deadline
        );
        await router.connect(alice).mintWithSharesOut(
            etf1.address,
            assets[0].address, 
            toDecimal(10), 
            amountIn, 
            alice.address,
            deadline
        );

        const shares = await router.estimateMintSharesOut(
            etf.address,
            assets[1].address,
            amountIn,
        )

        const estimatedAmountIn = await router.estimateMintAmountIn(
            etf.address,
            assets[1].address,
            shares,
        );

        await assets[1].connect(alice).approve(router.address, amountIn);
        await router.connect(alice).mintWithSharesOut(
            etf.address,
            assets[1].address, 
            shares, 
            amountIn, 
            alice.address,
            deadline
        );
        await assets[1].connect(alice).approve(router.address, estimatedAmountIn);
        await router.connect(alice).mintWithAmountIn(
            etf1.address,
            assets[1].address,
            estimatedAmountIn, 
            shares.sub(1),
            alice.address,
            deadline
        );


    })
})
