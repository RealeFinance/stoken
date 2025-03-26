const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("BlackList", function () {

  async function deployBlacklistFixture() {
    const [owner] = await ethers.getSigners()
    const BlackListContract = await ethers.getContractFactory("BlackList", owner);
    // 部署逻辑合约
    const blackList = await BlackListContract.deploy();
    await blackList.waitForDeployment();
    // 部署代理合约 
    const proxy = await upgrades.deployProxy(BlackListContract, []);
    await proxy.waitForDeployment();

    // 手动调用 initialize 方法
    const proxyAsContract = await BlackListContract.attach(await proxy.getAddress());
    // await proxyAsContract.initialize(owner.address);
    await proxyAsContract.waitForDeployment();

    return { blackList: proxy, owner };
  }

  async function deployrAmMMFFixture() {
    const { blackList } = await loadFixture(deployBlacklistFixture);
    const account = await ethers.getSigners()
    console.log(account[0].address) //2266
    console.log(account[1].address) //79c8
    const RAmMMFContract = await ethers.getContractFactory("RAmMMF", account[1], {
      initializer: 'initialize',
      kind: 'UUPS'
    });
    // 部署逻辑合约
    const RAmMMF = await RAmMMFContract.deploy();
    await RAmMMF.waitForDeployment();

    // 部署代理合约 
    const proxy = await upgrades.deployProxy(RAmMMFContract, [account[1].address, await blackList.getAddress()]);
    await proxy.waitForDeployment();

    // 手动调用 initialize 方法
    const proxyAsContract = await RAmMMFContract.attach(await proxy.getAddress());
    // await proxyAsContract.initialize(owner.address);
    await proxyAsContract.waitForDeployment();

    return { blackList, RAmMMF: proxy };
  }

  describe("Deployment", function () {
    it("RAmMMF test", async function () {
      const { blackList, RAmMMF } = await loadFixture(deployrAmMMFFixture);
      const account = await ethers.getSigners()

      // await blackList.addToBlacklist([])
      await blackList.addToBlacklist([account[1].address, account[2].address])
      await blackList.removeFromBlacklist([account[2].address])

      expect(await blackList.hasBlack(account[1].address)).to.equal(true)
      expect(await blackList.hasBlack(account[2].address)).to.equal(false)

      const c = await RAmMMF.connect(account[1]).isBlack()

      console.log(c)
      console.log(await blackList.getAddress())
    });
  });
});
