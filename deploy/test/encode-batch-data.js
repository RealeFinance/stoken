const { ethers } = require("hardhat");

async function main() {
  // =========================
  // 基础配置
  // =========================
  const proxyAddress = "0x907C00D587DaFf16D028fE1e131d6DD3c6BF2F4B";
  const timelockAddress = "0xF5a9D5E4Efe9BC0c91904CE8C3d14e653C596699";

  const minDelay = 60 * 60 * 48; // 48 小时

  const hre = require("hardhat");
  const { name: networkName } = hre.network;
  const [deployer] = await hre.ethers.getSigners();

  console.log(`正在生成网络: ${networkName}`);
  console.log(`当前签名者: ${deployer.address}`);

  // =========================
  // 目标合约接口
  // =========================
  const stokenInterface = new ethers.Interface([
    "function setAssetSender(address newSender)",
    "function setAssetRecipient(address newRecipient)",
    "function setServiceFeeRecipient(address newRecipient)",
    "function grantRole(bytes32 role, address account)",
    "function revokeRole(bytes32 role, address account)",
  ]);

  const timelock = await ethers.getContractAt(
    "TimelockController",
    timelockAddress,
  );

  // =========================
  // 1. 编码需要批量执行的方法
  // =========================

  const setAssetSenderData = stokenInterface.encodeFunctionData(
    "setAssetSender",
    ["0x39132F7Ee82656edd806d3980edb5Ef114568A25"],
  );

  const setAssetRecipientData = stokenInterface.encodeFunctionData(
    "setAssetRecipient",
    ["0x39132F7Ee82656edd806d3980edb5Ef114568A25"],
  );

  const setServiceFeeRecipientData = stokenInterface.encodeFunctionData(
    "setServiceFeeRecipient",
    ["0x39132F7Ee82656edd806d3980edb5Ef114568A25"],
  );

  const grantRoleData = stokenInterface.encodeFunctionData("grantRole", [
    ethers.id("STOKEN_ADMIN"),
    "0x9Ac1862C0D5C1bf821cc6926EB2044D2b4D10b17",
  ]);

  const revokeRoleData = stokenInterface.encodeFunctionData("revokeRole", [
    ethers.id("STOKEN_ADMIN"),
    "0x3b08abFC03C85c6D856Fa6Fcbdd1944461b0718F",
  ]);

  // =========================
  // 2. 构造 Batch 参数
  // =========================

  // 每一个方法对应一个 target
  const targets = [
    proxyAddress,
    proxyAddress,
    proxyAddress,
    proxyAddress,
    proxyAddress,
  ];

  // 每一个调用附带的原生币数量
  const values = [0, 0, 0, 0, 0];

  // 每一个调用的方法 data
  const payloads = [
    setAssetSenderData,
    setAssetRecipientData,
    setServiceFeeRecipientData,
    grantRoleData,
    revokeRoleData,
  ];

  if (targets.length !== values.length || targets.length !== payloads.length) {
    throw new Error("targets、values、payloads 三个数组长度必须一致");
  }

  // 无前置依赖
  const predecessor = ethers.ZeroHash;

  /*
   * 不建议一直使用 ZeroHash。
   *
   * 使用唯一 salt，可以避免相同操作无法再次 schedule。
   * 注意：schedule、execute、hashOperationBatch 必须使用完全相同的 salt。
   */
  const salt = ethers.id(`SAmMMF-batch-${Date.now()}`);

  // =========================
  // 3. 计算批量 Operation ID
  // =========================

  const operationId = await timelock.hashOperationBatch(
    targets,
    values,
    payloads,
    predecessor,
    salt,
  );

  // =========================
  // 4. 编码 scheduleBatch
  // =========================

  const scheduleBatchData = timelock.interface.encodeFunctionData(
    "scheduleBatch",
    [targets, values, payloads, predecessor, salt, minDelay],
  );

  // =========================
  // 5. 编码 executeBatch
  // =========================

  const executeBatchData = timelock.interface.encodeFunctionData(
    "executeBatch",
    [targets, values, payloads, predecessor, salt],
  );

  // =========================
  // 6. 编码 cancel
  // =========================

  const cancelData = timelock.interface.encodeFunctionData("cancel", [
    operationId,
  ]);

  // =========================
  // 输出给 Gnosis Safe
  // =========================

  console.log("");
  console.log("========================================");
  console.log("批量操作基本信息");
  console.log("========================================");
  console.log("Operation ID:         ", operationId);
  console.log("Salt:                 ", salt);
  console.log("Predecessor:          ", predecessor);
  console.log("Min Delay:            ", minDelay);
  console.log("Call Count:           ", payloads.length);

  console.log("");
  console.log("========================================");
  console.log("第一笔多签：Schedule Batch");
  console.log("========================================");
  console.log("To:                   ", timelockAddress);
  console.log("Value:                ", 0);
  console.log("Data:                 ", scheduleBatchData);

  console.log("");
  console.log("========================================");
  console.log("第二笔多签：Execute Batch");
  console.log("48 小时后执行");
  console.log("========================================");
  console.log("To:                   ", timelockAddress);
  console.log("Value:                ", 0);
  console.log("Data:                 ", executeBatchData);

  console.log("");
  console.log("========================================");
  console.log("取消操作：Cancel");
  console.log("========================================");
  console.log("To:                   ", timelockAddress);
  console.log("Value:                ", 0);
  console.log("Data:                 ", cancelData);

  console.log("");
  console.log("========================================");
  console.log("批量调用明细");
  console.log("========================================");

  payloads.forEach((payload, index) => {
    console.log(`调用 ${index + 1}:`);
    console.log("Target:               ", targets[index]);
    console.log("Value:                ", values[index]);
    console.log("Payload:              ", payload);
    console.log("");
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run ./deploy/test/encode-batch-data.js --network bscTestnet
