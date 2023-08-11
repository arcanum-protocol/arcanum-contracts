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
import { subtask, task, types } from "hardhat/config";
import fs from "fs";
import axios from "axios";

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

async function getTokenMarketCap(
    tokenId: string,
    vsCurrency: string = "usd",
): Promise<TokenMarketData> {
    try {
        const apiUrl = `https://api.coingecko.com/api/v3/coins/${tokenId}`;

        const response = await axios.get(apiUrl, {
            params: { vs_currency: vsCurrency },
        });

        const name = response.data.name;
        const symbol = response.data.symbol;
        const marketCap = response.data.market_data.market_cap[vsCurrency];

        return { name, symbol, marketCap };
    } catch (error) {
        console.error(error);
        throw new Error("Error fetching token market cap");
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
        hre.network.config.url,
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

task("first-mint", "Deploy whole infrastructure with specified token names list")
    .addParam("multipool", "address")
    .addParam("token", "token address")
    .addParam("amount", "token address")
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();
        const Multipool = await hre.ethers.getContractAt("Multipool", argsTask.multipool);
        const Token = await hre.ethers.getContractAt("MockERC20", argsTask.token);
        await Token.connect(deployer).mint(argsTask.multipool, argsTask.amount);
        await delay(13000);
        await Multipool.connect(deployer).mint(argsTask.token, argsTask.amount, deployer.address);
        //await tx.wait();
        await delay(13000);
    });

task("add-percents", "Deploy whole infrastructure with specified token names list")
    .addParam("multipoolAddress", "address")
    .addParam("tokens", "Json file with token info")
    .addParam("deployRouter", "Defines wether to deploy MultipoolRouter", true, types.boolean, true)
    .addParam("verify", "Verify contract on Etherscan", true, types.boolean, true)
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();
        const tokenList = JSON.parse(fs.readFileSync(argsTask.tokens, { encoding: 'utf8', flag: 'r' }));
        // const MULTIPOOL = await hre.ethers.getContractFactory("MultipoolRouter");
        // const Multipool = MULTIPOOL.attach(argsTask.multipoolAddress);
        const Multipool = await hre.ethers.getContractAt("Multipool", argsTask.multipoolAddress);
        for (let i = 0; i < tokenList.length; i++) {
            let token = tokenList[i];
            if (!token.address) {
                console.log("Deploying ", token.symbol);
                token.address = await hre.run("deploy-erc20-token", {
                    name: token.name,
                    symbol: token.symbol,
                    verify: argsTask.verify
                });
            }
            console.log("setting share for ", token.symbol);
            let tx = await Multipool.connect(deployer).updateAssetPercents(token.address, token.initialShare);
            //await tx.wait();
            await delay(13000);
        }

        let tx = await Multipool.connect(deployer).updateAssetPercents('0x588F899FeFf77CD4f34D05eC435ed435A31DecCd',
            0);
        if (argsTask.deployRouter) {
            await hre.run("deploy-multipool-router", {
                verify: argsTask.verify
            });
        }
    });

task("deploy-all", "Deploy whole infrastructure with specified token names list")
    .addParam("name", "Multipool name")
    .addParam("symbol", "Multipool symbol")
    .addParam("tokens", "Json file with token info")
    .addParam("deployRouter", "Defines wether to deploy MultipoolRouter", true, types.boolean, true)
    .addParam("verify", "Verify contract on Etherscan", true, types.boolean, true)
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();
        const tokenList = JSON.parse(fs.readFileSync(argsTask.tokens, { encoding: 'utf8', flag: 'r' }));
        const Multipool = await hre.run("deploy-multipool", {
            name: argsTask.name,
            symbol: argsTask.symbol,
            verify: argsTask.verify
        });
        for (let i = 0; i < tokenList.length; i++) {
            let token = tokenList[i];
            if (!token.address) {
                console.log("Deploying ", token.symbol);
                token.address = await hre.run("deploy-erc20-token", {
                    name: token.name,
                    symbol: token.symbol,
                    verify: argsTask.verify
                });
            }
            console.log("setting share for ", token.symbol);
            await Multipool.connect(deployer).updateAssetPercents(token.address, token.initialShare);
            await delay(10000);
        }
        if (argsTask.deployRouter) {
            await hre.run("deploy-multipool-router", {
                verify: argsTask.verify
            });
        }
    });

// deploy simple token
task("deploy-erc20-token", "Deploy simple token  with standart parameters")
    .addParam("name", "Token name")
    .addParam("symbol", "Token symbol")
    .addParam("supply", "Token supply", "1000000000000000000000000")
    .addFlag("verify", "Verify contract on Etherscan")
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();

        console.log(
            "Deploying " + clicolor.bgGreen("simple-token") + " with the account:",
            clicolor.underline(deployer.address),
        );

        const ERC20 = await hre.ethers.getContractFactory("MockERC20");
        let TOKEN: any;

        try {
            TOKEN = await ERC20.connect(deployer).deploy(
                argsTask.name,
                argsTask.symbol,
                argsTask.supply,
            );
        } catch (e: any) {
            if (e.code == "INSUFFICIENT_FUNDS") {
                console.log(
                    "Account " +
                    clicolor.red(deployer.address) +
                    " has insufficient funds to deploy contracts",
                );
            }
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

task("deploy-multipool-router", "Deploy ETF router")
    .addFlag("verify", "Verify contract on Etherscan")
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();

        console.log(
            "Deploying " + clicolor.bgGreen("etf") + " with the account:",
            clicolor.underline(deployer.address),
        );

        const ETF = await hre.ethers.getContractFactory("MultipoolRouter");
        let ETFContract: any;

        try {
            ETFContract = await ETF.connect(deployer).deploy();
        } catch (e: any) {
            if (e.code == "INSUFFICIENT_FUNDS") {
                console.log(
                    "Account " +
                    clicolor.red(deployer.address) +
                    " has insufficient funds to deploy contracts",
                );
            }
            console.log(e);
            process.exit(1);
        }

        console.log("ROUTER deployed to:", clicolor.bgGreen(ETFContract.address));

        if (argsTask.verify) {
            await awaitBytecode(ETFContract.address, hre);
            try {
                await hre.run("verify:verify", {
                    address: ETFContract.address,
                    network: hre.hardhatArguments.network,
                    constructorArguments: [],
                });
            } catch (e: any) {
                if (e.message.includes("Already Verified")) {
                    console.info(clicolor.yellow("Already Verified"));
                } else {
                    console.error("ETF:", e);
                }
            }
        }
        return ETFContract;
    });

task("deploy-multipool", "Deploy ETF with standart parameters")
    .addParam("name", "ETF name")
    .addParam("symbol", "ETF symbol")
    .addFlag("verify", "Verify contract on Etherscan")
    .setAction(async (argsTask, hre) => {
        const [deployer] = await hre.ethers.getSigners();

        console.log(
            "Deploying " + clicolor.bgGreen("etf") + " with the account:",
            clicolor.underline(deployer.address),
        );

        const ETF = await hre.ethers.getContractFactory("Multipool");
        let ETFContract: any;

        try {
            ETFContract = await ETF.connect(deployer).deploy(
                argsTask.name,
                argsTask.symbol,
            );
        } catch (e: any) {
            if (e.code == "INSUFFICIENT_FUNDS") {
                console.log(
                    "Account " +
                    clicolor.red(deployer.address) +
                    " has insufficient funds to deploy contracts",
                );
            }
            console.log(e);
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
        return ETFContract;
    });

task("mint", "Deploy all contracts")
    .addParam("address", "token address")
    .addParam<BigNumber>("amount", "mint amount")
    .setAction(async (taskArgs: any, hre: any) => {
        mainLine();
        const token = await hre.ethers.getContractAt(
            "MockERC20",
            taskArgs.address,
        );
        await hre.run("verify:verify", {
            address: token.address,
            network: hre.hardhatArguments.network,
            constructorArguments: [
                "bitcoin",
                "btc",
                "1000000000000000000000000",
            ],
        });
    });
