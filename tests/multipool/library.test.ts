import { ethers } from 'hardhat';

describe.only("Multipool library", function() {
    let ETF: any;
    let etf: any;

    before(async () => {
        ETF = await ethers.getContractFactory("TestMultipoolMath");
    });

    beforeEach(async function() {
        etf = await ETF.deploy();
    });

    it("Mint with zero balance", async function() {
        await etf.mintWithZeroBalance();
    });
    it("Mint with deviation fee", async function() {
        await etf.mintWithDeviationFee();
    });
    it("Mint with deviation fee reversed", async function() {
        await etf.mintWithDeviationFeeReversed();
    });
    it("Burn with deviation fee", async function() {
        await etf.burnWithDeviationFee();
    });
    it("Burn with deviation fee reversed", async function() {
        await etf.burnWithDeviationFeeReversed();
    });
});


