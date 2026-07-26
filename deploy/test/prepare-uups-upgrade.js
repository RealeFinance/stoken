const { ethers, upgrades } = require("hardhat");
const { NonceManager } = require("ethers");

async function main() {
  // ===== 你要改的参数 =====
  const proxyAddress = "0x0D90a6eE85d5668734bb3A515147f53EBDfE866c";
  const contractName = "PlusFund";
  const useSafe = false; // 如果你是要在 Gnosis Safe 上执行升级，就设为 true，否则设为 false
  // 如果升级后要顺便执行 reinitializer，就打开下面两行
  const callInitializer = false;
  const initializerArgs = []; // 例如 [123, "abc"]
  const data = {
    // ===== Timelock 配置 =====
    // DEFAULT_ADMIN_ROLE 會交给 TimelockController，所有敏感操作延迟执行
    timelock: {
      enabled: true,
      minDelay: 60 * 60 * 48, // 48 小时
      proposers: ["0x0589EbFa4A6A1d457AB9f4280DF8079806bA46ae"], // 可发起提案的地址
      executors: ["0x0000000000000000000000000000000000000000"], // 放空则延迟到后任何人可执行
      cancellers: ["0x0589EbFa4A6A1d457AB9f4280DF8079806bA46ae"], // 可取消待执行提案的地址
    },
  };

  const hre = require("hardhat");
  const { name: networkName } = hre.network;
  const [rawDeployer] = await hre.ethers.getSigners();
  // Avalanche public RPC may briefly return a stale pending nonce after a tx is sent.
  // Keep one local nonce sequence for the upgrade and all follow-up transactions.
  const deployer = new NonceManager(rawDeployer);
  const deployerAddress = await deployer.getAddress();
  console.log(`正在部署到网络: ${networkName}`);
  console.log(`部署者地址: ${deployerAddress}`);

  // ===== 1) 获取新实现合约工厂 =====
  const NewImplFactory = await ethers.getContractFactory(contractName, deployer);

  // ===== 2) 注册已有代理 =====
  // try {
  //   await upgrades.forceImport(proxyAddress, NewImplFactory, { kind: "uups" });
  // } catch (e) {
  //   console.log("Proxy already registered");
  // }

  // ===== 3) 校验升级安全性 =====
  await upgrades.validateUpgrade(proxyAddress, NewImplFactory, {
    kind: "uups",
  });

  if (!useSafe) {
    // ===== 4) 直接在当前网络执行升级 =====
    const upgradeOptions = {
      kind: "uups",
    };
    if (callInitializer) {
      upgradeOptions.call = { fn: "initializeV2", args: initializerArgs };
    }
    const proxy = (await upgrades.upgradeProxy(
      proxyAddress,
      NewImplFactory,
      upgradeOptions,
    )).connect(deployer);
    await proxy.waitForDeployment();
    const deploymentTx = proxy.deploymentTransaction();
    const blockNumber = deploymentTx?.blockNumber;
    const tokenAddress = await proxy.getAddress();
    console.log(`${contractName} Token 地址:`, tokenAddress);
    // console.log(`initializeV2 已执行，如果需要请手动调用`);
    // ===== 部署 TimelockController =====
    if (data.timelock?.enabled) {
      console.log(`正在部署 TimelockController...`);
      const TimelockController = await ethers.getContractFactory(
        "TimelockController",
        deployer,
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
      const hasRole = await proxy.hasRole(ethers.ZeroHash, timelockAddress);
      console.log(`Timelock has DEFAULT_ADMIN_ROLE: ${hasRole}`);
      if (!hasRole) {
        throw new Error("授予 Timelock DEFAULT_ADMIN_ROLE 失败");
      }
      console.log(`DEFAULT_ADMIN_ROLE 已授予给 Timelock`);

      // 放弃 deployer 在 Timelock 中的 admin 身份
      const txRenounceTimelock = await timelock.renounceRole(
        ethers.ZeroHash,
        deployerAddress,
      );
      await txRenounceTimelock.wait();
      console.log(`Timelock admin 已放弃`);

      console.log(`TimelockController 配置完成`);

      await proxy.setMinSubscriptionAmount(10000);
      console.log(`设置最小认购金额为: 10000`);
      await proxy.setMinRedemptionAmount(ethers.parseEther("924.676"));
      console.log(`设置最小赎回金额为: 924.676`);
      await proxy.renounceRole(
        ethers.id("STOKEN_BLACKLIST_ADMIN_ROLE"),
        deployerAddress,
      );
      console.log(`已放弃 STOKEN_BLACKLIST_ADMIN_ROLE 权限`);

      await proxy.renounceRole(ethers.id("UPGRADER_ROLE"), deployerAddress);
      console.log(`已放弃 UPGRADER_ROLE 权限`);

      await proxy.renounceRole(ethers.id("STOKEN_ADMIN"), deployerAddress);
      console.log(`已放弃 STOKEN_ADMIN 权限`);

      await proxy.renounceRole(
        await proxy.DEFAULT_ADMIN_ROLE(),
        deployerAddress,
      );
      console.log(`已放弃 DEFAULT_ADMIN_ROLE 权限`);
    }
  } else {
    // ===== 4) 仅部署新的 implementation，不执行升级 =====
    try {
      await hre.upgrades.forceImport(proxyAddress, NewImplFactory, {
        kind: "uups",
      });
    } catch (e) {
      console.log("Proxy already registered");
    }
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
