import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { ethers } from "hardhat";
import { toDecimal } from "../utils/numbers";

describe.skip("Multipool: Swap", () => {
    let owner: SignerWithAddress, user: SignerWithAddress, mev: SignerWithAddress;
    let multipool: Contract;
    let tokenA: Contract, tokenB: Contract, tokenC: Contract, tokenD: Contract;

    let TokenFactory: ContractFactory;
    let MultipoolFactory: ContractFactory;

    before(async function() {
        [owner, user, mev] = await ethers.getSigners();
        TokenFactory = await ethers.getContractFactory("MockERC20");
        MultipoolFactory = await ethers.getContractFactory("Multipool");
    });

    beforeEach(async function() {
        tokenA = await TokenFactory.deploy("Token A", "A", toDecimal(10000));
        tokenB = await TokenFactory.deploy("Token B", "B", toDecimal(10000));
        tokenC = await TokenFactory.deploy("Token C", "C", toDecimal(10000));
        tokenD = await TokenFactory.deploy("Token D", "D", toDecimal(10000));

        multipool = await MultipoolFactory.deploy("ETF1", "ETF1");

        // transfer tokens to the owner, user, and mev
        await tokenA.mint(owner.address, toDecimal(100000));
        await tokenA.mint(user.address, toDecimal(100000));
        await tokenA.mint(mev.address, toDecimal(100000));

        await tokenB.mint(owner.address, toDecimal(100000));
        await tokenB.mint(user.address, toDecimal(100000));
        await tokenB.mint(mev.address, toDecimal(100000));

        await tokenC.mint(owner.address, toDecimal(100000));
        await tokenC.mint(user.address, toDecimal(100000));
        await tokenC.mint(mev.address, toDecimal(100000));

        await tokenD.mint(owner.address, toDecimal(100000));
        await tokenD.mint(user.address, toDecimal(100000));
        await tokenD.mint(mev.address, toDecimal(100000));

        // add assets to the multipool
        await multipool.connect(owner).updateAssetPercents(tokenA.address, toDecimal(33333));
        await multipool.connect(owner).updateAssetPercents(tokenB.address, toDecimal(33333));
        await multipool.connect(owner).updateAssetPercents(tokenC.address, toDecimal(33333));
        await multipool.connect(owner).updateAssetPercents(tokenD.address, toDecimal(0));

        // set prices 
        await multipool.connect(owner).updatePrice(tokenA.address, toDecimal(1));
        await multipool.connect(owner).updatePrice(tokenB.address, toDecimal(1));
        await multipool.connect(owner).updatePrice(tokenC.address, toDecimal(1));

        // -- mint from owner first LP -- //
        // tokenA
        await tokenA.connect(owner).approve(multipool.address, toDecimal(100));
        await tokenA.connect(owner).transfer(multipool.address, toDecimal(100));
        await multipool.connect(owner).mint(tokenA.address, owner.address);

        // tokenB
        await tokenB.connect(owner).approve(multipool.address, toDecimal(100));
        await tokenB.connect(owner).transfer(multipool.address, toDecimal(100));
        await multipool.connect(owner).mint(tokenB.address, owner.address);

        // tokenC
        await tokenC.connect(owner).approve(multipool.address, toDecimal(100));
        await tokenC.connect(owner).transfer(multipool.address, toDecimal(100));
        await multipool.connect(owner).mint(tokenC.address, owner.address);
    });

    it("Standart Swap", async () => {
        await tokenA.connect(user).approve(multipool.address, toDecimal(1));
        await tokenA.connect(user).transfer(multipool.address, toDecimal(1));
        await multipool.connect(user).swap(tokenA.address, tokenB.address, user.address);
        expect(await tokenA.balanceOf(user.address)).to.equal(toDecimal(999));
        expect(await tokenB.balanceOf(user.address)).to.equal(toDecimal(1001)); // note: change to actual value, with sub(fees)
    });

    it("Swap with a lower curve delay", async () => {
        await multipool.connect(owner).setCurveDelay(1);

        await tokenA.connect(user).approve(multipool.address, toDecimal(1));
        await tokenA.connect(user).transfer(multipool.address, toDecimal(1));
        await multipool.connect(user).swap(tokenA.address, tokenB.address, user.address);
        expect(await tokenA.balanceOf(user.address)).to.equal(toDecimal(999));
        expect(await tokenB.balanceOf(user.address)).to.equal(toDecimal(1001)); // note: change to actual value, with sub(fees)
    });

    it("Swap with a higher curve delay", async () => {
        await multipool.connect(owner).setCurveDelay(2);

        await tokenA.connect(user).approve(multipool.address, toDecimal(1));
        await tokenA.connect(user).transfer(multipool.address, toDecimal(1));
        await multipool.connect(user).swap(tokenA.address, tokenB.address, user.address);
        expect(await tokenA.balanceOf(user.address)).to.equal(toDecimal(999));
        expect(await tokenB.balanceOf(user.address)).to.equal(toDecimal(1001)); // note: change to actual value, with sub(fees)
    });

    it("Swap with a higher restrictPercent", async () => {
        await multipool.connect(owner).setRestrictPercent(1);

        await tokenA.connect(user).approve(multipool.address, toDecimal(1));
        await tokenA.connect(user).transfer(multipool.address, toDecimal(1));
        await multipool.connect(user).swap(tokenA.address, tokenB.address, user.address);
        expect(await tokenA.balanceOf(user.address)).to.equal(toDecimal(999));
        expect(await tokenB.balanceOf(user.address)).to.equal(toDecimal(1001)); // note: change to actual value, with sub(fees)
    });

    it("Swap with a higher baseTradeFee", async () => {
        await multipool.connect(owner).setBaseTradeFee(1);

        await tokenA.connect(user).approve(multipool.address, toDecimal(1));
        await tokenA.connect(user).transfer(multipool.address, toDecimal(1));
        await multipool.connect(user).swap(tokenA.address, tokenB.address, user.address);
        expect(await tokenA.balanceOf(user.address)).to.equal(toDecimal(999));
        expect(await tokenB.balanceOf(user.address)).to.equal(toDecimal(1001)); // note: change to actual value, with sub(fees)
    });

    it("Swap with a lower baseTradeFee", async () => {
        await multipool.connect(owner).setBaseTradeFee(0);

        await tokenA.connect(user).approve(multipool.address, toDecimal(1));
        await tokenA.connect(user).transfer(multipool.address, toDecimal(1));
        await multipool.connect(user).swap(tokenA.address, tokenB.address, user.address);
        expect(await tokenA.balanceOf(user.address)).to.equal(toDecimal(999));
        expect(await tokenB.balanceOf(user.address)).to.equal(toDecimal(1001)); // note: change to actual value, with sub(fees)
    });

    it("Swap with an asset that has a zero percent allocation", async () => {
        await tokenD.connect(user).transfer(multipool.address, toDecimal(1));
        expect(await multipool.connect(user).swap(tokenD.address, tokenB.address, user.address)).to.be.reverted;
        expect(await tokenD.balanceOf(user.address)).to.equal(toDecimal(999));
        expect(await tokenB.balanceOf(user.address)).to.equal(toDecimal(1000)); // note: change to actual value, with sub(fees)
    });
});
