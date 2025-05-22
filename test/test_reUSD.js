const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("ReUSD", function () {
  let owner, addr1, addr2;
  let reUSD, rammmf, mammmf, tokenConfig;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy mock ERC20 for rAmMMF and mAmMMF
    const MockERC20 = await ethers.getContractFactory("Oracle");
    rammmf = await MockERC20.deploy();
    await rammmf.waitForDeployment();
    rammmf.initialize("rAmMMF", "rAmMMF");
    mammmf = await MockERC20.deploy();
    await mammmf.waitForDeployment();
    mammmf.initialize("mAmMMF", "mAmMMF");

    // Deploy mock TokenConfig
    const MockTokenConfig = await ethers.getContractFactory("TokenConfig");
    tokenConfig = await upgrades.deployProxy(
      MockTokenConfig,
      ["TokenConfig", "TCFG"],
      { initializer: "initialize" }
    );
    await tokenConfig.waitForDeployment();

    // Deploy ReUSD proxy
    const ReUSD = await ethers.getContractFactory("ReUSD");
    reUSD = await upgrades.deployProxy(
      ReUSD,
      [
        owner.address, // upgrader
        mammmf.target,
        rammmf.target,
        owner.address, // realeAdmin
        tokenConfig.target,
        "ReUSD",
        "ReUSD",
      ],
      { initializer: "initialize" }
    );
    await reUSD.waitForDeployment();
  });

  it("Initializes with correct values", async function () {
    expect(await reUSD.rammmf()).to.equal(rammmf.target);
    expect(await reUSD.mammmf()).to.equal(mammmf.target);
    expect(await reUSD.realeAdmin()).to.equal(owner.address);
    expect(await reUSD.tokenConfig()).to.equal(tokenConfig.target);
  });

  it("Allows locking rAmMMF for reUSD", async function () {
    const amount = ethers.parseUnits("100", 18);
    await rammmf.mint(addr1.address, amount);
    await rammmf.connect(addr1).approve(reUSD.target, amount);

    await expect(reUSD.connect(addr1).lock("rAmMMF", amount))
      .to.emit(reUSD, "SwapReUSD")
      .withArgs(addr1.address, amount, "rAmMMF");

    expect(await reUSD.balanceOf(addr1.address)).to.equal(amount);
    expect(await rammmf.balanceOf(addr1.address)).to.equal(0);
  });

  it("Allows locking mAmMMF for reUSD", async function () {
    const amount = ethers.parseUnits("100", 18);
    await mammmf.mint(addr1.address, amount);
    await mammmf.connect(addr1).approve(reUSD.target, amount);

    await expect(reUSD.connect(addr1).lock("mAmMMF", amount))
      .to.emit(reUSD, "SwapReUSD")
      .withArgs(addr1.address, amount, "mAmMMF");

    expect(await reUSD.balanceOf(addr1.address)).to.equal(amount);
    expect(await mammmf.balanceOf(addr1.address)).to.equal(0);
  });

  it("Allows locking custom token for reUSD", async function () {
    const MockERC20 = await ethers.getContractFactory("Oracle");
    const customToken = await MockERC20.deploy();
    await customToken.waitForDeployment();
    await tokenConfig.setToken("CSTM", customToken.target);

    const amount = ethers.parseUnits("50", 18);
    await customToken.mint(addr1.address, amount);
    await customToken.connect(addr1).approve(reUSD.target, amount);

    await expect(reUSD.connect(addr1).lock("CSTM", amount))
      .to.emit(reUSD, "SwapReUSD")
      .withArgs(addr1.address, amount, "CSTM");

    expect(await reUSD.balanceOf(addr1.address)).to.equal(amount);
    expect(await customToken.balanceOf(addr1.address)).to.equal(0);
  });

  it("Allows redeeming reUSD for rAmMMF", async function () {
    const amount = ethers.parseUnits("100", 18);
    await rammmf.mint(reUSD.target, amount);
    await reUSD.mint(addr1.address, amount);

    await expect(reUSD.connect(addr1).redeem("rAmMMF", amount))
      .to.emit(reUSD, "RedeemReUSD")
      .withArgs(addr1.address, amount, "rAmMMF");

    expect(await reUSD.balanceOf(addr1.address)).to.equal(0);
    expect(await rammmf.balanceOf(addr1.address)).to.equal(amount);
  });

  it("Allows redeeming reUSD for mAmMMF", async function () {
    const amount = ethers.parseUnits("100", 18);
    await mammmf.mint(reUSD.target, amount);
    await reUSD.mint(addr1.address, amount);

    await expect(reUSD.connect(addr1).redeem("mAmMMF", amount))
      .to.emit(reUSD, "RedeemReUSD")
      .withArgs(addr1.address, amount, "mAmMMF");

    expect(await reUSD.balanceOf(addr1.address)).to.equal(0);
    expect(await mammmf.balanceOf(addr1.address)).to.equal(amount);
  });

  it("Allows admin to mint and burn", async function () {
    const amount = ethers.parseUnits("10", 18);
    await reUSD.mint(addr2.address, amount);
    expect(await reUSD.balanceOf(addr2.address)).to.equal(amount);

    await reUSD.burn(addr2.address, amount);
    expect(await reUSD.balanceOf(addr2.address)).to.equal(0);
  });

  it("Does not allow non-admin to mint or burn", async function () {
    const amount = ethers.parseUnits("10", 18);
    await expect(reUSD.connect(addr1).mint(addr1.address, amount)).to.be
      .reverted;
    await expect(reUSD.connect(addr1).burn(addr1.address, amount)).to.be
      .reverted;
  });
});
