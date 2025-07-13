const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("SAmMMF", function () {
  let SAmMMF, sAmMMF;
  let owner, admin, user, other;

  beforeEach(async function () {
    [owner, admin, user, other] = await ethers.getSigners();
    const SAmMMFFactory = await ethers.getContractFactory("SAmMMF");
    sAmMMF = await upgrades.deployProxy(
      SAmMMFFactory,
      ["Staked AMMF", "sAMMF"],
      { initializer: "initialize" }
    );
    await sAmMMF.waitForDeployment();

    // Grant STOKEN_ADMIN role to admin
    const STOKEN_ADMIN = await sAmMMF.STOKEN_ADMIN();
    await sAmMMF.grantRole(STOKEN_ADMIN, admin.address);
  });

  it("should initialize correctly", async function () {
    expect(await sAmMMF.name()).to.equal("Staked AMMF");
    expect(await sAmMMF.symbol()).to.equal("sAMMF");
    expect(
      await sAmMMF.hasRole(await sAmMMF.DEFAULT_ADMIN_ROLE(), owner.address)
    ).to.be.true;
    expect(await sAmMMF.hasRole(await sAmMMF.UPGRADER_ROLE(), owner.address)).to
      .be.true;
  });

  it("should allow admin to pause and unpause", async function () {
    await sAmMMF.pause();
    expect(await sAmMMF.paused()).to.be.true;
    await sAmMMF.unpause();
    expect(await sAmMMF.paused()).to.be.false;
  });

  it("should revert pause/unpause if not admin", async function () {
    await expect(sAmMMF.connect(user).pause()).to.be.revertedWithCustomError(
      sAmMMF,
      "AccessControlUnauthorizedAccount"
    );
    await expect(sAmMMF.connect(user).unpause()).to.be.revertedWithCustomError(
      sAmMMF,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("should set and get technical service fee rate", async function () {
    await sAmMMF.connect(admin).setTechnicalServiceFeeRate(50);
    expect(await sAmMMF.getTechnicalServiceFeeRate()).to.equal(50);
  });

  it("should revert setTechnicalServiceFeeRate if not STOKEN_ADMIN", async function () {
    await expect(
      sAmMMF.setTechnicalServiceFeeRate(100)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
  });

  it("should create a subscription and execute mint", async function () {
    const amount = ethers.parseEther("100");
    const price = ethers.parseEther("1");
    await sAmMMF.connect(admin).subscribe(amount, user.address, price);

    // Find subscriptionId by event
    const filter = sAmMMF.filters.subscribeEvent();
    const logs = await sAmMMF.queryFilter(filter);
    const subscriptionId = logs[0].args[0];

    await sAmMMF.connect(admin).execute(subscriptionId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(amount);
  });

  it("should revert subscribe with zero amount or zero address", async function () {
    const price = ethers.parseEther("1");
    await expect(
      sAmMMF.connect(admin).subscribe(0, user.address, price)
    ).to.be.revertedWith("Amount must be greater than zero");
    await expect(
      sAmMMF.connect(admin).subscribe(1, ethers.ZeroAddress, price)
    ).to.be.revertedWith("Invalid user address");
  });

  it("should revert execute with invalid subscriptionId", async function () {
    await expect(sAmMMF.connect(admin).execute(0)).to.be.revertedWith(
      "Invalid subscription ID"
    );
  });

  it("should allow claim to mint tokens", async function () {
    const amount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    await sAmMMF.connect(admin).subscribe(amount, user.address, price);

    const filter = sAmMMF.filters.subscribeEvent();
    const logs = await sAmMMF.queryFilter(filter);
    const subscriptionId = logs[0].args[0];

    await sAmMMF.connect(user).claim(subscriptionId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(amount);
  });

  it("should create redemption and burn tokens", async function () {
    const amount = ethers.parseEther("100");
    const price = ethers.parseEther("1");
    await sAmMMF.connect(admin).subscribe(amount, user.address, price);

    const subLogs = await sAmMMF.queryFilter(sAmMMF.filters.subscribeEvent());
    const subscriptionId = subLogs[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);

    await sAmMMF.connect(admin).redemption(amount, user.address, price);
    const redLogs = await sAmMMF.queryFilter(sAmMMF.filters.RedemptionEvent());
    const redemptionId = redLogs[0].args[0];

    await sAmMMF.connect(admin).burn(redemptionId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(0);
  });

  it("should revert redemption with zero amount or zero address", async function () {
    const price = ethers.parseEther("1");
    await expect(
      sAmMMF.connect(admin).redemption(0, user.address, price)
    ).to.be.revertedWith("Amount must be greater than zero");
    await expect(
      sAmMMF.connect(admin).redemption(1, ethers.ZeroAddress, price)
    ).to.be.revertedWith("Invalid user address");
  });

  it("should revert burn with invalid redemptionId", async function () {
    await expect(sAmMMF.connect(admin).burn(0)).to.be.revertedWith(
      "Invalid redemption ID"
    );
  });

  it("should get and remove redemption data", async function () {
    const amount = ethers.parseEther("10");
    const price = ethers.parseEther("1");
    await sAmMMF.connect(admin).redemption(amount, user.address, price);
    const logs = await sAmMMF.queryFilter(sAmMMF.filters.RedemptionEvent());
    const redemptionId = logs[0].args[0];

    const data = await sAmMMF.connect(admin).getRedemptionDataMap(redemptionId);
    expect(data.id).to.equal(redemptionId);

    await sAmMMF.connect(admin).removeRedemptionData(redemptionId);
    await expect(
      sAmMMF.connect(admin).getRedemptionDataMap(redemptionId)
    ).to.be.revertedWith("redemption does not exist");
  });

  it("should revert get/remove redemption data with invalid id", async function () {
    await expect(
      sAmMMF.connect(admin).getRedemptionDataMap(0)
    ).to.be.revertedWith("Invalid redemption ID");
    await expect(
      sAmMMF.connect(admin).removeRedemptionData(0)
    ).to.be.revertedWith("Invalid redemption ID");
  });

  it("should return balanceOfWithId correctly", async function () {
    const amount = ethers.parseEther("20");
    const price = ethers.parseEther("1");
    await sAmMMF.connect(admin).subscribe(amount, user.address, price);

    const logs = await sAmMMF.queryFilter(sAmMMF.filters.subscribeEvent());
    const subscriptionId = logs[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);

    const [tokenIds, amounts] = await sAmMMF.balanceOfWithId(user.address);
    expect(tokenIds.length).to.equal(1);
    expect(amounts[0]).to.equal(amount);
  });

  it("should transfer tokens and update tokenId list", async function () {
    const amount = ethers.parseEther("30");
    const price = ethers.parseEther("1");
    await sAmMMF.connect(admin).subscribe(amount, user.address, price);

    const logs = await sAmMMF.queryFilter(sAmMMF.filters.subscribeEvent());
    const subscriptionId = logs[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);

    await sAmMMF.connect(user).transfer(other.address, amount);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(0);
    expect(await sAmMMF.balanceOf(other.address)).to.equal(amount);
  });

  it("should revert transfer if not enough tokens", async function () {
    await expect(
      sAmMMF.connect(user).transfer(other.address, 1)
    ).to.be.revertedWith("No tokens to burn");
  });

  it("should transferFrom tokens and update allowance", async function () {
    const amount = ethers.parseEther("40");
    const price = ethers.parseEther("1");
    await sAmMMF.connect(admin).subscribe(amount, user.address, price);

    const logs = await sAmMMF.queryFilter(sAmMMF.filters.subscribeEvent());
    const subscriptionId = logs[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);

    await sAmMMF.connect(user).approve(other.address, amount);
    await sAmMMF
      .connect(other)
      .transferFrom(user.address, other.address, amount);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(0);
    expect(await sAmMMF.balanceOf(other.address)).to.equal(amount);
  });

  it("should revert transferFrom if not enough tokens", async function () {
    await sAmMMF.connect(user).approve(other.address, 100);
    await expect(
      sAmMMF.connect(other).transferFrom(user.address, other.address, 100)
    ).to.be.revertedWith("No tokens to burn");
  });
});
