async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署到网络: ${networkName}`);

  const {
    deployERC20,
    deployReUSD,
    deployCollateralConfig,
  } = require("./_deploy_base");

  const collateralConfigToken = await deployCollateralConfig(
    hre,
    "collateralConfig",
    "collateralConfig"
  );
  const collateralConfigAddress = await collateralConfigToken.getAddress();

  const reUSDToken = await deployReUSD(hre, collateralConfigAddress);
  const reUSDAddress = await reUSDToken.getAddress();
  console.log("CollateralConfig Token 地址:", collateralConfigAddress);
  console.log("reUSD Token            地址:", reUSDAddress);
}

main().catch(console.error);
