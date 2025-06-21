const { ethers, upgrades } = require("hardhat");
async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署升级合约到网络: ${networkName}`);

  const { deployReUSDUpgrade } = require("./_deploy_base");

  const ReUSDToken = await deployReUSDUpgrade(
    hre,
    process.env.TESTNET_reUSD_proxy_ADDRESS
  );
  const ReUSDAddress = await ReUSDToken.getAddress();

  console.log("ReUSD升级成功...代理地址:", ReUSDAddress);

  //强制导入现有代理合约
  // await upgrades.forceImport(
  //   process.env.TESTNET_reUSD_proxy_ADDRESS,
  //   await ethers.getContractFactory("ReUSD")
  // );

  // console.log("已成功导入代理合约，准备升级...");

  // // 现在可以正常升级合约
  // const ContractV2 = await ethers.getContractFactory("ReUSD");
  // const upgraded = await upgrades.upgradeProxy(process.env.TESTNET_reUSD_proxy_ADDRESS, ContractV2);

  // console.log("合约已升级到新版本");
}

main().catch(console.error);
