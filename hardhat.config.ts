import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat/config";
import "hardhat-abi-exporter";
import "./deployments/etf";

import { HardhatUserConfig } from "hardhat/types";

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.5.16",
            },
            {
                version: "0.8.19",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1000,
                    },
                },
            },
        ],
    },
    networks: {
        ropsten: {
            url: process.env.ROPSTEN_URL || "",
            gasPrice: 10000000,
            accounts:
                process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        goerli: {
            url: process.env.GOERLI_URL || "",
            gasPrice: 1,
            accounts:
                process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        sepolia: {
            url: process.env.SEPOLIA_URL || "",
            accounts:
                process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        mumbai: {
            url: process.env.MUMBAI_URL || "",
            accounts:
                process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
        ganache: {
            url: "http://127.0.0.1:8545",
            accounts:
                process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: "USD",
    },
    etherscan: {
        apiKey: {
            ropsten:
                process.env.MUMBAI_SCAN_API_KEY !== undefined
                    ? process.env.MUMBAI_SCAN_API_KEY
                    : "",
            polygonMumbai:
                process.env.MUMBAI_SCAN_API_KEY !== undefined
                    ? process.env.MUMBAI_SCAN_API_KEY
                    : "",
        },
    },
    paths: {
        tests: "tests"
    }
};

export default config;
