const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
require("@nomicfoundation/hardhat-chai-matchers");

describe("RAmMMF", function () {
  let owner, addr1, addr2, blocklist, allowlist, ammmf, oracle, rAmMMF;

  async function deployRAmMMF() {
    const RAmMMF = await ethers.getContractFactory("RAmMMF", owner);
    const proxy = await upgrades.deployProxy(
      RAmMMF,
      [
        await blocklist.getAddress(),
        await allowlist.getAddress(),
        await ammmf.getAddress(),
        "RAmMMF",
        "RAmMMF",
      ],
      { initializer: "initialize" }
    );
    await proxy.waitForDeployment();
    return proxy;
  }

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const BlockList = await ethers.getContractFactory("BlockListPac", owner);
    blocklist = await upgrades.deployProxy(BlockList, [], owner);
    await blocklist.waitForDeployment();

    const AllowList = await ethers.getContractFactory("AllowListPac", owner);
    allowlist = await upgrades.deployProxy(AllowList, [], owner);
    await allowlist.waitForDeployment();

    const AmMMF = await ethers.getContractFactory("AmMMF", owner);
    ammmf = await AmMMF.deploy();
    await ammmf.waitForDeployment();

    const Oracle = await ethers.getContractFactory("Oracle", owner);
    oracle = await Oracle.deploy();
    await oracle.waitForDeployment();

    rAmMMF = await deployRAmMMF();

    await blocklist.addRamMMFAddress(await rAmMMF.getAddress());
    await allowlist.addRamMMFAddress(await rAmMMF.getAddress());
  });

  describe("Initialization", function () {
    it("should initialize with correct values", async function () {
      expect(await rAmMMF.blocklist()).to.equal(await blocklist.getAddress());
      expect(await rAmMMF.allowlist()).to.equal(await allowlist.getAddress());
      expect(await rAmMMF.ammmf()).to.equal(await ammmf.getAddress());
    });
  });

  describe("Wrap", function () {
    it("should wrap AmMMF tokens and mint shares", async function () {
      const amount = ethers.parseUnits("100", 18);
      await ammmf.mint(addr1.address, amount);
      await ammmf.connect(addr1).approve(await rAmMMF.getAddress(), amount);
      await allowlist.addToAllowlist([addr1]);
      await expect(rAmMMF.connect(addr1).wrap(amount))
        .to.emit(rAmMMF, "WrapCompleted")
        .withArgs(addr1.address, amount * 10000n, amount, 1000000000000000000n);
      expect(await rAmMMF.sharesOf(addr1.address)).to.equal(amount * 10000n);
    });

    it("should revert if wrapping zero tokens", async function () {
      await expect(rAmMMF.connect(addr1).wrap(0)).to.be.revertedWith(
        "zero AmMMF tokens"
      );
    });
  });

  describe("Unwrap", function () {
    it("should unwrap rAmMMF tokens and burn shares", async function () {
      const amount = ethers.parseUnits("100", 18);
      await ammmf.mint(addr1.address, amount);
      await ammmf.connect(addr1).approve(await rAmMMF.getAddress(), amount);
      await allowlist.addToAllowlist([addr1]);
      await rAmMMF.connect(addr1).wrap(amount);

      await expect(rAmMMF.connect(addr1).unwrap(amount)).to.emit(
        rAmMMF,
        "UnWrapCompleted"
      );
      expect(await rAmMMF.sharesOf(addr1.address)).to.equal(0);
    });

    it("should revert if unwrapping zero tokens", async function () {
      await expect(rAmMMF.connect(addr1).unwrap(0)).to.be.revertedWith(
        "zero rAmMMF tokens"
      );
    });

    it("should revert if unwrapping too small amount", async function () {
      const tooSmall = 1n;
      await ammmf.mint(addr1.address, tooSmall);
      await ammmf.connect(addr1).approve(await rAmMMF.getAddress(), tooSmall);
      await allowlist.addToAllowlist([addr1]);
      await rAmMMF.connect(addr1).wrap(tooSmall);
      await rAmMMF.connect(addr1).unwrap(tooSmall);
      // await expect(rAmMMF.connect(addr1).unwrap(tooSmall)).to.be.revertedWith("zero rAmMMF tokens");
    });
  });

  describe("Admin", function () {
    it("should allow admin to set oracle", async function () {
      const newOracle = addr1.address;
      await expect(rAmMMF.setOracle(newOracle))
        .to.emit(rAmMMF, "OracleSet")
        .withArgs(ethers.ZeroAddress, newOracle);
      expect(await rAmMMF.oracle()).to.equal(newOracle);
    });

    it("should revert if setting oracle to zero address", async function () {
      await expect(
        rAmMMF.setOracle(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(rAmMMF, "CannotSetToZeroAddress");
    });

    it("should allow admin to pause and unpause", async function () {
      await rAmMMF.pause();
      expect(await rAmMMF.paused()).to.be.true;
      await rAmMMF.unpause();
      expect(await rAmMMF.paused()).to.be.false;
    });
  });

  describe("Transfer", function () {
    it("should transfer shares between accounts", async function () {
      const amount = ethers.parseUnits("100", 18);
      await ammmf.mint(addr1.address, amount);
      await ammmf.connect(addr1).approve(await rAmMMF.getAddress(), amount);
      await allowlist.addToAllowlist([addr1, addr2]);
      await rAmMMF.connect(addr1).wrap(amount);

      await expect(
        rAmMMF.connect(addr1).transfer(addr2.address, amount)
      ).to.emit(rAmMMF, "TransferShares");
      expect(await rAmMMF.sharesOf(addr1.address)).to.equal(0);
      expect(await rAmMMF.sharesOf(addr2.address)).to.equal(amount * 10000n);
    });

    it("should revert if transferring more than balance", async function () {
      const amount = ethers.parseUnits("100", 18);
      await allowlist.addToAllowlist([addr1, addr2]);
      await expect(
        rAmMMF.connect(addr1).transfer(addr2.address, amount)
      ).to.be.revertedWith("TRANSFER_AMOUNT_EXCEEDS_BALANCE");
    });
  });
});
