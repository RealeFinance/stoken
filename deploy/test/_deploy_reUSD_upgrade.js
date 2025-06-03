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

  // console.log("正在验证合约...");

  // await hre.run("verify:verify", {
  //   address: RAmMMFAddress,
  //   constructorArguments: [],
  // });

  // console.log("合约验证完成。");
}

main().catch(console.error);
