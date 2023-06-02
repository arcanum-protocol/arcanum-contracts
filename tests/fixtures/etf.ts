import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { Multipool } from "../../typechain-types/contracts/etf/index"
import { MockERC20 } from "../../typechain-types/contracts/mocks/erc20.sol/index"
import * as Parallel from 'async-parallel';
import { toDecimal } from '../utils/numbers';

export async function deployEtf(
    erc20Factory: any,
    etfFactory: any,
    tokensAmount: number,
    receivers: any[]
): Promise<[Multipool, MockERC20[]]> {
    const tokens = [...Array(tokensAmount).keys()];
    const etf = await etfFactory.deploy(
        "ETF1",
        "ETF1",
    );
    const assets = await Parallel.map(tokens, async (i) => {
        const asset = await erc20Factory.deploy("asset" + i, "a" + i, toDecimal(100000000000));
        for (const recv of receivers) {
            await asset.transfer(recv.address, toDecimal(10000000));
        }
        await etf.updateAssetPercents(asset.address, toDecimal(10 * ++i));
        await etf.updatePrice(asset.address, toDecimal(100));
        return asset as MockERC20;
    });
    console.log("set percent");
    await etf.setRestrictPercent(toDecimal(13));
    await etf.setCurveDelay(toDecimal(13));
    return [etf, assets];
}
