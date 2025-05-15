const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("ReUSD Contract", function () {
  let reUSD, rammmf, mammmf, owner, addr1, addr2;

  async function deployReUSD() {
    const ReUSD = await ethers.getContractFactory("ReUSD", owner);
    const reUSDInstance = await upgrades.deployProxy(
      ReUSD,
      [
        owner.address, // upgrader
        await mammmf.getAddress(),
        await rammmf.getAddress(),
        owner.address, // realeAdmin
        "ReUSD",
        "ReUSD",
      ],
      { initializer: "initialize" }
    );
    await reUSDInstance.waitForDeployment();
    return reUSDInstance;
  }

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const MockToken = await ethers.getContractFactory("Oracle", owner);

    rammmf = await MockToken.deploy();
    await rammmf.waitForDeployment();

    mammmf = await MockToken.deploy();
    await mammmf.waitForDeployment();

    reUSD = await deployReUSD();
  });

  describe("Initialization", function () {
    it("Should initialize with correct values", async function () {
      expect(await reUSD.rammmf()).to.equal(await rammmf.getAddress());
      expect(await reUSD.mammmf()).to.equal(await mammmf.getAddress());
      expect(await reUSD.realeAdmin()).to.equal(owner.address);
    });
  });

  describe("Swap by rAmMMF", function () {
    it("Should allow swapping rAmMMF for reUSD", async function () {
      const amount = ethers.parseUnits("100", 18);
      await rammmf.mint(addr1.address, amount);
      await rammmf.connect(addr1).approve(await reUSD.getAddress(), amount);

      await expect(reUSD.connect(addr1).swapByRAmMMf(amount))
        .to.emit(reUSD, "Transfer")
        .withArgs(ethers.ZeroAddress, addr1.address, amount);

      expect(await reUSD.balanceOf(addr1.address)).to.equal(amount);
      expect(await rammmf.balanceOf(addr1.address)).to.equal(0);
    });

    it("Should revert if amount is zero", async function () {
      await expect(reUSD.connect(addr1).swapByRAmMMf(0)).to.be.revertedWith(
        "Amount must be greater than zero"
      );
    });
  });

  describe("Swap by mAmMMF", function () {
    it("Should allow swapping mAmMMF for reUSD", async function () {
      const amount = ethers.parseUnits("100", 18);
      await mammmf.mint(addr1.address, amount);
      await mammmf.connect(addr1).approve(await reUSD.getAddress(), amount);

      await expect(reUSD.connect(addr1).swapByMAmMMf(amount))
        .to.emit(reUSD, "Transfer")
        .withArgs(ethers.ZeroAddress, addr1.address, amount);

      expect(await reUSD.balanceOf(addr1.address)).to.equal(amount);
      expect(await mammmf.balanceOf(addr1.address)).to.equal(0);
    });

    it("Should revert if amount is zero", async function () {
      await expect(reUSD.connect(addr1).swapByMAmMMf(0)).to.be.revertedWith(
        "Amount must be greater than zero"
      );
    });
  });

  describe("Redeem to rAmMMF", function () {
    it("Should allow redeeming reUSD for rAmMMF", async function () {
      const amount = ethers.parseUnits("100", 18);
      await rammmf.mint(await reUSD.getAddress(), amount);
      await reUSD.mint(addr1.address, amount);

      await expect(reUSD.connect(addr1).redeemToRAmMMf(amount))
        .to.emit(reUSD, "Transfer")
        .withArgs(addr1.address, ethers.ZeroAddress, amount);

      expect(await reUSD.balanceOf(addr1.address)).to.equal(0);
      expect(await rammmf.balanceOf(addr1.address)).to.equal(amount);
    });

    it("Should revert if amount is zero", async function () {
      await expect(reUSD.connect(addr1).redeemToRAmMMf(0)).to.be.revertedWith(
        "Amount must be greater than zero"
      );
    });
  });

  describe("Redeem to mAmMMF", function () {
    it("Should allow redeeming reUSD for mAmMMF", async function () {
      const amount = ethers.parseUnits("100", 18);
      await mammmf.mint(await reUSD.getAddress(), amount);
      await reUSD.mint(addr1.address, amount);

      await expect(reUSD.connect(addr1).redeemToMAmMMf(amount))
        .to.emit(reUSD, "Transfer")
        .withArgs(addr1.address, ethers.ZeroAddress, amount);

      expect(await reUSD.balanceOf(addr1.address)).to.equal(0);
      expect(await mammmf.balanceOf(addr1.address)).to.equal(amount);
    });

    it("Should revert if amount is zero", async function () {
      await expect(reUSD.connect(addr1).redeemToMAmMMf(0)).to.be.revertedWith(
        "Amount must be greater than zero"
      );
    });
  });
});
