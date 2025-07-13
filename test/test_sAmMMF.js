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
      {
        initializer: "initialize",
      }
    );
    await sAmMMF.waitForDeployment();
    await sAmMMF.grantRole(await sAmMMF.STOKEN_ADMIN(), admin.address);
  });

  it("should initialize correctly", async function () {
    expect(await sAmMMF.name()).to.equal("Staked AMMF");
    expect(await sAmMMF.symbol()).to.equal("sAMMF");
    expect(await sAmMMF.getTechnicalServiceFeeRate()).to.equal(10);
    expect(
      await sAmMMF.hasRole(await sAmMMF.DEFAULT_ADMIN_ROLE(), owner.address)
    ).to.be.true;
    expect(await sAmMMF.hasRole(await sAmMMF.UPGRADER_ROLE(), owner.address)).to
      .be.true;
  });

  it("should allow admin to set technical service fee rate", async function () {
    await sAmMMF.connect(admin).setTechnicalServiceFeeRate(50);
    expect(await sAmMMF.getTechnicalServiceFeeRate()).to.equal(50);
  });

  it("should revert setTechnicalServiceFeeRate if not admin", async function () {
    await expect(
      sAmMMF.connect(user).setTechnicalServiceFeeRate(100)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
  });

  it("should pause and unpause by owner", async function () {
    await sAmMMF.pause();
    expect(await sAmMMF.paused()).to.be.true;
    await sAmMMF.unpause();
    expect(await sAmMMF.paused()).to.be.false;
  });

  it("should revert pause/unpause if not owner", async function () {
    await expect(sAmMMF.connect(user).pause()).to.be.revertedWithCustomError(
      sAmMMF,
      "AccessControlUnauthorizedAccount"
    );
    await sAmMMF.pause();
    await expect(sAmMMF.connect(user).unpause()).to.be.revertedWithCustomError(
      sAmMMF,
      "AccessControlUnauthorizedAccount"
    );
    await sAmMMF.unpause();
  });

  it("should subscribe and execute mint", async function () {
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    // Find subscriptionId by event
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(stokenAmount);
    // Should not allow execute again
    await expect(
      sAmMMF.connect(admin).execute(subscriptionId)
    ).to.be.revertedWith("Subscription does not exist");
  });

  it("should claim mint", async function () {
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(user).claim(subscriptionId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(stokenAmount);
  });

  it("should revert subscribe with zero stokenAmount or time", async function () {
    await expect(
      sAmMMF.connect(admin).subscribe(1, 0, user.address, 1, 1, 1)
    ).to.be.revertedWith("Stoken amount must be greater than zero");
    await expect(
      sAmMMF.connect(admin).subscribe(1, 1, user.address, 1, 0, 1)
    ).to.be.revertedWith("Time must be greater than zero");
    await expect(
      sAmMMF.connect(admin).subscribe(1, 1, ethers.ZeroAddress, 1, 1, 1)
    ).to.be.revertedWith("Invalid user address");
  });

  it("should redeem and burn tokens", async function () {
    // Mint tokens first
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);
    // Redemption
    await sAmMMF
      .connect(admin)
      .redemption(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const redemptionFilter = await sAmMMF.queryFilter("RedemptionEvent");
    const redemptionId = redemptionFilter[0].args[0];
    await sAmMMF.connect(admin).burn(redemptionId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(0);
  });

  it("should revert redemption with zero stokenAmount or time", async function () {
    await expect(
      sAmMMF.connect(admin).redemption(1, 0, user.address, 1, 1, 1)
    ).to.be.revertedWith("Stoken amount must be greater than zero");
    await expect(
      sAmMMF.connect(admin).redemption(1, 1, user.address, 1, 0, 1)
    ).to.be.revertedWith("Time must be greater than zero");
    await expect(
      sAmMMF.connect(admin).redemption(1, 1, ethers.ZeroAddress, 1, 1, 1)
    ).to.be.revertedWith("Invalid user address");
  });

  it("should get and remove redemption data", async function () {
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .redemption(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const redemptionFilter = await sAmMMF.queryFilter("RedemptionEvent");
    const redemptionId = redemptionFilter[0].args[0];
    const data = await sAmMMF.connect(admin).getRedemptionDataMap(redemptionId);
    expect(data.id).to.equal(redemptionId);
    await sAmMMF.connect(admin).removeRedemptionData(redemptionId);
    await expect(
      sAmMMF.connect(admin).getRedemptionDataMap(redemptionId)
    ).to.be.revertedWith("redemption does not exist");
  });

  it("should revert get/remove redemption data if not admin", async function () {
    await expect(
      sAmMMF.connect(user).getRedemptionDataMap(1)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
    await expect(
      sAmMMF.connect(user).removeRedemptionData(1)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
  });

  it("should revert burn if not enough tokens", async function () {
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .redemption(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const redemptionFilter = await sAmMMF.queryFilter("RedemptionEvent");
    const redemptionId = redemptionFilter[0].args[0];
    await expect(sAmMMF.connect(admin).burn(redemptionId)).to.be.revertedWith(
      "No tokens to burn"
    );
  });

  it("should return balanceOfWithId correctly", async function () {
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);
    const [tokenIds, amounts] = await sAmMMF.balanceOfWithId(user.address);
    expect(tokenIds.length).to.equal(1);
    expect(amounts[0]).to.equal(stokenAmount);
  });

  it("should transfer tokens and update tokenId mapping", async function () {
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);
    await sAmMMF.connect(user).transfer(other.address, stokenAmount);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(0);
    expect(await sAmMMF.balanceOf(other.address)).to.equal(stokenAmount);
    const [tokenIds, amounts] = await sAmMMF.balanceOfWithId(other.address);
    expect(tokenIds.length).to.equal(1);
    expect(amounts[0]).to.equal(stokenAmount);
  });

  it("should revert transfer if not enough tokens", async function () {
    await expect(
      sAmMMF.connect(user).transfer(other.address, 1)
    ).to.be.revertedWith("No tokens to burn");
  });

  it("should get token data", async function () {
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);
    const [tokenIds] = await sAmMMF.balanceOfWithId(user.address);
    const tokenData = await sAmMMF.getTokenData(tokenIds[0]);
    expect(tokenData.tokenOwner).to.equal(user.address);
    expect(tokenData.price).to.equal(price);
    expect(tokenData.mintTime).to.equal(time);
  });

  it("should revert getTokenData for invalid tokenId", async function () {
    await expect(sAmMMF.getTokenData(0)).to.be.revertedWith("Invalid token ID");
    await expect(sAmMMF.getTokenData(123)).to.be.revertedWith(
      "Token does not exist"
    );
  });

  it("should transfer tokens, redeem, get and remove redemption data", async function () {
    // Mint tokens to user
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);

    // Transfer tokens from user to other
    await sAmMMF.connect(user).transfer(other.address, stokenAmount);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(0);
    expect(await sAmMMF.balanceOf(other.address)).to.equal(stokenAmount);

    // Redemption for other
    await sAmMMF
      .connect(admin)
      .redemption(usdtAmount, stokenAmount, other.address, price, time, txHash);
    const redemptionFilter = await sAmMMF.queryFilter("RedemptionEvent");
    const redemptionId = redemptionFilter[0].args[0];

    // Get redemption data
    const data = await sAmMMF.connect(admin).getRedemptionDataMap(redemptionId);
    expect(data.id).to.equal(redemptionId);
    expect(data.user).to.equal(other.address);
    expect(data.stokenAmount).to.equal(stokenAmount);

    // Remove redemption data
    await sAmMMF.connect(admin).removeRedemptionData(redemptionId);
    await expect(
      sAmMMF.connect(admin).getRedemptionDataMap(redemptionId)
    ).to.be.revertedWith("redemption does not exist");
  });

  it("should redeem, burn, then getRedemptionDataMap and revert", async function () {
    // Mint tokens to user
    const usdtAmount = ethers.parseEther("100");
    const stokenAmount = ethers.parseEther("50");
    const price = ethers.parseEther("2");
    const time = Math.floor(Date.now() / 1000);
    const txHash = 123456;

    // Subscribe and execute mint for user
    await sAmMMF
      .connect(admin)
      .subscribe(usdtAmount, stokenAmount, user.address, price, time, txHash);
    const filter = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId = filter[0].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId);

    // Subscribe and execute mint for user
    await sAmMMF
      .connect(admin)
      .subscribe(
        usdtAmount,
        ethers.parseEther("200"),
        user.address,
        price,
        time,
        txHash
      );
    const filter1 = await sAmMMF.queryFilter("subscribeEvent");
    const subscriptionId1 = filter1[1].args[0];
    await sAmMMF.connect(admin).execute(subscriptionId1);

    // Redemption for user
    await sAmMMF
      .connect(admin)
      .redemption(
        usdtAmount,
        ethers.parseEther("120"),
        user.address,
        price,
        time,
        txHash
      );
    const redemptionFilter = await sAmMMF.queryFilter("RedemptionEvent");
    const redemptionId = redemptionFilter[0].args[0];

    // Burn tokens for redemptionId
    await sAmMMF.connect(admin).burn(redemptionId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(
      ethers.parseEther("130")
    );

    // Get redemption data
    const data = await sAmMMF.connect(admin).getRedemptionDataMap(redemptionId);
    console.info(data);
    const [tokenIds, amounts] = await sAmMMF.balanceOfWithId(user.address);
    console.info(tokenIds);
    console.info(amounts);
    expect(data.id).to.equal(redemptionId);
  });
});
