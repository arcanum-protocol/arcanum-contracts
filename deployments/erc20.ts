import { ethers, run } from "hardhat";

async function main() {
  await run("compile");

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  const MockERC20 = await ethers.getContractFactory("MockERC20");
  
  // Set your own values for name, symbol, and initial supply
  const name = "token name";
  const symbol = "tkn";
  const initialSupply = ethers.utils.parseEther("1000");

  const mockERC20 = await MockERC20.deploy(name, symbol, initialSupply);
  console.log(`${name}: ${mockERC20.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
