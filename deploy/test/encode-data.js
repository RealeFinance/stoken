const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const proxyAddress = "0x9EA9cd205783F08700d2A12C325FC4e1BF8e99a2";
  const timelockAddress = "0x70a1454cD4370D9a494c71C3F4C7CC55bC7246A4";
  const contractName = "FundYieldManualTraceV1";
  const useSafe = true; // 如果你是要在 Gnosis Safe 上执行升级，就设为 true，否则设为 false
  // 如果升级后要顺便执行 reinitializer，就打开下面两行
  const callInitializer = true;
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

  // 假设你有 SToken 和 Timelock 的 interface
  const stokenInterface = new ethers.Interface([
    "function setTechnicalServiceFeeRate(uint256 newRate)",
    "function setAssetSender(address newSender)",
    "function grantRole(bytes32 role, address account)",
    "function revokeRole(bytes32 role, address account)",
  ]);
  const timelock = await ethers.getContractAt(
    "TimelockController",
    timelockAddress,
  );

  // ① 先把实际要调用的 SToken 方法编码
  const setAssetSenderData = stokenInterface.encodeFunctionData(
    "setAssetSender",
    [proxyAddress], // 新的发送者地址
  );

  const grantRoleData = stokenInterface.encodeFunctionData(
    "grantRole",
    [ethers.ZeroHash, proxyAddress], // 新的管理员角色
  );

  const revokeRoleData = stokenInterface.encodeFunctionData(
    "revokeRole",
    [ethers.ZeroHash, proxyAddress], // 新的管理员角色
  );

  const cancelData = timelock.interface.encodeFunctionData(
    "cancel",
    ["0xefcbbb1bfc8e07775e534622dcf681d9cfab5f418b0b666d2faede52d0d587c7"], // 新的费率值
  );

  // ② 再编码 timelock.schedule() 调用
  const scheduleData = timelock.interface.encodeFunctionData("schedule", [
    proxyAddress, // target
    0, // value（不带 ETH）
    revokeRoleData, // data → 实际要调用的方法
    ethers.ZeroHash, // predecessor（无前置操作）
    ethers.ZeroHash, // salt（随机数，避免重复）
    120,
  ]);

  const executeData = timelock.interface.encodeFunctionData("execute", [
    proxyAddress, // target
    0, // value（不带 ETH）
    revokeRoleData, // data → 实际要调用的方法
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
  console.log("Grant Role Data:     ", revokeRoleData);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run .\deploy\test\encode-data.js --network bscTestnet
