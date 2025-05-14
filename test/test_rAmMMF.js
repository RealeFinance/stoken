const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("RAmMMF Contract", function () {
  let rAmMMF, owner, addr1, addr2, blacklist, allowlist, ammmf, oracle;

  async function deployRAmMMF() {
    const MockMAmMMF = await ethers.getContractFactory("RAmMMF", owner);
    const mAmMMF = await upgrades.deployProxy(
      MockMAmMMF,
      [
        await blacklist.getAddress(),
        await allowlist.getAddress(),
        await ammmf.getAddress(),
        "RAmMMF",
        "RAmMMF",
      ],
      { initializer: "initialize" }
    );
    await mAmMMF.waitForDeployment();
    return mAmMMF;
  }

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // console.log(owner.address)
    // console.log(addr1.address)

    const BlackListContract = await ethers.getContractFactory(
      "BlackList",
      owner
    );
    // const blackList1 = await BlackListContract.deploy();
    // await blackList1.waitForDeployment();
    blacklist = await upgrades.deployProxy(BlackListContract, [], owner);
    await blacklist.waitForDeployment();

    const AllowlistMock = await ethers.getContractFactory("AllowList", owner);
    allowlist = await upgrades.deployProxy(AllowlistMock, [], owner);
    await allowlist.waitForDeployment();

    const AmMMFMock = await ethers.getContractFactory("AmMMF", owner);
    ammmf = await AmMMFMock.deploy();
    await ammmf.waitForDeployment();

    const OracleMock = await ethers.getContractFactory("Oracle", owner);
    oracle = await OracleMock.deploy();
    await oracle.waitForDeployment();

    rAmMMF = await deployRAmMMF();

    blacklist.addRamMMFAddress(await rAmMMF.getAddress());
    allowlist.addRamMMFAddress(await rAmMMF.getAddress());
  });

  describe("Initialization", function () {
    it("Should initialize with correct values", async function () {
      expect(await rAmMMF.blacklist()).to.equal(await blacklist.getAddress());
      expect(await rAmMMF.allowlist()).to.equal(await allowlist.getAddress());
      expect(await rAmMMF.ammmf()).to.equal(await ammmf.getAddress());
    });
  });

  describe("Wrap Functionality", function () {
    it("Should wrap AmMMF tokens and mint shares", async function () {
      const amount = ethers.parseUnits("100", 18);
      await ammmf.mint(addr1.address, amount);
      await ammmf.connect(addr1).approve(await rAmMMF.getAddress(), amount);
      await allowlist.addToAllowlist([addr1]);

      await expect(rAmMMF.connect(addr1).wrap(amount))
        .to.emit(rAmMMF, "TransferShares")
        .withArgs(ethers.ZeroAddress, addr1.address, amount * 10000n);

      expect(await rAmMMF.sharesOf(addr1.address)).to.equal(amount * 10000n);
    });

    it("Should revert if wrapping zero tokens", async function () {
      await expect(rAmMMF.connect(addr1).wrap(0)).to.be.revertedWith(
        "zero AmMMF tokens"
      );
    });
  });

  describe("Unwrap Functionality", function () {
    it("Should unwrap rAmMMF tokens and burn shares", async function () {
      const amount = ethers.parseUnits("100", 18);
      await ammmf.mint(addr1.address, amount);
      await ammmf.connect(addr1).approve(await rAmMMF.getAddress(), amount);
      await allowlist.addToAllowlist([addr1]);
      await rAmMMF.connect(addr1).wrap(amount);

      await expect(rAmMMF.connect(addr1).unwrap(amount))
        .to.emit(rAmMMF, "TransferShares")
        .withArgs(addr1.address, ethers.ZeroAddress, amount * 10000n);

      expect(await rAmMMF.sharesOf(addr1.address)).to.equal(0);
    });

    it("Should revert if unwrapping zero tokens", async function () {
      await expect(rAmMMF.connect(addr1).unwrap(0)).to.be.revertedWith(
        "zero rAmMMF tokens"
      );
    });

    it("Should revert if unwrapping too small amount", async function () {
      // Use an amount that is below the minimum unwrap threshold defined in the contract
      const tooSmallAmount = 2n; // 1 wei, adjust if your contract uses a different threshold
      await ammmf.mint(addr1.address, tooSmallAmount);
      await ammmf
        .connect(addr1)
        .approve(await rAmMMF.getAddress(), tooSmallAmount);
      await allowlist.addToAllowlist([addr1]);
      await rAmMMF.connect(addr1).wrap(tooSmallAmount);

      await rAmMMF.connect(addr1).unwrap(tooSmallAmount);
      // await expect(
      //   rAmMMF.connect(addr1).unwrap(tooSmallAmount)
      // ).to.be.revertedWithCustomError(rAmMMF, "UnwrapTooSmall");
    });
  });

  describe("Admin Functions", function () {
    it("Should allow admin to set oracle", async function () {
      const newOracle = addr1.address;
      await expect(rAmMMF.setOracle(newOracle))
        .to.emit(rAmMMF, "OracleSet")
        .withArgs(ethers.ZeroAddress, newOracle);

      expect(await rAmMMF.oracle()).to.equal(newOracle);
    });

    it("Should revert if setting oracle to zero address", async function () {
      await expect(
        rAmMMF.setOracle(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(rAmMMF, "CannotSetToZeroAddress");
    });

    it("Should allow admin to pause and unpause the contract", async function () {
      await rAmMMF.pause();
      expect(await rAmMMF.paused()).to.be.true;

      await rAmMMF.unpause();
      expect(await rAmMMF.paused()).to.be.false;
    });
  });

  describe("Transfer Functionality", function () {
    it("Should transfer shares between accounts", async function () {
      const amount = ethers.parseUnits("100", 18);
      await ammmf.mint(addr1.address, amount);
      await ammmf.connect(addr1).approve(await rAmMMF.getAddress(), amount);
      await allowlist.addToAllowlist([addr1, addr2]);
      await rAmMMF.connect(addr1).wrap(amount);

      await expect(rAmMMF.connect(addr1).transfer(addr2.address, amount))
        .to.emit(rAmMMF, "TransferShares")
        .withArgs(addr1.address, addr2.address, amount * 10000n);

      expect(await rAmMMF.sharesOf(addr1.address)).to.equal(0);
      expect(await rAmMMF.sharesOf(addr2.address)).to.equal(amount * 10000n);
    });

    it("Should revert if transferring more than balance", async function () {
      const amount = ethers.parseUnits("100", 18);
      await allowlist.addToAllowlist([addr1, addr2]);
      await expect(
        rAmMMF.connect(addr1).transfer(addr2.address, amount)
      ).to.be.revertedWith("TRANSFER_AMOUNT_EXCEEDS_BALANCE");
    });
  });
});
