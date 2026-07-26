const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const proxyAddress = "0x1ec3AA07e3898f1e6d4F23b5dce1bdbecb5c1Fe1";
  const contractName = "PlusFund";

  const hre = require("hardhat");
  const { name: networkName } = hre.network;
  const [deployer] = await hre.ethers.getSigners();
  const deployerAddress = deployer.address;
  console.log(`正在部署到网络: ${networkName}`);
  console.log(`部署者地址: ${deployerAddress}`);

  // 获取token实例
  const proxy = await ethers.getContractAt(contractName, proxyAddress);
  await proxy.setMinSubscriptionAmount(10000);
  console.log(`设置最小认购金额为: 10000`);
  await proxy.setMinRedemptionAmount(ethers.parseEther("96.363"));
  console.log(`设置最小赎回金额为: 96.363`);

  // 放弃权限
  await proxy.renounceRole(
    ethers.id("STOKEN_BLACKLIST_ADMIN_ROLE"),
    deployerAddress,
  );
  console.log(`已放弃 STOKEN_BLACKLIST_ADMIN_ROLE 权限`);

  await proxy.renounceRole(ethers.id("UPGRADER_ROLE"), deployerAddress);
  console.log(`已放弃 UPGRADER_ROLE 权限`);

  await proxy.renounceRole(ethers.id("STOKEN_ADMIN"), deployerAddress);
  console.log(`已放弃 STOKEN_ADMIN 权限`);

  await proxy.renounceRole(await proxy.DEFAULT_ADMIN_ROLE(), deployerAddress);
  console.log(`已放弃 DEFAULT_ADMIN_ROLE 权限`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run .\deploy\test\set.js --network bscTestnet
