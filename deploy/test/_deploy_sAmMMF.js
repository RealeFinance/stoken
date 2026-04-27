const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const contractName = "SAmMMF";
  const name = "BondPlus";
  const symbol = "BOND+";
  const data = {
    STOKEN_ADMIN: ["0x52c8EB42Ecd0F9932721F6a3d309675152d0C083"],
    assetRecipient: "0x54150c306E84885B2B406b4c4b5cbc869E38f96d",
    assetSender: "0x54150c306E84885B2B406b4c4b5cbc869E38f96d",
    serviceFeeRecipient: "0x54150c306E84885B2B406b4c4b5cbc869E38f96d",
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

  const tokenAddress = await proxy2.getAddress();
  console.log(`${contractName} Token 地址:`, tokenAddress);

  console.log(`开始设置权限...`);
  data.STOKEN_ADMIN?.forEach(async (admin) => {
    await proxy2.grantRole(ethers.id("STOKEN_ADMIN"), admin);
    console.log(`STOKEN_ADMIN权限已授予: ${admin}`);
  });
  await proxy2.grantRole(
    ethers.id("STOKEN_ADMIN"),
    await deployer.getAddress(),
  );
  console.log(`STOKEN_ADMIN权限已授予: ${deployer.address}`);
  await proxy2.setAssetRecipient(data.assetRecipient);
  console.log(`资产接收地址已设置: ${data.assetRecipient}`);
  await proxy2.setAssetSender(data.assetSender);
  console.log(`资产发送地址已设置: ${data.assetSender}`);
  await proxy2.setServiceFeeRecipient(data.serviceFeeRecipient);
  console.log(`服务费接收地址已设置: ${data.serviceFeeRecipient}`);
  data.supportedTokenAddresses?.forEach(async (address) => {
    await proxy2.addSupportedTokenAddress(address);
  });
  console.log(
    `支持的交易代币地址已设置: ${data.supportedTokenAddresses.join(", ")}`,
  );
}

main().catch(console.error);

// npx hardhat run deploy/test/_deploy_sAmMMF.js --network bscTestnet
