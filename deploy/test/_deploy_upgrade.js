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
}

main().catch(console.error);
