import { ethers } from "hardhat";
import { Contract, ContractFactory, Signer } from "ethers";
import { expect } from "chai";
import { toDecimal } from "../utils/numbers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Multipool: Burn", () => {
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

    beforeEach(async () => {
        multipool = await MultipoolFactory.deploy("ETF1", "ETF1");

        tokenA = await TokenFactory.deploy("Token A", "A", toDecimal(10000));
        tokenB = await TokenFactory.deploy("Token B", "B", toDecimal(10000));
        tokenC = await TokenFactory.deploy("Token C", "C", toDecimal(10000));
        tokenD = await TokenFactory.deploy("Token D", "D", toDecimal(10000));

        // apply the same setup as in the swap test, percent / prices
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

    it.skip("should burn LP tokens and return the correct asset quantity", async () => {
        const shareToBurn = ethers.utils.parseEther("1000");

        await multipool.connect(user).approve(multipool.address, shareToBurn);
        await multipool.connect(user).transfer(multipool.address, shareToBurn);
        await multipool.connect(user).burn(shareToBurn, tokenA.address, user.address);
        expect(await tokenA.balanceOf(user.address)).to.equal(toDecimal(33333));
    });

    it.skip("should fail if not enough LP tokens to burn", async () => {
        const shareToBurn = ethers.utils.parseEther("1000");

        await multipool.connect(user).approve(multipool.address, shareToBurn);
        await multipool.connect(user).transfer(multipool.address, shareToBurn);
        await expect(multipool.connect(user).burn(shareToBurn.add(1), tokenA.address, user.address)).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });
});
