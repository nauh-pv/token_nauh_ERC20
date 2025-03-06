import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require("dotenv").config();
const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    bsctest: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: [process.env.PRIVATE_KEY as string],
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: [process.env.PRIVATE_KEY as string],
    },
    zenc_testnet: {
      url: "https://zenchain-testnet.api.onfinality.io/public",
      chainId: 8408,
      accounts: [process.env.PRIVATE_KEY1 as string],
      gas: 5000000,
      gasPrice: 5000000000,
    },
  },
  etherscan: {
    apiKey: process.env.BSC_API_KEY,
  },
};

export default config;
