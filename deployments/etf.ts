import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat/config";
import "hardhat-abi-exporter";

import clicolor from "cli-color";
import * as dotenv from "dotenv";
import { BigNumber, ethers as deflautEthers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { subtask, task } from "hardhat/config";
import fs from "fs";
import axios from 'axios';

dotenv.config();

interface ETFToken {
    id: string;
    address: string;
    mcap: BigNumber;
    persent: BigNumber;
}

interface TokenMarketData {
    name: string;
    symbol: string;
    marketCap: BigNumber;
}

async function getTokenMarketCap(tokenId: string, vsCurrency: string = 'usd'): Promise<TokenMarketData> {
    try {
        const apiUrl = `https://api.coingecko.com/api/v3/coins/${tokenId}`;

        const response = await axios.get(apiUrl, { params: { vs_currency: vsCurrency } });

        const name = response.data.name;
        const symbol = response.data.symbol;
        const marketCap = response.data.market_data.market_cap[vsCurrency];

        return { name, symbol, marketCap };
    } catch (error) {
        console.error(error);
        throw new Error('Error fetching token market cap');
    }
}

const delay = (ms: number | undefined) =>
    new Promise((res) => setTimeout(res, ms));
const mainLine = () => console.log(clicolor.white("_".repeat(80)));
const lowLine = () => console.log(clicolor.white("-".repeat(80)));

async function awaitBytecode(address: string, hre: HardhatRuntimeEnvironment) {
    console.log("Awaiting bytecode for ", clicolor.green(address));
    if (hre.hardhatArguments.network == "hardhat") return;
    const provider = new deflautEthers.providers.JsonRpcProvider(
        hre.network.config.url
    );
    let code = "0x";
    while (code === "0x") {
        await delay(5000);
        try {
            code = await provider.getCode(address);
        } catch (e) {
            console.log(e);
        }
    }
    console.log("Bytecode received for ", clicolor.green(address));
    await delay(30000);
}

// deploy simple token
subtask("deploy-simple-token", "Deploy simple token  with standart parameters")
    .addParam("name", "Token name", "RND111")
    .addParam("symbol", "Token symbol", "rnd111")
    .addParam("supply", "Token supply", "1000000000000000000000000")
    .addFlag("verify", "Verify contract on Etherscan")
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();

        console.log(
            "Deploying " + clicolor.bgGreen("simple-token") + " with the account:",
            clicolor.underline(deployer.address)
        );

        const ERC20 = await hre.ethers.getContractFactory("MockERC20");
        let TOKEN: any;

        try {
            TOKEN = await ERC20.connect(deployer).deploy(
                argsTask.name,
                argsTask.symbol,
                argsTask.supply
            );
        } catch (e: any) {
            if (e.code == "INSUFFICIENT_FUNDS")
                console.log(
                    "Account " +
                    clicolor.red(deployer.address) +
                    " has insufficient funds to deploy contracts"
                );
            process.exit(1);
        }

        console.log("Token deployed to:", clicolor.bgGreen(TOKEN.address));

        if (argsTask.verify) {
            await awaitBytecode(TOKEN.address, hre);
            try {
                await hre.run("verify:verify", {
                    address: TOKEN.address,
                    network: hre.hardhatArguments.network,
                    constructorArguments: [
                        argsTask.name,
                        argsTask.symbol,
                        argsTask.supply,
                    ],
                });
            } catch (e: any) {
                if (e.message.includes("Already Verified")) {
                    console.info(clicolor.yellow("Already Verified"));
                } else {
                    console.error("Token:", e);
                }
            }
        }

        return TOKEN.address;
    });

// deploy UniV2 pair
subtask("deploy-univ2-pair", "Deploy UniV2 pair")
    .addParam("token0", "Token0 address")
    .addParam("token1", "Token1 address")
    .addFlag("verify", "Verify contract on Etherscan")
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();

        console.log(
            "Deploying " + clicolor.bgGreen("univ2-pair") + " with the account:",
            clicolor.underline(deployer.address)
        );

        const PairFactory = await hre.ethers.getContractFactory("UniswapV2Pair");
        const pair = await PairFactory.connect(deployer).deploy();

        console.log("Pair deployed to:", clicolor.bgGreen(pair.address));

        await pair.initialize(argsTask.token0, argsTask.token1);

        // add liquidity
        const token0 = await hre.ethers.getContractAt(
            "MockERC20",
            argsTask.token0
        );

        const token1 = await hre.ethers.getContractAt(
            "MockERC20",
            argsTask.token1
        );

        const amount0 = "1000000000000000000000000";
        const amount1 = "1000000000000000000000000";

        await token0.connect(deployer).transfer(pair.address, amount0);
        await token1.connect(deployer).transfer(pair.address, amount1);

        await pair.mint(deployer.address);

        console.log("Liquidity added to pair");

        if (argsTask.verify) {
            await awaitBytecode(pair.address, hre);
            try {
                await hre.run("verify:verify", {
                    address: pair.address,
                    network: hre.hardhatArguments.network,
                    constructorArguments: [deployer.address],
                });
            } catch (e: any) {
                if (e.message.includes("Already Verified")) {
                    console.info(clicolor.yellow("Already Verified"));
                } else {
                    console.error("Pair:", e);
                }
            }
        }

        return pair.address;
    });

subtask("deploy-etf", "Deploy ETF with standart parameters")
    .addParam("name", "ETF name", "ETF111")
    .addParam("symbol", "ETF symbol", "etf111")
    .addFlag("verify", "Verify contract on Etherscan")
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();

        console.log(
            "Deploying " + clicolor.bgGreen("etf") + " with the account:",
            clicolor.underline(deployer.address)
        );

        const ETF = await hre.ethers.getContractFactory("Multipool");
        let ETFContract: any;

        try {
            ETFContract = await ETF.connect(deployer).deploy(
                argsTask.name,
                argsTask.symbol
            );
        } catch (e: any) {
            if (e.code == "INSUFFICIENT_FUNDS")
                console.log(
                    "Account " +
                    clicolor.red(deployer.address) +
                    " has insufficient funds to deploy contracts"
                );
            process.exit(1);
        }

        console.log("ETF deployed to:", clicolor.bgGreen(ETFContract.address));

        if (argsTask.verify) {
            await awaitBytecode(ETFContract.address, hre);
            try {
                await hre.run("verify:verify", {
                    address: ETFContract.address,
                    network: hre.hardhatArguments.network,
                    constructorArguments: [
                        argsTask.name,
                        argsTask.symbol,
                        argsTask.supply,
                    ],
                });
            } catch (e: any) {
                if (e.message.includes("Already Verified")) {
                    console.info(clicolor.yellow("Already Verified"));
                } else {
                    console.error("ETF:", e);
                }
            }
        }

        // read line by line from file
        let file = fs.readFileSync("tokens.txt", "utf8");
        let raw_tokens = file.split("\r\n");

        let tokens: string[] = [];

        // execute subtask and make 4 tokens
        for (let i = 0; i < 4; i++) {
            let token_address = await hre.run("deploy-simple-token", {
                name: raw_tokens[i],
                symbol: raw_tokens[i],
                verify: argsTask.verify,
            });
            await delay(2000);
            tokens.push(token_address);
        }

        let tokensWithPercents: ETFToken[] = [];
        let totalPercent: BigNumber = BigNumber.from(0);

        // get mcap of each token, from coingecko
        for (let i = 0; i < 4; i++) {
            let mcap = await getTokenMarketCap(raw_tokens[i]);
            totalPercent = totalPercent.add(BigNumber.from(mcap.marketCap));

            tokensWithPercents.push({
                id: raw_tokens[i],
                address: tokens[i],
                mcap: mcap.marketCap,
                persent: BigNumber.from(0),
            });
        }

        // calculate percents
        for (let i = 0; i < 4; i++) {
            const mcap: BigNumber = tokensWithPercents[i].mcap;

            tokensWithPercents[i].persent = BigNumber.from(mcap).mul(100).div(totalPercent);
        }

        // add tokens to ETF
        for (let i = 0; i < 4; i++) {
            await ETFContract.updateAssetPercents(tokensWithPercents[i].address, tokensWithPercents[i].persent);
            await delay(2000);

            console.log("Token " + clicolor.bgGreen(tokensWithPercents[i].address) + " added to ETF with percent " + clicolor.bgGreen(tokensWithPercents[i].persent.toString()));
        }

        return ETFContract.address;
    });

task("deploy-all", "Deploy all contracts")
    .addFlag("verify", "Verify contracts on etherscan")
    .setAction(async (taskArgs, hre) => {
        mainLine();

        //const ZNAK = await hre.run("deploy-znak", { verify: taskArgs.verify });
        mainLine();
        await delay(2000);
        await hre.run("deploy-etf", { name: "TESTETF", symbol: "tstetf", verify: taskArgs.verify });
    });
