import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import * as Parallel from 'async-parallel';
import { expect } from 'chai';
import { BigNumber, Contract, ContractFactory } from 'ethers';
import { ethers } from 'hardhat';
import { deployUniswapV2Pool, deployUniswapV2PoolWithTokens } from '../FIXTURES/UniV2';

import { toDecimal } from '../utils/numbers';

describe.skip("Benchmark ETFV1", function() {
    let owner: SignerWithAddress, alice, bob, carol, treasury: SignerWithAddress;
    let ETF, ERC20: ContractFactory, etfFactory: ContractFactory, etfFactoryInstance: Contract;
    let Tokens: string[] = [];
    let USDC: Contract;
    let router: Contract;
    let routerFactory: ContractFactory;

    before(async () => {
        [owner, alice, bob, carol, treasury] = await ethers.getSigners();
        ETF = await ethers.getContractFactory("ETF");
        ERC20 = await ethers.getContractFactory("MockERC20");
        etfFactory = await ethers.getContractFactory("ETFFactory");
        // deploy router
        routerFactory = await ethers.getContractFactory("ETFRouterV1");
    });

    beforeEach(async () => {
        etfFactoryInstance = await etfFactory.deploy();
        await etfFactoryInstance.deployed();

        USDC = await ERC20.connect(owner).deploy("USDC", "USDC", toDecimal(100000000));
        router = await routerFactory.deploy();

        // deploy 700 tokens, in parallel
        Tokens = await Parallel.map(Array.from(Array(700).keys()), async (i) => {
            const token = await ERC20.connect(owner).deploy(`TOKEN${i}`, `TOKEN${i}`, toDecimal(10000000));
            return token.address;
        });
    });

    // benchmark for ETFV1, deploy ETFV1, with 1, 10, 100 tokens, and measure the gas cost
    it("Benchmark 1, 10, 100, 650 tokens", async () => {
        // 1 token
        const OneTOKEN = Tokens.slice(0, 1);
        const ETFV1_1TOKEN = await etfFactoryInstance.connect(owner).createETF("ETFV1_1TOKEN", "ETFV1_1TOKEN", OneTOKEN, treasury.address, 1, 100);
        console.log("Deploy ETF: 1 token: ", (await ethers.provider.getTransactionReceipt(ETFV1_1TOKEN.hash)).gasUsed.toString());
        // 10 tokens
        const TenTOKENS = Tokens.slice(0, 10);
        const ETFV1_10TOKENS = await etfFactoryInstance.connect(owner).createETF("ETFV1_10TOKENS", "ETFV1_10TOKENS", TenTOKENS, treasury.address, 1, 100);
        console.log("Deploy ETF: 10 tokens: ", (await ethers.provider.getTransactionReceipt(ETFV1_10TOKENS.hash)).gasUsed.toString());
        // 100 tokens
        const HundredTOKENS = Tokens.slice(0, 100);
        const ETFV1_100TOKENS = await etfFactoryInstance.connect(owner).createETF("ETFV1_100TOKENS", "ETFV1_100TOKENS", HundredTOKENS, treasury.address, 1, 100);
        console.log("Deploy ETF: 100 tokens: ", (await ethers.provider.getTransactionReceipt(ETFV1_100TOKENS.hash)).gasUsed.toString());
        // 1000 tokens, expect to fail
        const ThousandTOKENS = Tokens.slice(0, 650);
        const ETFV1_1000TOKENS = await etfFactoryInstance.connect(owner).createETF("ETFV1_1000TOKENS", "ETFV1_1000TOKENS", ThousandTOKENS, treasury.address, 1, 100);
        console.log("Deploy ETF: 650 tokens: ", (await ethers.provider.getTransactionReceipt(ETFV1_1000TOKENS.hash)).gasUsed.toString());
    });

    // benchmark for ETFV1, deploy ETFV1, with 1, 10, 100 tokens, and measure the gas cost of minting
    it("Benchmark 1, 10, 100, 650 tokens minting", async () => {
        const OneTOKEN = Tokens.slice(0, 1);
        const TenTOKENS = Tokens.slice(0, 10);
        const HundredTOKENS = Tokens.slice(0, 100);
        const ThousandTOKENS = Tokens.slice(0, 650);

        const Params = [OneTOKEN, TenTOKENS, HundredTOKENS, ThousandTOKENS];

        for (let i = 0; i < Params.length; i++) {
            const ETFV1 = await etfFactoryInstance.connect(owner).createETF(`ETFV1${i}`, `ETFV1${i}`, Params[i], treasury.address, 1, 100);
        }

        // get the address of the ETF
        const ETFAddresses = await etfFactoryInstance.getBundle(0, 4);

        for (let i = 0; i < ETFAddresses.length; i++) {
            const etf = await ethers.getContractAt("ETF", ETFAddresses[i]);
            for (let j = 0; j < Params[i].length; j++) {
                await ERC20.attach(Params[i][j]).connect(owner).approve(etf.address, toDecimal(100));
                ERC20.attach(Params[i][j]).connect(owner).transfer(etf.address, toDecimal(100));
            }
            const mint = await etf.connect(owner).mint(toDecimal(100), owner.address);
            console.log(`Minting ${Params[i].length} tokens: `, (await ethers.provider.getTransactionReceipt(mint.hash)).gasUsed.toString());
        }
    });

    // benchmark for ETFV1, deploy ETFV1, with 1, 10, 100 tokens, and measure the gas cost of redeeming
    it("Benchmark 1, 10, 100, 650 tokens redeeming", async () => {
        const OneTOKEN = Tokens.slice(0, 1);
        const TenTOKENS = Tokens.slice(0, 10);
        const HundredTOKENS = Tokens.slice(0, 100);
        const ThousandTOKENS = Tokens.slice(0, 650);

        const Params = [OneTOKEN, TenTOKENS, HundredTOKENS, ThousandTOKENS];

        for (let i = 0; i < Params.length; i++) {
            const ETFV1 = await etfFactoryInstance.connect(owner).createETF(`ETFV1${i}`, `ETFV1${i}`, Params[i], treasury.address, 1, 100);
        }

        // get the address of the ETF
        const ETFAddresses = await etfFactoryInstance.getBundle(0, 4);

        for (let i = 0; i < ETFAddresses.length; i++) {
            const etf = await ethers.getContractAt("ETF", ETFAddresses[i]);
            for (let j = 0; j < Params[i].length; j++) {
                await ERC20.attach(Params[i][j]).connect(owner).approve(etf.address, toDecimal(100));
                ERC20.attach(Params[i][j]).connect(owner).transfer(etf.address, toDecimal(100));
            }
            const mint = await etf.connect(owner).mint(toDecimal(100), owner.address);
            // console.log(`Minting ${Params[i].length} tokens: `, (await ethers.provider.getTransactionReceipt(mint.hash)).gasUsed.toString());
        }

        // redeem
        for (let i = 0; i < ETFAddresses.length; i++) {
            const etf = await ethers.getContractAt("ETF", ETFAddresses[i]);
            // console.log(`etf balanceOf: ${await etf.balanceOf(owner.address)}`);
            const redeem = await etf.connect(owner).burn(toDecimal(99), owner.address);
            console.log(`Redeeming ${Params[i].length} tokens: `, (await ethers.provider.getTransactionReceipt(redeem.hash)).gasUsed.toString());
        }
    });

    // benchmark for ETFV1, deploy ETFV1, with 1, 10, 100 tokens, and measure the gas cost of mint using router
    it("Benchmark 1, 10, 100, 410 tokens minting using router", async () => {
        const OneTOKEN = Tokens.slice(0, 1);
        const TenTOKENS = Tokens.slice(0, 10);
        const HundredTOKENS = Tokens.slice(0, 100);
        const ThousandTOKENS = Tokens.slice(0, 410);

        const Params = [OneTOKEN, TenTOKENS, HundredTOKENS, ThousandTOKENS];

        // deploy router
        const routerFactory = await ethers.getContractFactory("ETFRouterV1");
        const router = await routerFactory.deploy();

        for (let i = 0; i < Params.length; i++) {
            const ETFV1 = await etfFactoryInstance.connect(owner).createETF(`ETFV1${i}`, `ETFV1${i}`, Params[i], treasury.address, 1, 100);
        }

        // get the address of the ETF
        const ETFAddresses = await etfFactoryInstance.getBundle(0, 4);

        for (let i = 0; i < ETFAddresses.length; i++) {
            const etf = await ethers.getContractAt("ETF", ETFAddresses[i]);
            for (let j = 0; j < Params[i].length; j++) {
                await ERC20.attach(Params[i][j]).connect(owner).approve(router.address, toDecimal(100));
            }
            const amounts = Params[i].map((token) => toDecimal(1));
            const mint = await router.connect(owner).mintFrom(etf.address, Params[i], amounts, toDecimal(1), owner.address);
            console.log(`Minting ${Params[i].length} tokens using router: `, (await ethers.provider.getTransactionReceipt(mint.hash)).gasUsed.toString());
        }
    });

    it("Benchmark 1, 10, 100, 145 tokens minting using router from single asset", async () => {
        const OneTOKEN = Tokens.slice(0, 1);
        const TenTOKENS = Tokens.slice(0, 10);
        const HundredTOKENS = Tokens.slice(0, 100);
        const ThousandTOKENS = Tokens.slice(0, 145);

        const Params = [OneTOKEN, TenTOKENS, HundredTOKENS, ThousandTOKENS];

        // approve USDC to router
        await USDC.connect(owner).approve(router.address, toDecimal(10000000));

        for (let i = 0; i < Params.length; i++) {
            const ETFV1 = await etfFactoryInstance.connect(owner).createETF(`ETFV1${i}`, `ETFV1${i}`, Params[i], treasury.address, 1, 100);
        }

        // get the address of the ETF
        const ETFAddresses = await etfFactoryInstance.getBundle(0, 4);
        // get ETF instance
        const ETFInstances = await Promise.all(ETFAddresses.map(async (address: string) => await ethers.getContractAt("ETF", address)));


        // create a pool for each token with usdc
        let pools: string[] = await Parallel.map(ThousandTOKENS, async (token) => {
            return (await deployUniswapV2PoolWithTokens(token, USDC.address, toDecimal(100), toDecimal(100), owner)).pool;
        });

        // call mintFromSingleAsset from USDC to all tokens
        for (let i = 0; i < ETFInstances.length; i++) {

            // create `swapPaths`, `_pairs` and `_amounts` to be used in mintFromSingleAsset
            const _swapPaths: string[][] = Params[i].map((token) => [USDC.address, token]);
            const _pairs: string[][] = Params[i].map((_, y) => [pools[y]]);
            const amounts: string[][] = Params[i].map((_) => [toDecimal(10).toString(), toDecimal(1).toString()]);

            // console.log(_swapPaths);
            // console.log(_pairs);
            // console.log(amounts);

            const mint = await router.connect(owner).mintFromSingleAsset(ETFInstances[i].address, _swapPaths, _pairs, amounts, toDecimal(1), owner.address);
            console.log(`Minting ${Params[i].length} tokens using router: `, (await ethers.provider.getTransactionReceipt(mint.hash)).gasUsed.toString());
            // tokens in the etf
            // const etfTokens: string = await ETFInstances[i].getAssetAddresses();
        }
    });
});
