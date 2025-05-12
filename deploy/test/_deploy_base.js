async function deployBlackList(hre) {
  const ContractFactory = await ethers.getContractFactory("BlackList");
  const constructorArgs = [];

  console.log("BlackList 正在部署合约...");
  const contract = await ContractFactory.deploy(...constructorArgs);
  await contract.waitForDeployment();

  return contract;
};

async function deployAllowList(hre) {
  const ContractFactory = await ethers.getContractFactory("AllowList");
  const constructorArgs = [];

  console.log("AllowList 正在部署合约...");
  const contract = await ContractFactory.deploy(...constructorArgs);
  await contract.waitForDeployment();

  return contract;
};


module.exports = {
  deployBlackList,
  deployAllowList,
};