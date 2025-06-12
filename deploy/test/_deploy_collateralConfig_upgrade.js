async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署升级合约到网络: ${networkName}`);

  const { deployCollateralConfigUpgrade } = require("./_deploy_base");

  const CollateralConfigToken = await deployCollateralConfigUpgrade(
    hre,
    process.env.TESTNET_CollateralConfig_proxy_ADDRESS
  );
  const CollateralConfigAddress = await CollateralConfigToken.getAddress();

  console.log("CollateralConfig升级成功...代理地址:", CollateralConfigAddress);

  // console.log("正在验证合约...");

  // await hre.run("verify:verify", {
  //   address: RAmMMFAddress,
  //   constructorArguments: [],
  // });

  // console.log("合约验证完成。");
}

main().catch(console.error);
