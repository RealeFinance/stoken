async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署升级合约到网络: ${networkName}`);

  const { deployRAmMMFUpgrade } = require("./_deploy_base");

  const RAmMMFToken = await deployRAmMMFUpgrade(
    hre,
    process.env.TESTNET_rAmMMF_proxy_ADDRESS
  );
  const RAmMMFAddress = await RAmMMFToken.getAddress();

  console.log("RAmMMF升级成功...代理地址:", RAmMMFAddress);

  // console.log("正在验证合约...");

  // await hre.run("verify:verify", {
  //   address: RAmMMFAddress,
  //   constructorArguments: [],
  // });

  // console.log("合约验证完成。");
}

main().catch(console.error);
