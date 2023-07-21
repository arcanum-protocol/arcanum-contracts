import * as Parallel from "async-parallel";
import { expect } from "chai";
import { ethers } from "hardhat";
import "@nomicfoundation/hardhat-chai-matchers";

import { toDecimal } from "../utils/numbers";
import { BigNumber } from "ethers";

interface MpAsset {
    quantity: string;
    price: string;
    collectedFees: string;
    collectedCashbacks: string;
    percent: string;
}

//struct MpContext {
//    uint totalCurrentUsdAmount;
//    uint totalAssetPercents;
//    uint halfDeviationFeeRatio;
//    uint deviationPercentLimit;
//    uint operationBaseFee;
//    uint userCashbackBalance;
//}

describe("Multipool contract maths", function() {
    let alice: any;
    let bob: any;
    let carol: any;
    let owner: any;
    let ETF: any;
    let ROUTER: any;
    let ERC20: any;
    // without fees and mutability
    let etf: any;
    let router: any;
    // with 1% fees
    let assets: any[] = [];

    before(async () => {
        [owner, alice, bob, carol] = await ethers.getSigners();
        ETF = await ethers.getContractFactory("Multipool");
        ROUTER = await ethers.getContractFactory("MultipoolRouter");
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

        router = await ROUTER.deploy();

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

    it("Mint and burn for full", async function() {
        let executionResult;
        let asset1: MpAsset;
        let asset2: MpAsset;

        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        //200.000 token 0 transfer for inital mint
        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));
        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));

        await expect(router.estimateMintSharesOut(
            etf.address,
            assets[0].address,
            toDecimal(200000),
        )).to.be.revertedWith("MULTIPOOL ROUTER: no shares");

        await expect(router.estimateMintAmountIn(
            etf.address,
            assets[0].address,
            toDecimal(100000),
        )).to.be.revertedWith("MULTIPOOL ROUTER: no shares");


        executionResult = await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(100000),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["0", toDecimal(100000)]);

        await etf.connect(alice).transfer(etf.address, toDecimal(100000));

        let result = await router.estimateBurnSharesIn(
            etf.address,
            assets[0].address,
            "199980001999800019998000",
        );

        expect(result.fee).to.be.equal(toDecimal(1, 14).sub(BigNumber.from("1")));
        expect(result.sharesIn).to.be.equal(toDecimal(100000).sub(BigNumber.from("1")));
        expect(result.cashbackOut).to.be.equal("0");

        result = await router.estimateBurnAmountOut(
            etf.address,
            assets[0].address,
            toDecimal(100000),
        );

        expect(result.fee).to.be.equal(toDecimal(1, 14));
        expect(result.amountOut).to.be.equal("199980001999800019998000");
        expect(result.cashbackOut).to.be.equal("0");


        executionResult = await etf.connect(alice).burn(
            assets[0].address,
            toDecimal(100000),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["-" + toDecimal(100000), "0"]);

        // base fee is charged while last burn, but no deviation fee
        await expect(executionResult).to.changeTokenBalances(assets[0], [
            etf.address,
            alice.address,
        ], ["-" + "199980001999800019998000", "199980001999800019998000"]);

        expect(await etf.totalSupply()).to.be.equal("0");
        expect(await etf.totalCurrentUsdAmount()).to.be.equal("0");
        let asset1Balance = await assets[0].balanceOf(etf.address);
        asset1 = await etf.assets(
            assets[0].address,
        );
        expect(asset1Balance.sub(asset1.collectedFees)).to.be.equal(
            "1",
        );

        //200.000 + 1 wei token 0 transfer for inital mint
        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));
        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));

        executionResult = await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(10),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["0", toDecimal(10)]);

        //2.000.000 token 1 transfer for mint
        await assets[1].connect(alice).transfer(etf.address, toDecimal(1000000));
        await assets[1].connect(alice).transfer(etf.address, toDecimal(1000000));

        result = await router.estimateMintSharesOut(
            etf.address,
            assets[1].address,
            "400040000000000000000002",
        );

        expect(result.fee).to.be.equal("100000000000000");
        expect(result.sharesOut).to.be.equal(toDecimal(20).sub(BigNumber.from("1")));
        expect(result.cashbackIn).to.be.equal("0");

        result = await router.estimateMintAmountIn(
            etf.address,
            assets[1].address,
            toDecimal(20),
        );

        expect(result.fee).to.be.equal(BigNumber.from("100000000000000").sub(BigNumber.from("1")));
        expect(result.amountIn).to.be.equal("400040000000000000000002");
        expect(result.cashbackIn).to.be.equal("0");

        executionResult = await etf.connect(alice).mint(
            assets[1].address,
            toDecimal(20),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["0", toDecimal(20)]);

        await expect(executionResult).to.changeTokenBalances(assets[1], [
            etf.address,
            alice.address,
        ], ["-1599959999999999999999998", "1599959999999999999999998"]);

        expect(await etf.totalSupply()).to.be.equal(toDecimal(30));
        // 6M
        expect(await etf.totalCurrentUsdAmount()).to.be.equal(
            "6000000000000000000000030",
        );
        asset1Balance = await assets[0].balanceOf(etf.address);
        asset1 = await etf.assets(
            assets[0].address,
        );
        expect(asset1.collectedFees).to.be.equal(
            "19998000199980001999",
        );
        expect(asset1.quantity).to.be.equal(
            "200000000000000000000001",
        );
        expect(asset1.collectedCashbacks).to.be.equal(
            "0",
        );

        expect(asset1Balance.sub(asset1.collectedFees).sub(asset1.quantity)).to.be
            .equal(
                "0",
            );

        asset2 = await etf.assets(
            assets[1].address,
        );
        expect(asset2.collectedFees).to.be.equal(
            "40000000000000000000",
        );
        expect(asset2.quantity).to.be.equal(
            "400000000000000000000002",
        );
        expect(asset2.collectedCashbacks).to.be.equal(
            "0",
        );

        await etf.connect(alice).transfer(etf.address, toDecimal(20));

        await expect(
            etf.connect(alice).burn(
                assets[1].address,
                toDecimal(20),
                alice.address,
            ),
        ).to.be.revertedWith("MULTIPOOL: deviation overflow");

        executionResult = await etf.connect(alice).burn(
            assets[1].address,
            toDecimal(10),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["-" + toDecimal(20), toDecimal(10)]);

        await expect(executionResult).to.changeTokenBalances(assets[1], [
            etf.address,
            alice.address,
        ], ["-199980001999800019998001", "199980001999800019998001"]);
    });

    it.only("Swapping", async function() {
        let executionResult;
        let asset1: MpAsset;
        let asset2: MpAsset;

        await etf.connect(owner).updateAssetPercents(
            assets[0].address,
            toDecimal(50),
        );
        await etf.connect(owner).updateAssetPercents(
            assets[1].address,
            toDecimal(50),
        );

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        //200.000 token 0 transfer for inital mint
        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));
        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));

        executionResult = await etf.connect(alice).mint(
            assets[0].address,
            toDecimal(10),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["0", toDecimal(10)]);

        //2.000.000 token 1 transfer for mint
        await assets[1].connect(alice).transfer(etf.address, toDecimal(1000000));
        await assets[1].connect(alice).transfer(etf.address, toDecimal(1000000));

        executionResult = await etf.connect(alice).mint(
            assets[1].address,
            toDecimal(20),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["0", toDecimal(20)]);

        await expect(executionResult).to.changeTokenBalances(assets[1], [
            etf.address,
            alice.address,
        ], ["-1599960000000000000000000", "1599960000000000000000000"]);

        expect(await etf.totalSupply()).to.be.equal(toDecimal(30));
        // 6M
        expect(await etf.totalCurrentUsdAmount()).to.be.equal(
            "6000000000000000000000000",
        );
        let asset1Balance = await assets[0].balanceOf(etf.address);
        asset1 = await etf.assets(
            assets[0].address,
        );
        expect(asset1.collectedFees).to.be.equal(
            "0",
        );
        expect(asset1.quantity).to.be.equal(
            "200000000000000000000000",
        );
        expect(asset1.collectedCashbacks).to.be.equal(
            "0",
        );

        expect(asset1Balance.sub(asset1.collectedFees).sub(asset1.quantity)).to.be
            .equal(
                "0",
            );

        asset2 = await etf.assets(
            assets[1].address,
        );
        expect(asset2.collectedFees).to.be.equal(
            "40000000000000000000",
        );
        expect(asset2.quantity).to.be.equal(
            "400000000000000000000000",
        );
        expect(asset2.collectedCashbacks).to.be.equal(
            "0",
        );

        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));

        let result = await router.estimateSwapAmountOut(
            etf.address,
            assets[0].address,
            assets[1].address,
            toDecimal(20001),
        );

        expect(result.fee).to.be.equal(toDecimal(1000025, 8));
        expect(result.amountOut).to.be.equal("19999000049997500124993");
        expect(result.shares).to.be.equal(toDecimal(1));
        expect(result.cashbackOut).to.be.equal("0");
        expect(result.cashbackIn).to.be.equal("0");

        result = await router.estimateSwapAmountIn(
            etf.address,
            assets[0].address,
            assets[1].address,
            "19999000049997500124993",
        );

        expect(result.fee).to.be.equal(toDecimal(1000025, 8).sub(BigNumber.from(2)));
        expect(result.amountIn).to.be.equal("20000999999999999979308");
        expect(result.shares).to.be.equal(toDecimal(1).sub(BigNumber.from(1)));
        expect(result.cashbackOut).to.be.equal("0");
        expect(result.cashbackIn).to.be.equal("0");

        executionResult = await etf.connect(alice).swap(
            assets[0].address,
            assets[1].address,
            toDecimal(1),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["-0", "0"]);

        // 80 unused
        await expect(executionResult).to.changeTokenBalances(assets[0], [
            etf.address,
            alice.address,
        ], ["-79999000000000000000000", "79999000000000000000000"]);

        // 20.600 received
        await expect(executionResult).to.changeTokenBalances(assets[1], [
            etf.address,
            alice.address,
        ], ["-19999000049997500124993", "19999000049997500124993"]);

        asset1Balance = await assets[0].balanceOf(etf.address);
        asset1 = await etf.assets(
            assets[0].address,
        );
        // 0.005% fees of 20k eq 1
        expect(asset1.collectedFees).to.be.equal(
            "1000000000000000000",
        );
        // +20k
        expect(asset1.quantity).to.be.equal(
            "220000000000000000000000",
        );
        expect(asset1.collectedCashbacks).to.be.equal(
            "0",
        );

        expect(asset1Balance.sub(asset1.collectedFees).sub(asset1.quantity)).to.be
            .equal(
                "0",
            );

        asset2 = await etf.assets(
            assets[1].address,
        );
        expect(asset2.collectedFees).to.be.equal(
            "40999950002499875006",
        );
        expect(asset2.quantity).to.be.equal(
            "380000000000000000000000",
        );
        expect(asset2.collectedCashbacks).to.be.equal(
            "0",
        );

        await assets[0].connect(alice).transfer(etf.address, toDecimal(100000));

        executionResult = await etf.connect(alice).swap(
            assets[0].address,
            assets[1].address,
            toDecimal(2),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["-0", "0"]);

        // 80 unused
        await expect(executionResult).to.changeTokenBalances(assets[0], [
            etf.address,
            alice.address,
        ], ["-59998000000000000000000", "59998000000000000000000"]);

        // 20.600 received
        await expect(executionResult).to.changeTokenBalances(assets[1], [
            etf.address,
            alice.address,
        ], ["-39998000099995000249987", "39998000099995000249987"]);

        asset1Balance = await assets[0].balanceOf(etf.address);
        asset1 = await etf.assets(
            assets[0].address,
        );
        // 0.005% fees of 20k eq 1
        expect(asset1.collectedFees).to.be.equal(
            "3000000000000000000",
        );
        expect(asset1.quantity).to.be.equal(
            "260000000000000000000000",
        );
        expect(asset1.collectedCashbacks).to.be.equal(
            "0",
        );

        expect(asset1Balance.sub(asset1.collectedFees).sub(asset1.quantity)).to.be
            .equal(
                "0",
            );

        asset2 = await etf.assets(
            assets[1].address,
        );
        expect(asset2.collectedFees).to.be.equal(
            "42999850007499625018",
        );
        expect(asset2.quantity).to.be.equal(
            "340000000000000000000000",
        );
        expect(asset2.collectedCashbacks).to.be.equal(
            "0",
        );

        // try swap again big amount

        await assets[0].connect(alice).transfer(etf.address, toDecimal(1000000));

        await expect(
            etf.connect(alice).swap(
                assets[0].address,
                assets[1].address,
                toDecimal(10),
                alice.address,
            ),
        ).to.be.revertedWith("MULTIPOOL: deviation overflow");

        await assets[1].connect(alice).transfer(
            etf.address,
            "10085374999999999997710",
        );

        executionResult = await etf.connect(alice).mint(
            assets[1].address,
            toDecimal(5, 17),
            alice.address,
        );

        await expect(executionResult).to.changeTokenBalances(etf, [
            etf.address,
            alice.address,
        ], ["0", toDecimal(5, 17)]);

        await expect(executionResult).to.changeTokenBalances(assets[1], [
            etf.address,
            alice.address,
        ], ["-0", "0"]);

        expect(await etf.totalSupply()).to.be.equal(toDecimal(305, 17));

        expect(await etf.totalCurrentUsdAmount()).to.be.equal(
            "6100000000000000000000000",
        );
        asset1Balance = await assets[0].balanceOf(etf.address);
        let asset2Balance = await assets[1].balanceOf(etf.address);
        asset1 = await etf.assets(
            assets[0].address,
        );
        expect(asset1.collectedFees).to.be.equal(
            "3000000000000000000",
        );
        expect(asset1.quantity).to.be.equal(
            "260000000000000000000000",
        );
        expect(asset1.collectedCashbacks).to.be.equal(
            "0",
        );

        // we transferred extra 100000 previously
        expect(
            asset1Balance.sub(asset1.collectedFees).sub(asset1.quantity).sub(
                asset1.collectedCashbacks,
            ),
        ).to.be
            .equal(
                toDecimal(1000000),
            );

        asset2 = await etf.assets(
            assets[1].address,
        );
        expect(asset2.collectedFees).to.be.equal(
            "43999850007499625018",
        );
        expect(asset2.quantity).to.be.equal(
            "350000000000000000000000",
        );
        expect(asset2.collectedCashbacks).to.be.equal(
            "84374999999999997712",
        );

        expect(
            asset2Balance.sub(asset2.collectedFees).sub(asset2.quantity).sub(
                asset2.collectedCashbacks,
            ),
        ).to.be
            .equal(
                "0",
            );
    });
});
