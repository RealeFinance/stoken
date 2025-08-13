// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-chai-matchers");
require("dotenv").config();

// task("compile")
//   .addFlag(
//     "printstandardjson",
//     "Print the standard JSON input used for compilation"
//   )
//   .setAction(async (taskArgs, hre) => {
//     // 注册编译前的钩子
//     hre.events.on("beforeCompile", (args) => {
//       if (taskArgs.printStandardJson) {
//         console.log("Standard JSON Input:");
//         console.log(JSON.stringify(args.input, null, 2));
//       }
//     });

//     // 执行编译
//     await hre.run("compile");
//   });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
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
      timeout: 2000000,
    },
    BNBtestnet: {
      url: "https://bsc-testnet.drpc.org/",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 97,
      gasPrice: "auto",
      timeout: 2000000,
    },
  },
  // Etherscan验证配置
  etherscan: {
    // apiKey: {
    //   mainnet: process.env.ETHERSCAN_API_KEY,
    //   testnet: process.env.ETHERSCAN_API_KEY,
    //   "hashkey-chain-testnet": "empty",
    //   // 其他网络API密钥
    //   BNBtestnet: process.env.ETHERSCAN_API_KEY,
    // },
    apiKey: {
      testnet: "empty",
      "hashkey-chain-testnet": "empty",
      // BNBtestnet: "NTY643JIUYT5WTX1DBGXEDJKRWMFNJ8Q42",
      bscTestnet: "TJKUQ1AFRIVXV4ZCMBEQ1G95BW9A6SMEEA",
      // bscTestnet: "1",
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
        {
          network: "BNBtestnet",
          chainId: 97,
          urls: {
            apiUrl: "https://api.etherscan.io/v2/api?chainid=97",
            browserUrl: "https://testnet.bscscan.com",
          },
        },
      ],
    },
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
