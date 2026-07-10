const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const contractName = "FundYieldManualTraceV1";
  const PRODUCT_NAME = "GtCashPlus_ETH";
  const name = "HtCashPlus";
  const symbol = "HTCASH+";
  const timelockDelay = 172800; // 2 天（秒）
  const data = {
    // ===== Timelock 配置 =====
    // DEFAULT_ADMIN_ROLE 會交给 TimelockController，所有敏感操作延迟执行
    timelock: {
      enabled: true,
      minDelay: timelockDelay, // 2 天（秒）
      proposers: ["0x0589EbFa4A6A1d457AB9f4280DF8079806bA46ae"], // 可发起提案的地址
      executors: ["0x0000000000000000000000000000000000000000"], // 放空则延迟到后任何人可执行
      cancellers: ["0x0589EbFa4A6A1d457AB9f4280DF8079806bA46ae"], // 可取消待执行提案的地址
    },
    // ===== 角色分配 =====
    STOKEN_ADMIN: ["0xb66DE9dd40b569E39B9866f0185f0292bC5dfe46"], // 日常运维地址（无延迟）
    // ===== 资产地址 =====
    assetRecipient: "0x5f6c3454e282d12E142b7559289421C5E5d90E72",
    assetSender: "0x5f6c3454e282d12E142b7559289421C5E5d90E72",
    serviceFeeRecipient: "0x5f6c3454e282d12E142b7559289421C5E5d90E72",
    // ===== 支持代币 =====
    supportedTokenAddresses: [
      "0xdac17f958d2ee523a2206206994597c13d831ec7",
      "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    ],
  };
  // =======================

  const hre = require("hardhat");
  const { name: networkName } = hre.network;
  const [deployer] = await hre.ethers.getSigners();
  console.log(`正在部署到网络: ${networkName}`);
  console.log(`部署者地址: ${deployer.address}`);
  const deployerAddress = deployer.address;

  const Contract = await ethers.getContractFactory(contractName);
  const proxy2 = await upgrades.deployProxy(Contract, [name, symbol], {
    initializer: "initialize",
    gasLimit: 15000000,
  });
  await proxy2.waitForDeployment();
  const deploymentTx = proxy2.deploymentTransaction();
  const blockNumber = deploymentTx?.blockNumber;

  // 获取代理合约实例
  // const proxy2 = await ethers.getContractAt(
  //   contractName,
  //   "0x50bDAFf4bCeB852F006F657f47C68fCC417f7bEb",
  // );

  const tokenAddress = await proxy2.getAddress();
  console.log(`${contractName} Token 地址:`, tokenAddress);

  console.log(`开始设置权限...`);
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
    const txGrant = await proxy2.grantRole(ethers.ZeroHash, timelockAddress);
    await txGrant.wait();
    console.log(`DEFAULT_ADMIN_ROLE 已授予给 Timelock`);

    // 构造函数已经设置了 PROPOSER 和 EXECUTOR，这里只需要单独配置 CANCELLER
    const CANCELLER_ROLE = await timelock.CANCELLER_ROLE();
    for (const addr of data.timelock.cancellers ?? []) {
      const tx = await timelock.grantRole(CANCELLER_ROLE, addr);
      await tx.wait();
      console.log(`CANCELLER_ROLE 已授予: ${addr}`);
    }

    // 放弃 deployer 在 Timelock 中的 admin 身份
    const txRenounceTimelock = await timelock.renounceRole(
      ethers.ZeroHash,
      deployerAddress,
    );
    await txRenounceTimelock.wait();
    console.log(`Timelock admin 已放弃`);

    console.log(`TimelockController 配置完成`);
  } else {
    // 不用 timelock，直接授予 DEFAULT_ADMIN_ROLE 给指定地址
    for (const admin of data.DEFAULT_ADMIN_ROLE ?? []) {
      console.log(`正在授权 DEFAULT_ADMIN_ROLE: ${admin}`);
      const tx = await proxy2.grantRole(ethers.ZeroHash, admin);
      await tx.wait();
      console.log(`DEFAULT_ADMIN_ROLE权限已授予: ${admin}`);
    }
  }
  for (const admin of data.STOKEN_ADMIN ?? []) {
    console.log(`正在授权 STOKEN_ADMIN: ${admin}`);
    const tx = await proxy2.grantRole(ethers.id("STOKEN_ADMIN"), admin);
    await tx.wait();
    console.log(`STOKEN_ADMIN权限已授予: ${admin}`);
  }

  const tx = await proxy2.grantRole(ethers.id("STOKEN_ADMIN"), deployerAddress);
  await tx.wait();
  console.log(`STOKEN_ADMIN权限已授予: ${deployerAddress}`);

  const tx1 = await proxy2.setAssetRecipient(data.assetRecipient);
  await tx1.wait();
  console.log(`资产接收地址已设置: ${data.assetRecipient}`);

  const tx2 = await proxy2.setAssetSender(data.assetSender);
  await tx2.wait();
  console.log(`资产发送地址已设置: ${data.assetSender}`);

  const tx3 = await proxy2.setServiceFeeRecipient(data.serviceFeeRecipient);
  await tx3.wait();
  console.log(`服务费接收地址已设置: ${data.serviceFeeRecipient}`);

  for (const address of data.supportedTokenAddresses ?? []) {
    console.log(`正在添加支持代币: ${address}`);
    const tx = await proxy2.addSupportedTokenAddress(address);
    await tx.wait();
    console.log(`支持代币已添加: ${address}`);
  }

  console.log(
    `支持的交易代币地址已设置: ${(data.supportedTokenAddresses ?? []).join(
      ", ",
    )}`,
  );

  // ===== 部署者退出部分权限（DEFAULT_ADMIN_ROLE 单独处理） =====
  // 先自动退出 STOKEN_ADMIN 和 STOKEN_BLACKLIST_ADMIN_ROLE
  console.log(`开始撤销部署者权限...`);
  const rolesToRenounce = [
    ethers.id("STOKEN_ADMIN"),
    ethers.id("STOKEN_BLACKLIST_ADMIN_ROLE"),
  ];
  for (const role of rolesToRenounce) {
    const hasRole = await proxy2.hasRole(role, deployerAddress);
    if (hasRole) {
      console.log(`正在退出: ${role}`);
      const tx = await proxy2.renounceRole(role, deployerAddress);
      await tx.wait();
      console.log(`已退出: ${role}`);
    } else {
      console.log(`已无此角色，跳过: ${role}`);
    }
  }
  console.log(`部署者 STOKEN_ADMIN 和 STOKEN_BLACKLIST_ADMIN_ROLE 已退出`);

  console.log(`PRODUCT_NAME=${PRODUCT_NAME}`);
  console.log(`stoken_Contract_Address=${tokenAddress}`);
  console.log(`stoken_Start_Height=${blockNumber}`);

  // ===== DEFAULT_ADMIN_ROLE 单独退出（可选执行） =====
  // 如果需要退出 DEFAULT_ADMIN_ROLE，取消下面的注释
  // 警告: 确保 Timelock 或其他人已经持有 DEFAULT_ADMIN_ROLE，否则退出后无人能管理合约！
  // const hasDefaultAdmin = await proxy2.hasRole(ethers.ZeroHash, deployerAddress);
  // if (hasDefaultAdmin) {
  //   console.log(`正在退出 DEFAULT_ADMIN_ROLE...`);
  //   const tx = await proxy2.renounceRole(ethers.ZeroHash, deployerAddress);
  //   await tx.wait();
  //   console.log(`DEFAULT_ADMIN_ROLE 已退出`);
  // }
}

main().catch(console.error);

// npx hardhat run deploy/test/_deploy_SToken.js --network bscTestnet

// ====== 多签调用timelock示例 ======

// 假设你有 SToken 和 Timelock 的 interface
// const stokenInterface = new ethers.Interface([
//   "function setAssetRecipient(address newRecipient)"
// ]);
// const timelockInterface = new ethers.Interface([
//   "function schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)",
//   "function execute(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt)"
// ]);

// // ① 先把实际要调用的 SToken 方法编码
// const setAssetRecipientData = stokenInterface.encodeFunctionData("setAssetRecipient", [
//   "0x新地址"
// ]);

// // ② 再编码 timelock.schedule() 调用
// const scheduleData = timelockInterface.encodeFunctionData("schedule", [
//   "0xSToken代理地址", // target
//   0, // value（不带 ETH）
//   setAssetRecipientData, // data → 实际要调用的方法
//   ethers.ZeroHash, // predecessor（无前置操作）
//   ethers.ZeroHash, // salt（随机数，避免重复）
//   timelockDelay, // delay（2 天）
// ]);

// console.log("多签需要执行的交易:");
// console.log("To:      ", "0xTimelock地址");
// console.log("Value:   ", 0);
// console.log("Data:    ", scheduleData);
// 把这 3 个参数填到多签钱包的"发送交易"页面
