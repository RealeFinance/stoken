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
        runs: 100,
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
      // url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      url: "https://ethereum-rpc.publicnode.com",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 1,
      gasPrice: 1_000_000_000, // 1 gwei
      gasLimit: 3000000, // 代理合约部署通常需要100-300万Gas，设置冗余值
      timeout: 120000, // 主网交易确认慢，延长超时时间（2分钟）
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
    hashkeyMainnet: {
      url: "https://mainnet.hsk.xyz",
      chainId: 177,
      accounts: [process.env.PRIVATE_KEY_2],
      gasPrice: "auto",
      timeout: 2000000,
    },
    bscTestnet: {
      url: "https://bnb-testnet.api.onfinality.io/public",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 97,
      gasPrice: "auto",
      timeout: 2000000,
    },
    bsc: {
      url: "https://bsc-dataseed.bnbchain.org",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 56,
      gasPrice: "auto",
      timeout: 2000000,
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/N3C7u3FWjnZvKyop_yRKc",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 11155111,
      gasPrice: "auto",
      timeout: 2000000,
    },
    Avalanche_Fuji_Testnet: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 43113,
      gasPrice: "auto",
      timeout: 2000000,
    },
    Avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: [process.env.PRIVATE_KEY_2],
      chainId: 43114,
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
      // BNBtestnet: "NTY643JIUYT5WTX1DBGXEDJKRWMFNJ8Q42", //TJKUQ1AFRIVXV4ZCMBEQ1G95BW9A6SMEEA
      bscTestnet: "NTY643JIUYT5WTX1DBGXEDJKRWMFNJ8Q42",
      bsc: "TJKUQ1AFRIVXV4ZCMBEQ1G95BW9A6SMEEA",
      avalancheFujiTestnet: "snowtrace",
      avalanche: "Avalanche",
      // bscTestnet: "empty",
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
          network: "bscTestnet",
          chainId: 97,
          urls: {
            apiURL: "https://api.etherscan.io/v2/api?chainid=97", // BSC测试网专用API
            browserURL: "https://testnet.bscscan.com",
          },
        },
        {
          network: "Avalanche_Fuji_Testnet",
          chainId: 43113,
          urls: {
            apiURL:
              "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan",
            browserURL: "https://avalanche.testnet.localhost:8080",
          },
        },
        // {
        //   network: "Avalanche",
        //   chainId: 43114,
        //   urls: {
        //     apiURL: "https://api.snowtrace.io/api",
        //     browserURL: "https://snowtrace.io",
        //   },
        // },
        {
          network: "Avalanche",
          chainId: 43114,
          urls: {
            apiURL:
              "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
            browserURL: "https://avalanche.routescan.io",
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
