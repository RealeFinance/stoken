async function main() {
  const hre = require("hardhat");

  const { name: networkName } = hre.network;
  console.log(`正在部署到网络: ${networkName}`);

  const {
    deployBlackList,
    deployAllowList,
    deployRAmMMF,
  } = require("./_deploy_base");

  // const BlackListToken = await deployBlackList(hre);
  // const BlackListAddress = await BlackListToken.getAddress();
  // const AllowListToken = await deployAllowList(hre);
  // const AllowListAddress = await AllowListToken.getAddress();
  const RAmMMFToken = await deployRAmMMF(
    hre,
    process.env.TESTNET_AOABTB_BlockList_ADDRESS,
    process.env.TESTNET_AOABTB_AllowList_ADDRESS,
    process.env.TESTNET_AOABTB_ADDRESS,
    "rAoABTb",
    "rAoABTb"
  );
  const RAmMMFAddress = await RAmMMFToken.getAddress();

  console.log(
    "引用AOABT BlockList Token地址:",
    process.env.TESTNET_AOABTB_BlockList_ADDRESS
  );
  console.log(
    "引用AOABT AllowList Token地址:",
    process.env.TESTNET_AOABTB_AllowList_ADDRESS
  );
  console.log("             RAmMMF Token地址:", RAmMMFAddress);
}

main().catch(console.error);
