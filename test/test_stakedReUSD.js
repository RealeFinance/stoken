const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const parseEther = ethers.parseEther;

describe("StakedReUSD", function () {
  let StakedReUSD, stakedReUSD;
  let reUSDMock;
  let owner, user, other, admin;

  beforeEach(async function () {
    [owner, user, other, admin] = await ethers.getSigners();

    // Deploy mock ERC20 for reUSD
    const MockERC20 = await ethers.getContractFactory("Oracle");
    reUSDMock = await MockERC20.deploy();
    await reUSDMock.waitForDeployment();

    // Deploy StakedReUSD contract
    const StakedReUSDFactory = await ethers.getContractFactory("StakedReUSD");
    stakedReUSD = await upgrades.deployProxy(
      StakedReUSDFactory,
      ["Staked reUSD", "stRUSD", await reUSDMock.getAddress()],
      { initializer: "initialize" }
    );
    await stakedReUSD.waitForDeployment();
  });

  it("should initialize correctly", async function () {
    expect(await stakedReUSD.name()).to.equal("Staked reUSD");
    expect(await stakedReUSD.symbol()).to.equal("stRUSD");
    expect(await stakedReUSD.reUSD()).to.equal(await reUSDMock.getAddress());
    expect(await stakedReUSD.getOwner()).to.equal(owner.address);
  });

  it("should allow owner to transfer ownership", async function () {
    await stakedReUSD.transferOwnership(admin.address);
    expect(await stakedReUSD.getOwner()).to.equal(admin.address);
  });

  it("should revert ownership transfer to zero address", async function () {
    await expect(
      stakedReUSD.transferOwnership(ethers.ZeroAddress)
    ).to.be.revertedWith("New owner is the zero address");
  });

  it("should allow owner to pause and unpause", async function () {
    await stakedReUSD.pause();
    expect(await stakedReUSD.paused()).to.be.true;
    await stakedReUSD.unpause();
    expect(await stakedReUSD.paused()).to.be.false;
  });

  it("should revert pause/unpause if not owner", async function () {
    await expect(
      stakedReUSD.connect(user).pause()
    ).to.be.revertedWithCustomError(
      stakedReUSD,
      "AccessControlUnauthorizedAccount"
    );

    await stakedReUSD.pause();
    await expect(
      stakedReUSD.connect(user).unpause()
    ).to.be.revertedWithCustomError(
      stakedReUSD,
      "AccessControlUnauthorizedAccount"
    );
    await stakedReUSD.unpause();
  });

  it("should allow staking reUSD", async function () {
    await reUSDMock.mint(user.address, parseEther("100"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("50"));
    await stakedReUSD.connect(user).stake(parseEther("50"));
    expect(await stakedReUSD.balanceOf(user.address)).to.equal(
      parseEther("50")
    );
    expect(await reUSDMock.balanceOf(user.address)).to.equal(parseEther("50"));
    expect(await reUSDMock.balanceOf(stakedReUSD.getAddress())).to.equal(
      parseEther("50")
    );
  });

  it("should revert staking zero", async function () {
    await expect(stakedReUSD.stake(0)).to.be.revertedWith(
      "Amount must be greater than zero"
    );
  });

  it("should revert staking without enough balance", async function () {
    await reUSDMock.mint(user.address, parseEther("10"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("20"));
    await expect(
      stakedReUSD.connect(user).stake(parseEther("20"))
    ).to.be.revertedWith("Insufficient reUSD balance");
  });

  it("should revert staking without enough allowance", async function () {
    await reUSDMock.mint(user.address, parseEther("100"));
    await expect(
      stakedReUSD.connect(user).stake(parseEther("50"))
    ).to.be.revertedWith("Allowance not sufficient");
  });

  it("should allow unstaking principal", async function () {
    await reUSDMock.mint(user.address, parseEther("100"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("100"));
    await stakedReUSD.connect(user).stake(parseEther("100"));
    await stakedReUSD.connect(user).unstake(parseEther("40"));
    expect(await stakedReUSD.balanceOf(user.address)).to.equal(
      parseEther("60")
    );
    expect(await reUSDMock.balanceOf(user.address)).to.equal(parseEther("40"));
    expect(await reUSDMock.balanceOf(stakedReUSD.getAddress())).to.equal(
      parseEther("60")
    );
  });

  it("should revert unstaking zero", async function () {
    await expect(stakedReUSD.unstake(0)).to.be.revertedWith(
      "Amount must be greater than zero"
    );
  });

  it("should revert unstaking more than balance+interest", async function () {
    await reUSDMock.mint(user.address, parseEther("10"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("10"));
    await stakedReUSD.connect(user).stake(parseEther("10"));
    await expect(
      stakedReUSD.connect(user).unstake(parseEther("20"))
    ).to.be.revertedWith("Insufficient stakedReUSD balance");
  });

  it("should allow unstaking using interest", async function () {
    await reUSDMock.mint(user.address, parseEther("100"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("100"));
    await stakedReUSD.connect(user).stake(parseEther("100"));

    // Set interest for today
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await stakedReUSD.setDailyInterestRate(day * 24 * 60 * 60, 1000); // 10%
    await stakedReUSD.calculateDailyInterest(day * 24 * 60 * 60);

    // Unstake more than principal (principal=100, interest=10)
    await stakedReUSD.connect(user).unstake(parseEther("105"));
    expect(await stakedReUSD.balanceOf(user.address)).to.equal(parseEther("0"));
    expect(await stakedReUSD.getInterestBalance(user.address)).to.equal(
      parseEther("5")
    );
    expect(await reUSDMock.balanceOf(user.address)).to.equal(parseEther("5"));
  });

  it("should revert unstaking more than interest", async function () {
    await reUSDMock.mint(user.address, parseEther("100"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("100"));
    await stakedReUSD.connect(user).stake(parseEther("100"));

    // Set interest for today
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await stakedReUSD.setDailyInterestRate(day * 24 * 60 * 60, 1000); // 10%
    await stakedReUSD.calculateDailyInterest(day * 24 * 60 * 60);

    // Try to unstake more than principal+interest
    await expect(
      stakedReUSD.connect(user).unstake(parseEther("120"))
    ).to.be.revertedWith("Insufficient stakedReUSD balance");
  });

  it("should revert unstake if not enough interest", async function () {
    await reUSDMock.mint(user.address, parseEther("100"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("100"));
    await stakedReUSD.connect(user).stake(parseEther("100"));

    // Try to unstake more than principal, but no interest
    await expect(
      stakedReUSD.connect(user).unstake(parseEther("101"))
    ).to.be.revertedWith("Insufficient stakedReUSD balance");
  });

  it("should revert staking/unstaking when paused", async function () {
    await reUSDMock.mint(user.address, parseEther("100"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("100"));
    await stakedReUSD.pause();
    await expect(
      stakedReUSD.connect(user).stake(parseEther("10"))
    ).to.be.revertedWithCustomError(stakedReUSD, "EnforcedPause");
    await expect(
      stakedReUSD.connect(user).unstake(parseEther("10"))
    ).to.be.revertedWithCustomError(stakedReUSD, "EnforcedPause");
    await stakedReUSD.unpause();
  });

  it("should allow owner to set daily interest rate", async function () {
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await stakedReUSD.setDailyInterestRate(day * 24 * 60 * 60, 100);
    expect(await stakedReUSD.dailyInterestRates(day)).to.equal(100);
  });

  it("should revert setDailyInterestRate if not owner", async function () {
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await expect(
      stakedReUSD.connect(user).setDailyInterestRate(day * 24 * 60 * 60, 100)
    ).to.be.revertedWithCustomError(
      stakedReUSD,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("should revert setDailyInterestRate if rate is zero", async function () {
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await expect(
      stakedReUSD.setDailyInterestRate(day * 24 * 60 * 60, 0)
    ).to.be.revertedWith("Interest rate must be greater than zero");
  });

  it("should calculate daily interest only once per day", async function () {
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await stakedReUSD.setDailyInterestRate(day * 24 * 60 * 60, 100);
    await stakedReUSD.calculateDailyInterest(day * 24 * 60 * 60);
    await expect(
      stakedReUSD.calculateDailyInterest(day * 24 * 60 * 60)
    ).to.be.revertedWith("Interest already updated for this day");
  });

  it("should revert calculateDailyInterest if rate not set", async function () {
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await expect(
      stakedReUSD.calculateDailyInterest(day * 24 * 60 * 60)
    ).to.be.revertedWith("Interest rate not set for this day");
  });

  it("should update token holders correctly", async function () {
    await reUSDMock.mint(user.address, parseEther("10"));
    await reUSDMock
      .connect(user)
      .approve(stakedReUSD.getAddress(), parseEther("10"));
    await stakedReUSD.connect(user).stake(parseEther("10"));
    // No direct getter for tokenHolders, but can check interest calculation
    const now = Math.floor(Date.now() / 1000);
    const day = Math.floor(now / (24 * 60 * 60));
    await stakedReUSD.setDailyInterestRate(day * 24 * 60 * 60, 100);
    await stakedReUSD.calculateDailyInterest(day * 24 * 60 * 60);
    expect(await stakedReUSD.getInterestBalance(user.address)).to.equal(
      parseEther("0.1")
    );
  });
});
