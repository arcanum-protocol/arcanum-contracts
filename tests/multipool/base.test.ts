import * as Parallel from 'async-parallel';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import '@nomicfoundation/hardhat-chai-matchers';

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

    it("ETF mint and swap should work", async function() {

        let result: any;

        await etf.connect(owner).updateAssetPercents(assets[0].address, toDecimal(50));
        await etf.connect(owner).updateAssetPercents(assets[1].address, toDecimal(50));

        await etf.connect(owner).setCurveCoef(toDecimal(3, 14));
        await etf.connect(owner).setDeviationPercentLimit(toDecimal(1, 17));

        await etf.connect(owner).updatePrice(assets[0].address, toDecimal(10));
        await etf.connect(owner).updatePrice(assets[1].address, toDecimal(10));

        await assets[0].connect(alice).transfer(etf.address, toDecimal(10));

        await etf.connect(alice).mint(assets[0].address, toDecimal(10), alice.address);

        await assets[1].connect(alice).transfer(etf.address, toDecimal(1001, 15));

        await etf.connect(alice).mint(assets[1].address, toDecimal(1), alice.address);

        await etf.connect(alice).transfer(etf.address, toDecimal(1));

        await etf.connect(alice).burn(assets[0].address, toDecimal(1), alice.address);

        await assets[1].connect(alice).transfer(etf.address, toDecimal(1001, 15));

        result = await etf.connect(alice).swap(assets[1].address, assets[0].address, toDecimal(10005, 15), alice.address);

        await expect(result).to.changeTokenBalances(assets[0], [etf.address, alice.address], ['-1000000000000000000', '1000000000000000000']);

    });
})
