const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const proxyAddress = "0x9EA9cd205783F08700d2A12C325FC4e1BF8e99a2";
  const timelockAddress = "0x70a1454cD4370D9a494c71C3F4C7CC55bC7246A4";
  const contractName = "FundYieldManualTraceV1";
  const useSafe = true; // 如果你是要在 Gnosis Safe 上执行升级，就设为 true，否则设为 false
  // 如果升级后要顺便执行 reinitializer，就打开下面两行
  const callInitializer = false;
  const initializerArgs = []; // 例如 [123, "abc"]
  const data = {
    // ===== Timelock 配置 =====
    // DEFAULT_ADMIN_ROLE 會交给 TimelockController，所有敏感操作延迟执行
    timelock: {
      enabled: true,
      minDelay: 120, // 2 分钟
      proposers: ["0x89B416C2e456b89bFDa314fb5C400BAB66D4aADb"], // 可发起提案的地址
      executors: ["0x0000000000000000000000000000000000000000"], // 放空则延迟到后任何人可执行
      cancellers: ["0x89B416C2e456b89bFDa314fb5C400BAB66D4aADb"], // 可取消待执行提案的地址
    },
  };

  const hre = require("hardhat");
  const { name: networkName } = hre.network;
  const [deployer] = await hre.ethers.getSigners();
  const deployerAddress = deployer.address;
  console.log(`正在部署到网络: ${networkName}`);
  console.log(`部署者地址: ${deployerAddress}`);

  // // ===== 1) 获取新实现合约工厂 =====
  const NewImplFactory = await ethers.getContractFactory(contractName);

  // // ===== 2) 校验升级安全性 =====
  // await upgrades.validateUpgrade(proxyAddress, NewImplFactory, {
  //   kind: "uups",
  // });
  // // ===== 3) 仅部署新的 implementation，不执行升级 =====
  // const newImplementationAddress = await upgrades.prepareUpgrade(
  //   proxyAddress,
  //   NewImplFactory,
  //   {
  //     kind: "uups",
  //   },
  // );
  // console.log("New implementation deployed:", newImplementationAddress);

  const newImplementationAddress = "0x19AaE71c223Ca591448Fb0e0b97e2D53C1dbB405";

  const proxyAsUUPS = await ethers.getContractAt(
    [
      "function upgradeToAndCall(address newImplementation, bytes data) external payable",
    ],
    proxyAddress,
  );

  let upgradeCallData;
  if (callInitializer) {
    // 假设你的 V2 里有：
    // function initializeV2(uint256 x, string memory y) reinitializer(2)
    const implInterface = NewImplFactory.interface;
    const initData = implInterface.encodeFunctionData(
      "initializeV2",
      initializerArgs,
    );

    upgradeCallData = proxyAsUUPS.interface.encodeFunctionData(
      "upgradeToAndCall",
      [newImplementationAddress, initData],
    );
  } else {
    upgradeCallData = proxyAsUUPS.interface.encodeFunctionData(
      "upgradeToAndCall",
      [newImplementationAddress, "0x"],
    );
  }

  const timelock = await ethers.getContractAt(
    "TimelockController",
    timelockAddress,
  );

  const cancelData = timelock.interface.encodeFunctionData(
    "cancel",
    ["0x3172fc05fc1de7cd465b46402980628ab944c3f60cbadac923f11ac9978f0eab"], // 新的费率值
  );

  // ② 再编码 timelock.schedule() 调用
  const scheduleData = timelock.interface.encodeFunctionData("schedule", [
    proxyAddress, // target
    0, // value（不带 ETH）
    upgradeCallData, // data → 实际要调用的方法
    ethers.ZeroHash, // predecessor（无前置操作）
    ethers.ZeroHash, // salt（随机数，避免重复）
    120,
  ]);

  const executeData = timelock.interface.encodeFunctionData("execute", [
    proxyAddress, // target
    0, // value（不带 ETH）
    upgradeCallData, // data → 实际要调用的方法
    ethers.ZeroHash, // predecessor（无前置操作）
    ethers.ZeroHash, // salt（随机数，避免重复）
  ]);

  console.log("多签需要执行的交易:");
  console.log("To:                  ", timelockAddress);
  console.log("Value:               ", 0);
  console.log("Schedule Data:       ", scheduleData);
  console.log("");
  console.log("Execute Data:        ", executeData);
  console.log("");
  console.log("Cancel Data:         ", cancelData);
  console.log("Upgrade Call Data:   ", upgradeCallData);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run .\deploy\test\encode-data-update.js --network bscTestnet
