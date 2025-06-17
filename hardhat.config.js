// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-chai-matchers");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  // 网络配置
  networks: {
    hardhat: {
      // 本地开发网络配置
      chainId: 31337,
      // 可添加fork配置
      // forking: {
      //   url: "https://eth-mainnet.alchemyapi.io/v2/your-api-key",
      // },
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY_1],
      chainId: 1,
      gasPrice: "auto",
      gasMultiplier: 1.2,
    },
    "hashkey-chain-testnet": {
      url: "https://hashkeychain-testnet.alt.technology",
    },
    // 可添加更多网络配置
    testnet: {
      url: "https://testnet.hsk.xyz",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 133,
      gasPrice: "auto",
    },
  },
  // Etherscan验证配置
  etherscan: {
    // apiKey: {
    //   mainnet: process.env.ETHERSCAN_API_KEY,
    //   testnet: process.env.ETHERSCAN_API_KEY,
    //   "hashkey-chain-testnet": "empty",
    //   // 其他网络API密钥
    // },
    apiKey: {
      testnet: "empty",
      "hashkey-chain-testnet": "empty",
    },
    // 自定义网络配置
    customChains: [
      {
        network: "testnet",
        chainId: 133,
        urls: {
          apiUrl:
            "https://hashkeychain-testnet-explorer.alt.technology/api/v1/graphql",
          browserUrl: "https://hashkeychain-testnet-explorer.alt.technology/",
        },
      },
      {
        network: "hashkey-chain-testnet",
        chainId: 133,
        urls: {
          apiURL: "https://testnet-explorer.hsk.xyz/api",
          browserURL: "https://testnet-explorer.hsk.xyz",
        },
      },
    ],
  },

  // 测试配置
  mocha: {
    timeout: 100000, // 测试超时时间
  },

  // 路径配置
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};
