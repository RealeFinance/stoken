async function deployBlackList(hre) {
  const ContractFactory = await ethers.getContractFactory("BlockListPac");
  const constructorArgs = [];

  console.log("BlockList 正在部署合约...");
  const contract = await ContractFactory.deploy(...constructorArgs);
  await contract.waitForDeployment();

  return contract;
}

async function deployAllowList(hre) {
  const ContractFactory = await ethers.getContractFactory("AllowListPac");
  const constructorArgs = [];

  console.log("AllowList 正在部署合约...");
  const contract = await ContractFactory.deploy(...constructorArgs);
  await contract.waitForDeployment();

  return contract;
}

async function deployRAmMMF(
  hre,
  _blacklist,
  _allowlist,
  _ammmf,
  _name,
  _symbol
) {
  const ContractFactory = await ethers.getContractFactory("RAmMMF");
  const constructorArgs = [_blacklist, _allowlist, _ammmf, _name, _symbol, ""];

  console.log("RAmMMF 正在部署合约...");
  const contract = await ContractFactory.deploy(constructorArgs);
  await contract.waitForDeployment();

  return contract;
}

module.exports = {
  deployBlackList,
  deployAllowList,
  deployRAmMMF,
};
