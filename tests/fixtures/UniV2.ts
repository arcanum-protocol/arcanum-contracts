import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';

export async function deployUniswapV2Pool(
    amount1: any,
    amount2: any,
    to: string,
) {
    const poolFactory = await ethers.getContractFactory("UniswapV2Pair");
    const pair = await poolFactory.deploy();

    const tokenFactory = await ethers.getContractFactory("MockERC20");
    const token1 = await tokenFactory.deploy("RNDM", "RNDM", amount1);
    const token2 = await tokenFactory.deploy("RNDM", "RNDM", amount2);

    await pair.initialize(token1.address, token2.address);

    await token1.transfer(pair.address, amount1);
    await token2.transfer(pair.address, amount2);

    await pair.mint(to);

    return {
        pool: pair.address,
        token1: token1.address,
        token2: token2.address,
    };
}

// create a new pool, with specific tokens and amounts
export async function deployUniswapV2PoolWithTokens(
    token1: string,
    token2: string,
    amount1: any,
    amount2: any,
    owner: SignerWithAddress,
) {
    const poolFactory = await ethers.getContractFactory("UniswapV2Pair");
    const pair = await poolFactory.deploy();

    await pair.initialize(token1, token2);

    const firstToken = await ethers.getContractAt("MockERC20", token1);
    const secondToken = await ethers.getContractAt("MockERC20", token2);

    await firstToken.connect(owner).transfer(pair.address, amount1);
    await secondToken.connect(owner).attach(token2).transfer(pair.address, amount2);

    await pair.mint(owner.address);

    return {
        pool: pair.address,
        token1: token1,
        token2: token2,
    };
}
