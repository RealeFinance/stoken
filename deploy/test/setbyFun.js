const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const contractName = "SAmMMF";
  const proxyAddress = "0x37d03D8caBfB617e455D0cAA0Cf1cdc5b8F3BDEe";
  const name = "YIELDPlus";
  const symbol = "YIELD+";
  const data = {
    STOKEN_ADMIN: ["0x7757c491144a6cB8e957f2f7650242a19F448b2c"],
    assetRecipient: "0xf5dE29C08CEbFE490c05Eb0C560Cd47bEC03b6d3",
    assetSender: "0xf5dE29C08CEbFE490c05Eb0C560Cd47bEC03b6d3",
    serviceFeeRecipient: "0xf5dE29C08CEbFE490c05Eb0C560Cd47bEC03b6d3",
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

  const proxy2 = await ethers.getContractAt(contractName, proxyAddress);

  console.log(`开始设置权限...`);
  for (const admin of data.STOKEN_ADMIN ?? []) {
    console.log(`正在授权 STOKEN_ADMIN: ${admin}`);
    const tx = await proxy2.grantRole(ethers.id("STOKEN_ADMIN"), admin);
    await tx.wait();
    console.log(`STOKEN_ADMIN权限已授予: ${admin}`);
  }

  const deployerAddress = await deployer.getAddress();

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
    `支持的交易代币地址已设置: ${(data.supportedTokenAddresses ?? []).join(", ")}`,
  );
}

main().catch(console.error);

// npx hardhat run .\deploy\test\set.js --network hardhat
