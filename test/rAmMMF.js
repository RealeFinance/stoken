const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("BlackList", function () {
  let account
  let owner //所有部署合约的default Admin
  async function deployBlacklistFixture() {
    account = await ethers.getSigners()
    owner = account[0]
    const BlackListContract = await ethers.getContractFactory("BlackList", owner);
    // 部署逻辑合约
    const blackList = await BlackListContract.deploy();
    await blackList.waitForDeployment();
    // 部署代理合约 
    const proxy = await upgrades.deployProxy(BlackListContract, []);
    await proxy.waitForDeployment();

    // 手动调用 initialize 方法
    // const proxyAsContract = await BlackListContract.attach(await proxy.getAddress());
    // await proxyAsContract.initialize(owner.address);
    // await proxyAsContract.waitForDeployment();

    return { blackList: proxy };
  }

  async function deployAllowListFixture() {
    const AllowListContract = await ethers.getContractFactory("AllowList", owner);
    // 部署逻辑合约
    const allowList = await AllowListContract.deploy();
    await allowList.waitForDeployment();
    // 部署代理合约 
    const proxy = await upgrades.deployProxy(AllowListContract, []);
    await proxy.waitForDeployment();

    // 手动调用 initialize 方法
    // const proxyAsContract = await AllowListContract.attach(await proxy.getAddress());
    // await proxyAsContract.initialize(owner.address);
    // await proxyAsContract.waitForDeployment();

    return { allowList: proxy };
  }

  async function deployrAmMMFFixture() {
    const { blackList } = await loadFixture(deployBlacklistFixture);
    const { allowList } = await loadFixture(deployAllowListFixture);

    const RAmMMFContract = await ethers.getContractFactory("RAmMMF", owner, {
      initializer: 'initialize',
      kind: 'UUPS'
    });
    // 部署逻辑合约
    const RAmMMF = await RAmMMFContract.deploy();
    await RAmMMF.waitForDeployment();

    const address1 = await blackList.getAddress()
    const address2 = await allowList.getAddress()
    /**
     * 部署代理合约
     * @param RAmMMFContract 合约实例
     * @param RAmMMF 合约initialize方法的参数数组
     */ 
    const proxy = await upgrades.deployProxy(RAmMMFContract, [address1, address2]);
    await proxy.waitForDeployment();

    // 手动调用 initialize 方法
    const proxyAsContract = await RAmMMFContract.attach(await proxy.getAddress());
    // await proxyAsContract.initialize(owner.address);
    await proxyAsContract.waitForDeployment();

    return { blackList, RAmMMF: proxy, allowList };
  }

  describe("Deployment", function () {
    it("RAmMMF test", async function () {
      const { blackList, RAmMMF, allowList } = await loadFixture(deployrAmMMFFixture);

      await blackList.addToBlacklist([account[0].address, account[1].address, account[2].address])

      expect(await blackList.hasBlack(account[2].address)).to.equal(true)

      await blackList.removeFromBlacklist([account[2].address])

      expect(await blackList.hasBlack(account[1].address)).to.equal(true)
      expect(await blackList.hasBlack(account[2].address)).to.equal(false)

      await allowList.addToAllowlist([account[0].address, account[1].address])

      console.log(await RAmMMF.isBlack(account[0].address))
      console.log(await RAmMMF.isAllow(account[0].address))

    });
  });
});
