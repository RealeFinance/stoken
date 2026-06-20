async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署到网络: ${networkName}`);

  const {
    deployBlackList,
    deployAllowList,
    deployRAmMMF,
  } = require("./_deploy_base");

  const BlackListToken = await deployBlackList(hre);
  const BlackListAddress = await BlackListToken.getAddress();
  const AllowListToken = await deployAllowList(hre);
  const AllowListAddress = await AllowListToken.getAddress();
  const RAmMMFToken = await deployRAmMMF(
    hre,
    BlackListAddress,
    AllowListAddress,
    process.env.AmMMF_ADDRESS,
    "RAmMMF",
    "RAmMMF"
  );
  const RAmMMFAddress = await RAmMMFToken.getAddress();

  console.log("BlockList Token地址:", BlackListAddress);
  console.log("AllowList Token地址:", AllowListAddress);
  console.log("   RAmMMF Token地址:", RAmMMFAddress);
}

main().catch(console.error);
