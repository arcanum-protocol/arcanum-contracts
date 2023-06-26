import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const MultipoolRouter = await ethers.getContractFactory("MultipoolRouter");
  const multipoolRouter = await MultipoolRouter.deploy();

  console.log("MultipoolRouter contract deployed to:", multipoolRouter.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
