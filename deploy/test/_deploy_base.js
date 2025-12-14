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
  const constructorArgs = [_blacklist, _allowlist, _ammmf, _name, _symbol];

  console.log("RAmMMF 正在部署合约...");
  const contract = await hre.upgrades.deployProxy(
    ContractFactory,
    constructorArgs,
    {
      initializer: "initialize",
      gasLimit: 3000000,
      gasPrice: ethers.parseUnits("30", "gwei"),
    }
  );
  await contract.waitForDeployment();

  return contract;
}

async function deployRAmMMFUpgrade(hre, _proxyAddress) {
  const RAmMMF_V2 = await ethers.getContractFactory("RAmMMF");
  const rammmf_v2 = await RAmMMF_V2.deploy();
  await rammmf_v2.waitForDeployment();

  // 2. 升级代理到新实现
  const proxy = await hre.upgrades.upgradeProxy(_proxyAddress, RAmMMF_V2);
  return proxy;
}

async function deployReUSD(hre, tokenConfigAddress) {
  console.log("reUSD 正在部署合约...");
  const ReUSDFactory = await ethers.getContractFactory("ReUSD");
  reUSD = await hre.upgrades.deployProxy(
    ReUSDFactory,
    [tokenConfigAddress, "ReUSD", "ReUSD"],
    {
      initializer: "initialize",
      gasLimit: 3000000,
      gasPrice: ethers.parseUnits("30", "gwei"),
    }
  );
  await reUSD.waitForDeployment();
  return reUSD;
}

async function deployReUSDUpgrade(hre, _proxyAddress) {
  const reUSD_V2 = await ethers.getContractFactory("ReUSD");
  const reusd_V2 = await reUSD_V2.deploy();
  await reusd_V2.waitForDeployment();

  // 2. 升级代理到新实现
  const proxy = await hre.upgrades.upgradeProxy(_proxyAddress, reUSD_V2);
  return proxy;
}

async function deployCollateralConfigUpgrade(hre, _proxyAddress) {
  const CollateralConfig_V2 = await ethers.getContractFactory(
    "CollateralConfig"
  );
  const collateralconfig_V2 = await CollateralConfig_V2.deploy();
  await collateralconfig_V2.waitForDeployment();

  // 2. 升级代理到新实现
  const proxy = await hre.upgrades.upgradeProxy(
    _proxyAddress,
    CollateralConfig_V2
  );
  return proxy;
}

async function deployERC20(_name, _symbol) {
  console.log(`${_name} 正在部署合约...`);
  const MockERC20 = await ethers.getContractFactory("Oracle");
  mammmf = await MockERC20.deploy();
  await mammmf.waitForDeployment();
  await mammmf.initialize(_name, _symbol);
  return mammmf;
}

async function deploySAmMMF() {
  const Contract = await ethers.getContractFactory("SAmMMF");
  // const impl2 = await Contract.deploy({
  //   gasLimit: 15000000,
  // });
  // await impl2.waitForDeployment();

  const proxy2 = await upgrades.deployProxy(Contract, ["CashPlus", "CASH+"], {
    initializer: "initialize",
    gasLimit: 15000000,
    gasPrice: ethers.parseUnits("0.3", "gwei"),
  });
  await proxy2.waitForDeployment();
  return proxy2;
}

async function deploySAmMMFUpgrade(hre, _proxyAddress) {
  const SAmMMF_V2 = await ethers.getContractFactory("SAmMMF");
  const sammmf_v2 = await SAmMMF_V2.deploy();
  await sammmf_v2.waitForDeployment();

  // 2. 升级代理到新实现
  const proxy = await hre.upgrades.upgradeProxy(_proxyAddress, SAmMMF_V2);
  return proxy;
}

async function deployCollateralConfig(hre, _name, _symbol) {
  console.log(`${_name} 正在部署合约...`);
  const MockERC20 = await deployERC20(hre, "Oracle", "Oracle");
  const CollateralConfig = await ethers.getContractFactory("CollateralConfig");
  const collateralConfig = await hre.upgrades.deployProxy(
    CollateralConfig,
    [_name, _symbol, MockERC20.target],
    {
      initializer: "initialize",
      gasLimit: 3000000,
      gasPrice: ethers.parseUnits("30", "gwei"),
    }
  );
  await collateralConfig.waitForDeployment();
  return collateralConfig;
}

module.exports = {
  deployBlackList,
  deployAllowList,
  deployRAmMMF,
  deployRAmMMFUpgrade,
  deployReUSD,
  deployReUSDUpgrade,
  deployERC20,
  deployCollateralConfig,
  deployCollateralConfigUpgrade,
  deploySAmMMF,
  deploySAmMMFUpgrade,
};
