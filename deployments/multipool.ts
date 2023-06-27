import { BigNumber } from "ethers";
import { ethers, run } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log(
        "Deploying the contracts with the account:",
        deployer.address
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Contract = await ethers.getContractFactory("Multipool", deployer);
    const tokens = [
        '0x4d53C85b41EdF002A12eBdE2326aa92c8987f9E7',
        '0xa5f517C964A010d8DE72420398a764F572B80f58',
        '0x421D6e19A0ec9F93a2C4A96Cbea0fE4823052Ad6',
        '0xF6432Aa7B10947dD38907BD655e2Daf68Db48647',
        '0x7b66EAd5b6076626Aab46610222479eFCb90E9AD'
    ];

    const contract = await Contract.deploy("AAA", "AAA");

    await contract.deployed();

    console.log("Multipool deployed to:", contract.address);

    for (const token of tokens) {
        // You may want to call some contract functions here with the tokens, e.g.:
        await contract.updateAssetPercents(token, BigNumber.from("20"));
        console.log(`Added token: ${token}`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
