async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署到网络: ${networkName}`);

  const { deployERC20 } = require("./_deploy_base");

  const token = await deployERC20("USDT", "USDT");
  const tokenAddress = await token.getAddress();
  console.log("MOCK USDT 地址:", tokenAddress);
}

main().catch(console.error);
