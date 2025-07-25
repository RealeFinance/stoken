const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("SAmMMF", function () {
  let SAmMMF, sAmMMF, owner, admin, user, other, usdc, usdt;

  beforeEach(async function () {
    [owner, admin, user, other] = await ethers.getSigners();

    // Deploy mock ERC20 tokens for USDC and USDT
    const MockERC20 = await ethers.getContractFactory("Oracle");
    usdc = await MockERC20.deploy();
    await usdc.waitForDeployment();
    usdt = await MockERC20.deploy();
    await usdt.waitForDeployment();

    // Deploy SAmMMF contract
    const SAmMMFFactory = await ethers.getContractFactory("SAmMMF");
    sAmMMF = await upgrades.deployProxy(
      SAmMMFFactory,
      [
        "Staked AmMMF",
        "sAmMMF",
        await usdc.getAddress(),
        await usdt.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await sAmMMF.waitForDeployment();

    // Grant STOKEN_ADMIN role to admin
    const STOKEN_ADMIN = await sAmMMF.STOKEN_ADMIN();
    await sAmMMF.grantRole(STOKEN_ADMIN, admin.address);
  });

  it("should initialize correctly", async function () {
    expect(await sAmMMF.name()).to.equal("Staked AmMMF");
    expect(await sAmMMF.symbol()).to.equal("sAmMMF");
    expect(await sAmMMF.getAssetRecipient()).to.equal(sAmMMF.target);
    expect(await sAmMMF.getTechnicalServiceFeeRate()).to.equal(10);
    const supported = await sAmMMF.getSupportedTokenAddresses();
    expect(supported).to.include(await usdc.getAddress());
    expect(supported).to.include(await usdt.getAddress());
  });

  it("should allow admin to set technical service fee rate", async function () {
    await sAmMMF.connect(admin).setTechnicalServiceFeeRate(50);
    expect(await sAmMMF.getTechnicalServiceFeeRate()).to.equal(50);
  });

  it("should revert setTechnicalServiceFeeRate if not admin", async function () {
    await expect(
      sAmMMF.connect(user).setTechnicalServiceFeeRate(20)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
  });

  it("should allow admin to set asset recipient", async function () {
    await sAmMMF.connect(admin).setAssetRecipient(user.address);
    expect(await sAmMMF.getAssetRecipient()).to.equal(user.address);
  });

  it("should revert setAssetRecipient to zero address", async function () {
    await expect(
      sAmMMF.connect(admin).setAssetRecipient(ethers.ZeroAddress)
    ).to.be.revertedWith("Invalid address");
  });

  it("should allow admin to pause and unpause", async function () {
    await sAmMMF.connect(admin).pause();
    expect(await sAmMMF.paused()).to.be.true;
    await sAmMMF.connect(admin).unpause();
    expect(await sAmMMF.paused()).to.be.false;
  });

  it("should revert pause/unpause if not admin", async function () {
    await expect(sAmMMF.connect(user).pause()).to.be.revertedWithCustomError(
      sAmMMF,
      "AccessControlUnauthorizedAccount"
    );
    await sAmMMF.connect(admin).pause();
    await expect(sAmMMF.connect(user).unpause()).to.be.revertedWithCustomError(
      sAmMMF,
      "AccessControlUnauthorizedAccount"
    );
    await sAmMMF.connect(admin).unpause();
  });

  it("should allow onChainSubscribe and overwriteOnChainSubscribe", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);

    // Find subscriptionId (simulate as in contract)
    const filter = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = filter[0].args.subscriptionId;

    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
  });

  it("should revert onChainSubscribe with unsupported token", async function () {
    const MockERC20 = await ethers.getContractFactory("Oracle");
    const fake = await MockERC20.deploy();
    await fake.waitForDeployment();
    await fake.mint(user.address, 1000);
    await fake.connect(user).approve(sAmMMF.target, 1000);
    await expect(
      sAmMMF.connect(user).onChainSubscribe(await fake.getAddress(), 1000)
    ).to.be.revertedWith("Unsupported token address");
  });

  it("should revert onChainSubscribe with zero amount", async function () {
    await expect(
      sAmMMF.connect(user).onChainSubscribe(await usdc.getAddress(), 0)
    ).to.be.revertedWith("Amount must be greater than zero");
  });

  it("should allow admin to subscribe", async function () {
    await sAmMMF
      .connect(admin)
      .subscribe(
        1000,
        await usdc.getAddress(),
        100,
        user.address,
        1,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
  });

  it("should revert subscribe with zero stokenAmount", async function () {
    await expect(
      sAmMMF
        .connect(admin)
        .subscribe(
          1000,
          await usdc.getAddress(),
          0,
          user.address,
          1,
          Math.floor(Date.now() / 1000),
          ethers.keccak256(ethers.toUtf8Bytes("txhash")),
          "offchainid"
        )
    ).to.be.revertedWith("Stoken amount must be greater than zero");
  });

  it("should revert subscribe with zero user", async function () {
    await expect(
      sAmMMF
        .connect(admin)
        .subscribe(
          1000,
          await usdc.getAddress(),
          100,
          ethers.ZeroAddress,
          1,
          Math.floor(Date.now() / 1000),
          ethers.keccak256(ethers.toUtf8Bytes("txhash")),
          "offchainid"
        )
    ).to.be.revertedWith("Invalid user address");
  });

  it("should allow onChainRedemption and overwriteOnChainRedemption", async function () {
    // Prepare subscription and mint tokens
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    // Redemption
    await sAmMMF.connect(user).onChainRedemption(await usdc.getAddress(), 1000);
    const redEvent = await sAmMMF.queryFilter("onChainRedemptionEvent");
    const redId = redEvent[0].args.redemptionId;

    await sAmMMF
      .connect(admin)
      .overwriteOnChainRedemption(
        redId,
        1000,
        1,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash"))
      );
  });

  it("should revert onChainRedemption with zero amount", async function () {
    await expect(
      sAmMMF.connect(user).onChainRedemption(await usdc.getAddress(), 0)
    ).to.be.revertedWith("Amount must be greater than zero");
  });

  it("should revert onChainRedemption with unsupported token", async function () {
    const MockERC20 = await ethers.getContractFactory("Oracle");
    const fake = await MockERC20.deploy();
    await fake.waitForDeployment();
    await expect(
      sAmMMF.connect(user).onChainRedemption(await fake.getAddress(), 100)
    ).to.be.revertedWith("Unsupported token address");
  });

  it("should revert overwriteOnChainRedemption with zero uAmount", async function () {
    // Prepare redemptionId
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);
    await sAmMMF.connect(user).onChainRedemption(await usdc.getAddress(), 1000);
    const redEvent = await sAmMMF.queryFilter("onChainRedemptionEvent");
    const redId = redEvent[0].args.redemptionId;

    await expect(
      sAmMMF
        .connect(admin)
        .overwriteOnChainRedemption(
          redId,
          0,
          1,
          Math.floor(Date.now() / 1000),
          ethers.keccak256(ethers.toUtf8Bytes("txhash"))
        )
    ).to.be.revertedWith("USDT amount must be greater than zero");
  });

  it("should allow admin to removeRedemptionData", async function () {
    // Prepare redemptionId
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);
    await sAmMMF.connect(user).onChainRedemption(await usdc.getAddress(), 1000);
    const redEvent = await sAmMMF.queryFilter("onChainRedemptionEvent");
    const redId = redEvent[0].args.redemptionId;

    await sAmMMF.connect(admin).removeRedemptionData(redId);
  });

  it("should revert removeRedemptionData with invalid id", async function () {
    await expect(
      sAmMMF.connect(admin).removeRedemptionData(0)
    ).to.be.revertedWith("Invalid redemption ID");
  });

  it("should allow admin to execute and claim", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    // New subscription for claim
    await usdc.mint(user.address, 100000);
    await usdc.connect(user).approve(sAmMMF.target, 100000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 100000);
    const subEvent2 = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId2 = subEvent2[subEvent2.length - 1].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId2,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(user).claim(subId2);
  });

  it("should revert claim if not subscriber", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await expect(sAmMMF.connect(other).claim(subId)).to.be.revertedWith(
      "Only the subscriber can claim"
    );
  });

  it("should allow admin to burn", async function () {
    // Prepare redemptionId
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);
    await sAmMMF.connect(user).onChainRedemption(await usdc.getAddress(), 1000);
    const redEvent = await sAmMMF.queryFilter("onChainRedemptionEvent");
    const redId = redEvent[0].args.redemptionId;

    await sAmMMF
      .connect(admin)
      .overwriteOnChainRedemption(
        redId,
        1000,
        1,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash"))
      );

    const balance = await sAmMMF.balanceOf(user.address);
    expect(balance).to.equal(0);
  });

  it("should revert burn with invalid id", async function () {
    await expect(sAmMMF.connect(admin).burn(0)).to.be.revertedWith(
      "Invalid redemption ID"
    );
  });

  it("should allow admin to blacklist and unblacklist", async function () {
    await sAmMMF.connect(admin).blacklist(user.address);
    await sAmMMF.connect(admin).unBlacklist(user.address);
  });

  it("should revert blacklist/unBlacklist if not admin", async function () {
    await expect(
      sAmMMF.connect(user).blacklist(other.address)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
    await expect(
      sAmMMF.connect(user).unBlacklist(other.address)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
  });

  it("should allow admin to add/remove supported token address", async function () {
    const MockERC20 = await ethers.getContractFactory("Oracle");
    const fake = await MockERC20.deploy();
    await fake.waitForDeployment();
    await sAmMMF
      .connect(admin)
      .addSupportedTokenAddress(await fake.getAddress());
    let supported = await sAmMMF.getSupportedTokenAddresses();
    expect(supported).to.include(await fake.getAddress());

    await sAmMMF
      .connect(admin)
      .removeSupportedTokenAddress(await fake.getAddress());
    supported = await sAmMMF.getSupportedTokenAddresses();
    expect(supported).to.not.include(await fake.getAddress());
  });

  it("should revert add/remove supported token address with zero address", async function () {
    await expect(
      sAmMMF.connect(admin).addSupportedTokenAddress(ethers.ZeroAddress)
    ).to.be.revertedWith("Invalid address");
    await expect(
      sAmMMF.connect(admin).removeSupportedTokenAddress(ethers.ZeroAddress)
    ).to.be.revertedWith("Invalid address");
  });

  it("should revert removeSupportedTokenAddress if not found", async function () {
    const MockERC20 = await ethers.getContractFactory("Oracle");
    const fake = await MockERC20.deploy();
    await fake.waitForDeployment();
    await expect(
      sAmMMF.connect(admin).removeSupportedTokenAddress(await fake.getAddress())
    ).to.be.revertedWith("Token address not found");
  });

  it("should return balanceOf and balanceOfWithId", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    const balance = await sAmMMF.balanceOf(user.address);
    expect(balance).to.equal(1000);

    const [tokenIds, amounts] = await sAmMMF.balanceOfWithId(user.address);
    expect(tokenIds.length).to.equal(amounts.length);
    expect(tokenIds.length).to.equal(1);
  });

  it("should allow transfer and transferFrom", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    await sAmMMF.connect(user).approve(other.address, 1000);
    await sAmMMF.connect(user).transfer(other.address, 500);
    await sAmMMF.connect(other).transferFrom(user.address, admin.address, 200);
  });

  it("should revert transfer if blacklisted", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    await sAmMMF.connect(admin).blacklist(user.address);
    await expect(
      sAmMMF.connect(user).transfer(other.address, 100)
    ).to.be.revertedWith("Blacklistable: account is blacklisted");
  });

  it("should revert transferFrom if blacklisted", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    await sAmMMF.connect(user).approve(other.address, 1000);
    await sAmMMF.connect(admin).blacklist(user.address);
    await expect(
      sAmMMF.connect(other).transferFrom(user.address, admin.address, 100)
    ).to.be.revertedWith("Blacklistable: account is blacklisted");
  });

  it("should revert transfer if paused", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    await sAmMMF.connect(admin).pause();
    await expect(
      sAmMMF.connect(user).transfer(other.address, 100)
    ).to.be.revertedWithCustomError(sAmMMF, "EnforcedPause");
    await sAmMMF.connect(admin).unpause();
  });

  // Add more tests for getTokenData, getTokenDataByRedemptionId, etc. as needed
  it("getTokenData", async function () {
    await usdc.mint(user.address, 1000000);
    await usdc.connect(user).approve(sAmMMF.target, 1000000);
    await sAmMMF
      .connect(user)
      .onChainSubscribe(await usdc.getAddress(), 1000000);
    const subEvent = await sAmMMF.queryFilter("onChainSubscribeEvent");
    const subId = subEvent[0].args.subscriptionId;
    await sAmMMF
      .connect(admin)
      .overwriteOnChainSubscribe(
        subId,
        100,
        1000,
        Math.floor(Date.now() / 1000),
        ethers.keccak256(ethers.toUtf8Bytes("txhash")),
        "offchainid"
      );
    await sAmMMF.connect(admin).execute(subId);

    const [tokenIds, amounts] = await sAmMMF.balanceOfWithId(user.address);
    // console.log("Token IDs:", tokenIds);
    await sAmMMF
      .connect(admin)
      .getTokenData([...tokenIds])
      .then(async (data) => {
        console.log("Token Data:", data);
      });
  });
});
