const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("CollateralConfig", function () {
  let CollateralConfig, collateralConfig, owner, user, oracle, token1, token2;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy a mock oracle
    const MockOracle = await ethers.getContractFactory("Oracle");
    oracle = await MockOracle.deploy();

    // Deploy two mock ERC20 tokens
    const MockERC20 = await ethers.getContractFactory("AmMMF");
    token1 = await MockERC20.deploy();
    await token1.initialize("MockToken1", "MTK1");
    token2 = await MockERC20.deploy();
    await token2.initialize("MockToken2", "MTK2");

    // Deploy CollateralConfig contract
    const CollateralConfigFactory = await ethers.getContractFactory(
      "CollateralConfig"
    );
    collateralConfig = await upgrades.deployProxy(
      CollateralConfigFactory,
      ["CollateralConfig", "CCFG", await oracle.getAddress()],
      { initializer: "initialize" }
    );
    await collateralConfig.waitForDeployment();
  });

  it("should initialize with correct name, symbol, and oracle", async function () {
    expect(await collateralConfig.name()).to.equal("CollateralConfig");
    expect(await collateralConfig.symbol()).to.equal("CCFG");
    expect(await collateralConfig.oracle()).to.equal(await oracle.getAddress());
  });

  it("should allow admin to set and get collateral", async function () {
    // Use the enum value for CollateralType.ERC20
    const CollateralType = {
      ERC20: 0,
      MTOKEN: 1, // Native isMtoken
      OTHER: 2,
    };

    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      CollateralType.ERC20,
      true
    );
    const [name, addr, ratio, isERC20, isEnabled] =
      await collateralConfig.getCollateral(await token1.getAddress());
    expect(name).to.equal("MockToken1");
    expect(addr).to.equal(await token1.getAddress());
    expect(ratio).to.equal(100);
    expect(isERC20).to.equal(true);
    expect(isEnabled).to.equal(true);
  });

  it("should revert if collateral address already exists", async function () {
    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      0,
      true
    );
    await expect(
      collateralConfig.setCollateral(
        "MockToken1",
        await token1.getAddress(),
        100,
        0,
        true
      )
    ).to.be.revertedWith("Collateral address already exists");
  });

  it("should revert if collateral name is empty", async function () {
    await expect(
      collateralConfig.setCollateral(
        "",
        await token1.getAddress(),
        100,
        0,
        true
      )
    ).to.be.revertedWith("Collateral name is empty");
  });

  it("should revert if collateral address is zero", async function () {
    await expect(
      collateralConfig.setCollateral(
        "MockToken1",
        ethers.ZeroAddress,
        100,
        0,
        true
      )
    ).to.be.revertedWith("Collateral address is zero");
  });

  it("should allow admin to delete collateral", async function () {
    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      0,
      true
    );
    await collateralConfig.deleteCollateral(await token1.getAddress());
    await expect(
      collateralConfig.getCollateral(await token1.getAddress())
    ).to.be.revertedWith("Collateral is not supported");
  });

  it("should revert when deleting non-existent collateral", async function () {
    await expect(
      collateralConfig.deleteCollateral(await token1.getAddress())
    ).to.be.revertedWith("Collateral does not exist");
  });

  it("should return all collaterals", async function () {
    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      0,
      true
    );
    await collateralConfig.setCollateral(
      "MockToken2",
      await token2.getAddress(),
      125,
      0,
      true
    );
    const collaterals = await collateralConfig.getAllCollaterals();
    expect(collaterals.length).to.equal(2);
    expect(collaterals.map((c) => c.addr)).to.include(
      await token1.getAddress()
    );
    expect(collaterals.map((c) => c.addr)).to.include(
      await token2.getAddress()
    );
  });

  it("should only allow admin to set collateral", async function () {
    await expect(
      collateralConfig
        .connect(user)
        .setCollateral("MockToken1", await token1.getAddress(), 100, 0, true)
    ).to.be.revertedWithCustomError(
      collateralConfig,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("should only allow admin to delete collateral", async function () {
    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      0,
      true
    );
    await expect(
      collateralConfig.connect(user).deleteCollateral(await token1.getAddress())
    ).to.be.revertedWithCustomError(
      collateralConfig,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("should allow admin to set and change oracle", async function () {
    const MockOracle = await ethers.getContractFactory("Oracle");
    const newOracle = await MockOracle.deploy();
    await collateralConfig.setOracle(await newOracle.getAddress());
    expect(await collateralConfig.oracle()).to.equal(
      await newOracle.getAddress()
    );
  });

  it("should only allow admin to set oracle", async function () {
    const MockOracle = await ethers.getContractFactory("Oracle");
    const newOracle = await MockOracle.deploy();
    await expect(
      collateralConfig.connect(user).setOracle(await newOracle.getAddress())
    ).to.be.revertedWithCustomError(
      collateralConfig,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("should revert if setting oracle to zero address", async function () {
    await expect(
      collateralConfig.setOracle(ethers.ZeroAddress)
    ).to.be.revertedWith("Oracle address is zero");
  });

  it("should allow admin to enable/disable collateral", async function () {
    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      0,
      true
    );
    await collateralConfig.setCollateralEnabled(
      await token1.getAddress(),
      false
    );
    await expect(
      collateralConfig.getCollateral(await token1.getAddress())
    ).to.be.revertedWith("Collateral is not supported");
    await collateralConfig.setCollateralEnabled(
      await token1.getAddress(),
      true
    );
    const [, , , , isEnabled] = await collateralConfig.getCollateral(
      await token1.getAddress()
    );
    expect(isEnabled).to.equal(true);
  });

  it("should revert if enabling/disabling non-existent collateral", async function () {
    await expect(
      collateralConfig.setCollateralEnabled(await token1.getAddress(), false)
    ).to.be.revertedWith("Collateral does not exist");
  });

  it("should calculate reUSD amount and collateral amount correctly", async function () {
    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      0,
      true
    );
    // getReUSDAmount: (amount * price * 100) / (ratio * 1e18)
    // getAmountByReUSD: (reUSDAmount * ratio * 1e18) / (price * 100)
    // price is hardcoded as 1e18 in mock
    const amount = ethers.parseUnits("10", 18);
    const reUSD = await collateralConfig.getReUSDAmount(
      await token1.getAddress(),
      amount
    );
    expect(reUSD).to.equal(amount);

    const needed = await collateralConfig.getAmountByReUSD(
      await token1.getAddress(),
      amount
    );
    expect(needed).to.equal(amount);
  });

  it("should revert getReUSDAmount/getAmountByReUSD if not supported", async function () {
    const amount = ethers.parseUnits("10", 18);
    await expect(
      collateralConfig.getReUSDAmount(await token1.getAddress(), amount)
    ).to.be.revertedWith("Collateral is not supported");
    await expect(
      collateralConfig.getAmountByReUSD(await token1.getAddress(), amount)
    ).to.be.revertedWith("Collateral is not supported");
  });

  it("should revert getReUSDAmount/getAmountByReUSD if amount is zero", async function () {
    await collateralConfig.setCollateral(
      "MockToken1",
      await token1.getAddress(),
      100,
      0,
      true
    );
    await expect(
      collateralConfig.getReUSDAmount(await token1.getAddress(), 0)
    ).to.be.revertedWith("Amount must be greater than zero");
    await expect(
      collateralConfig.getAmountByReUSD(await token1.getAddress(), 0)
    ).to.be.revertedWith("Amount must be greater than zero");
  });

  it("should only allow admin to upgrade the proxy", async function () {
    const CollateralConfigFactory = await ethers.getContractFactory(
      "CollateralConfig"
    );
    await expect(
      upgrades.upgradeProxy(
        await collateralConfig.getAddress(),
        CollateralConfigFactory.connect(user)
      )
    ).to.be.revertedWithCustomError(
      collateralConfig,
      "AccessControlUnauthorizedAccount"
    );
  });
});
