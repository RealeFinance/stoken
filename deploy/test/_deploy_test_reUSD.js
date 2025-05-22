async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署到网络: ${networkName}`);

  const { deployERC20, deployReUSD } = require("./_deploy_base").default;

  const mAmMMFToken = await deployERC20(hre, "mAmMMF", "mAmMMF");
  const mAmMMFTokenAddress = await mAmMMFToken.getAddress();

  const rAmMMFToken = await deployERC20(hre, "rAmMMF", "rAmMMF");
  const rAmMMFTokenAddress = await rAmMMFToken.getAddress();

  const reUSDToken = await deployReUSD(
    hre,
    mAmMMFTokenAddress,
    rAmMMFTokenAddress
  );

  // console.log(
  //   "引用AOABT BlockList Token地址:",
  //   process.env.TESTNET_AOABT_BlockList_ADDRESS
  // );
  // console.log(
  //   "引用AOABT AllowList Token地址:",
  //   process.env.TESTNET_AOABT_AllowList_ADDRESS
  // );
  // console.log("             RAmMMF Token地址:", RAmMMFAddress);
}

main().catch(console.error);
