const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const proxyAddress = "0x9EA9cd205783F08700d2A12C325FC4e1BF8e99a2";
  const contractName = "FundYieldManualTraceV1";
  const useSafe = false; // 如果你是要在 Gnosis Safe 上执行升级，就设为 true，否则设为 false
  // 如果升级后要顺便执行 reinitializer，就打开下面两行
  const callInitializer = true;
  const initializerArgs = []; // 例如 [123, "abc"]
  const data = {
    // ===== Timelock 配置 =====
    // DEFAULT_ADMIN_ROLE 會交给 TimelockController，所有敏感操作延迟执行
    timelock: {
      enabled: true,
      minDelay: 900, // 15 分钟
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

  // ===== 1) 获取新实现合约工厂 =====
  const NewImplFactory = await ethers.getContractFactory(contractName);

  // ===== 2) 校验升级安全性 =====
  await upgrades.validateUpgrade(proxyAddress, NewImplFactory, {
    kind: "uups",
  });

  if (!useSafe) {
    // ===== 3) 直接在当前网络执行升级 =====
    const proxy = await upgrades.upgradeProxy(proxyAddress, NewImplFactory, {
      kind: "uups",
      call: { fn: "initializeV2", args: [] },
    });
    await proxy.waitForDeployment();
    const deploymentTx = proxy.deploymentTransaction();
    const blockNumber = deploymentTx?.blockNumber;
    const tokenAddress = await proxy.getAddress();
    console.log(`${contractName} Token 地址:`, tokenAddress);
    console.log(`initializeV2 已执行，maxQueueLength = 100`);
    // ===== 部署 TimelockController =====
    if (data.timelock?.enabled) {
      console.log(`正在部署 TimelockController...`);
      const TimelockController = await ethers.getContractFactory(
        "TimelockController",
      );
      const timelock = await TimelockController.deploy(
        data.timelock.minDelay,
        data.timelock.proposers,
        data.timelock.executors,
        deployerAddress, // 暂时设 deployer 为 admin，配置完成后再放弃
      );
      await timelock.waitForDeployment();
      const timelockAddress = await timelock.getAddress();
      console.log(`TimelockController 地址: ${timelockAddress}`);

      // 将 DEFAULT_ADMIN_ROLE 交给 TimelockController
      console.log(`正在授予 DEFAULT_ADMIN_ROLE 给 Timelock...`);
      const txGrant = await proxy.grantRole(ethers.ZeroHash, timelockAddress);
      await txGrant.wait();
      console.log(`DEFAULT_ADMIN_ROLE 已授予给 Timelock`);

      // 放弃 deployer 在 Timelock 中的 admin 身份
      const txRenounceTimelock = await timelock.renounceRole(
        ethers.ZeroHash,
        deployerAddress,
      );
      await txRenounceTimelock.wait();
      console.log(`Timelock admin 已放弃`);

      console.log(`TimelockController 配置完成`);
    }
  } else {
    // ===== 3) 仅部署新的 implementation，不执行升级 =====
    const newImplementationAddress = await upgrades.prepareUpgrade(
      proxyAddress,
      NewImplFactory,
      {
        kind: "uups",
      },
    );

    console.log("New implementation deployed:", newImplementationAddress);
    console.log("请在 Gnosis Safe 上执行升级，下面会输出要提交的交易数据...");
    // ===== 4) 构造多签要执行的 calldata =====

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

    console.log("\n=== Submit this transaction in Safe ===");
    console.log("to:", proxyAddress);
    console.log("value:", "0");
    console.log("data:", upgradeCallData);

    // 也可以顺便打印更适合复制的 JSON
    const payload = {
      to: proxyAddress,
      value: "0",
      data: upgradeCallData,
      newImplementationAddress,
    };

    console.log("\nSafe payload JSON:");
    console.log(JSON.stringify(payload, null, 2));
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run .\deploy\test\prepare-uups-upgrade.js --network bscTestnet
