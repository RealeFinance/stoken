async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署到网络: ${networkName}`);

  const {
    deployERC20,
    deployReUSD,
    deployTokenConfig,
  } = require("./_deploy_base");

  // const mAmMMFToken = await deployERC20(hre, "mAmMMF", "mAmMMF");
  // const mAmMMFTokenAddress = await mAmMMFToken.getAddress();
  const mAmMMFTokenAddress = process.env.TESTNET_mAmMMF_proxy_ADDRESS;

  // const rAmMMFToken = await deployERC20(hre, "rAmMMF", "rAmMMF");
  // const rAmMMFTokenAddress = await rAmMMFToken.getAddress();
  const rAmMMFTokenAddress = process.env.TESTNET_rAmMMF_proxy_ADDRESS;

  const tokenConfigToken = await deployTokenConfig(
    hre,
    "tokenConfig",
    "tokenConfig"
  );
  const tokenConfigAddress = await tokenConfigToken.getAddress();

  const reUSDToken = await deployReUSD(
    hre,
    mAmMMFTokenAddress,
    rAmMMFTokenAddress,
    tokenConfigAddress
  );
  const reUSDAddress = await reUSDToken.getAddress();
  console.log("mAmMMF Token      地址:", mAmMMFTokenAddress);
  console.log("rAmMMF Token      地址:", rAmMMFTokenAddress);
  console.log("tokenConfig Token 地址:", tokenConfigAddress);
  console.log("reUSD Token       地址:", reUSDAddress);
}

main().catch(console.error);
