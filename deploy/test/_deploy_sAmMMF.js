const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const contractName = "SToken";
  const name = "CnCashPlus";
  const symbol = "CNCASH+";
  const data = {
    STOKEN_ADMIN: ["0xb900937Af55EEcE6835646ad515A0517AC094af1"],
    assetRecipient: "0xc859e52B13Bd8B78FA47972aBc671E240f1A432a",
    assetSender: "0xc859e52B13Bd8B78FA47972aBc671E240f1A432a",
    serviceFeeRecipient: "0xc859e52B13Bd8B78FA47972aBc671E240f1A432a",
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

  const Contract = await ethers.getContractFactory(contractName);
  const proxy2 = await upgrades.deployProxy(Contract, [name, symbol], {
    initializer: "initialize",
    gasLimit: 15000000,
    gasPrice: ethers.parseUnits("0.3", "gwei"),
  });
  await proxy2.waitForDeployment();

  // 获取代理合约实例
  // const proxy2 = await ethers.getContractAt(
  //   contractName,
  //   "0x286D9F099587f567EcE2b70eBB64B94ACD672d76",
  // );

  const tokenAddress = await proxy2.getAddress();
  console.log(`${contractName} Token 地址:`, tokenAddress);

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

// npx hardhat run deploy/test/_deploy_sAmMMF.js --network bscTestnet
