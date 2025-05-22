const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("TokenConfig", function () {
  let TokenConfig, tokenConfig, owner, user, token1, token2;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy a mock ERC20 token for testing
    const MockERC20 = await ethers.getContractFactory("AmMMF");
    token1 = await MockERC20.deploy();
    await token1.initialize("MockToken1", "MTK1");
    token2 = await MockERC20.deploy();
    await token2.initialize("MockToken2", "MTK2");

    // Deploy TokenConfig contract
    const TokenConfigFactory = await ethers.getContractFactory("TokenConfig");
    tokenConfig = await upgrades.deployProxy(
      TokenConfigFactory,
      ["TokenConfig", "TCFG"],
      { initializer: "initialize" }
    );
    await tokenConfig.waitForDeployment();
  });

  it("should initialize with correct name and symbol", async function () {
    expect(await tokenConfig.name()).to.equal("TokenConfig");
    expect(await tokenConfig.symbol()).to.equal("TCFG");
  });

  it("should allow admin to set and get token", async function () {
    await tokenConfig.setToken("MockToken1", await token1.getAddress());
    const [name, addr] = await tokenConfig.getToken("MockToken1");
    expect(name).to.equal("MockToken1");
    expect(addr).to.equal(await token1.getAddress());
  });

  it("should update token address if setToken called again", async function () {
    await tokenConfig.setToken("MockToken1", await token1.getAddress());
    await tokenConfig.setToken("MockToken1", await token2.getAddress());
    const [name, addr] = await tokenConfig.getToken("MockToken1");
    expect(name).to.equal("MockToken1");
    expect(addr).to.equal(await token2.getAddress());
  });

  it("should return correct token address", async function () {
    await tokenConfig.setToken("MockToken1", await token1.getAddress());
    expect(await tokenConfig.getTokenAddress("MockToken1")).to.equal(
      await token1.getAddress()
    );
  });

  it("should return all tokens", async function () {
    await tokenConfig.setToken("MockToken1", await token1.getAddress());
    await tokenConfig.setToken("MockToken2", await token2.getAddress());
    const tokens = await tokenConfig.getAllTokens();
    console.log(tokens);
    expect(tokens.length).to.equal(2);
    expect(tokens.map((t) => t.addr)).to.include(await token1.getAddress());
    expect(tokens.map((t) => t.addr)).to.include(await token2.getAddress());
  });

  it("should only allow admin to set token", async function () {
    await expect(
      tokenConfig
        .connect(user)
        .setToken("MockToken1", await token1.getAddress())
    ).to.be.revertedWithCustomError(
      tokenConfig,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("should only allow admin to upgrade the proxy", async function () {
    const TokenConfigFactory = await ethers.getContractFactory("TokenConfig");
    await expect(
      upgrades.upgradeProxy(
        await tokenConfig.getAddress(),
        TokenConfigFactory.connect(user)
      )
    ).to.be.revertedWithCustomError(
      tokenConfig,
      "AccessControlUnauthorizedAccount"
    );
  });
});
