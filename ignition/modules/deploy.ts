import { ethers, hardhatArguments } from "hardhat";
import * as Config from "../config";

async function main() {
  await Config.initConfig();
  const network = hardhatArguments.network ? hardhatArguments.network : "dev";
  const [deployer] = await ethers.getSigners();
  console.log("Deploy from address:", deployer.address);

  const NauhToken = await ethers.getContractFactory("NauhToken");
  const nauhToken = await NauhToken.deploy();
  await nauhToken.waitForDeployment();
  console.log(`✅ NauhToken deployed at: ${nauhToken.target}`);
  Config.setConfig(network + ".NauhToken", await nauhToken.getAddress());

  const RewardManager = await ethers.getContractFactory("RewardManager");
  const rewardManager = await RewardManager.deploy(
    nauhToken.target,
    100,
    86400
  );
  await rewardManager.waitForDeployment();
  console.log(`✅ RewardManager deployed at: ${rewardManager.target}`);
  Config.setConfig(
    network + ".RewardManager",
    await rewardManager.getAddress()
  );

  const TokenVault = await ethers.getContractFactory("TokenVault");
  const tokenVault = await TokenVault.deploy(
    nauhToken.target,
    rewardManager.target
  );
  await tokenVault.waitForDeployment();
  console.log(`✅ TokenVault deployed at: ${tokenVault.target}`);
  Config.setConfig(network + ".TokenVault", await tokenVault.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
