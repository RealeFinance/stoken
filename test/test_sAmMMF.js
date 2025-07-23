const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("SAmMMF", function () {
  let SAmMMF, sAmMMF, owner, user, admin, stokenAdmin, usdc, usdt;

  beforeEach(async function () {
    [owner, user, admin, stokenAdmin] = await ethers.getSigners();
    // deploy a simple ERC20 mintable token as mock USDC/USDT
    const MockERC20 = await ethers.getContractFactory("Oracle");
    usdc = await MockERC20.deploy();
    usdt = await MockERC20.deploy();
    await usdc.waitForDeployment();
    await usdt.waitForDeployment();

    const SAmMMFFactory = await ethers.getContractFactory("SAmMMF"); 
    sAmMMF = await upgrades.deployProxy(
      SAmMMFFactory,
      ["Staked AmMMF", "sAmMMF"],
      { initializer: "initialize" }
    );
    await sAmMMF.waitForDeployment();

    const STOKEN_ADMIN = await sAmMMF.STOKEN_ADMIN();
    await sAmMMF.connect(owner).grantRole(STOKEN_ADMIN, stokenAdmin.address);
    await sAmMMF
      .connect(stokenAdmin)
      .addSupportedTokenAddress(await usdc.getAddress());
    await sAmMMF
      .connect(stokenAdmin)
      .addSupportedTokenAddress(await usdt.getAddress());
  });

  it("initializes correctly", async function () {
    expect(await sAmMMF.name()).to.equal("Staked AmMMF");
    expect(await sAmMMF.symbol()).to.equal("sAmMMF");
    expect(await sAmMMF.getAssetRecipient()).to.equal(
      await sAmMMF.getAddress()
    );
    expect(await sAmMMF.getTechnicalServiceFeeRate()).to.equal(10);
    const list = await sAmMMF.getSupportedTokenAddresses();
    expect(list).to.include(await usdc.getAddress());
    expect(list).to.include(await usdt.getAddress());
  });

  it("pause/unpause by admin only", async function () {
    await sAmMMF.connect(owner).pause();
    expect(await sAmMMF.paused()).to.equal(true);
    await sAmMMF.connect(owner).unpause();
    expect(await sAmMMF.paused()).to.equal(false);
    await expect(sAmMMF.connect(user).pause()).to.be.revertedWithCustomError(
      sAmMMF,
      "AccessControlUnauthorizedAccount"
    );
  });

  it("setTechnicalServiceFeeRate and revert", async function () {
    await sAmMMF.connect(stokenAdmin).setTechnicalServiceFeeRate(50);
    expect(await sAmMMF.getTechnicalServiceFeeRate()).to.equal(50);
    await expect(
      sAmMMF.connect(user).setTechnicalServiceFeeRate(20)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
  });

  it("setAssetRecipient and invalid", async function () {
    await sAmMMF.connect(stokenAdmin).setAssetRecipient(user.address);
    expect(await sAmMMF.getAssetRecipient()).to.equal(user.address);
    await expect(
      sAmMMF.connect(stokenAdmin).setAssetRecipient(ethers.ZeroAddress)
    ).to.be.revertedWith("Invalid address");
  });

  it("onChainSubscribe happy path and unsupported/zero", async function () {
    await usdc.mint(user.address, 1_000_000);
    await usdc.connect(user).approve(await sAmMMF.getAddress(), 1_000_000);
    await expect(
      sAmMMF.connect(user).onChainSubscribe(await usdc.getAddress(), 500_000)
    ).to.emit(sAmMMF, "onChainSubscribeEvent");
    expect(await usdc.balanceOf(await sAmMMF.getAddress())).to.equal(500_000);

    const fake = await (await ethers.getContractFactory("Oracle")).deploy();
    await fake.waitForDeployment();
    await expect(
      sAmMMF.connect(user).onChainSubscribe(await fake.getAddress(), 100)
    ).to.be.revertedWith("Unsupported token address");

    await expect(
      sAmMMF.connect(user).onChainSubscribe(await usdc.getAddress(), 0)
    ).to.be.revertedWith("Amount must be greater than zero");
  });

  it("add/remove supported token and invalids", async function () {
    const New = await (await ethers.getContractFactory("Oracle")).deploy();
    await New.waitForDeployment();
    await sAmMMF
      .connect(stokenAdmin)
      .addSupportedTokenAddress(await New.getAddress());
    let list = await sAmMMF.getSupportedTokenAddresses();
    expect(list).to.include(await New.getAddress());
    await sAmMMF
      .connect(stokenAdmin)
      .removeSupportedTokenAddress(await New.getAddress());
    list = await sAmMMF.getSupportedTokenAddresses();
    expect(list).to.not.include(await New.getAddress());

    await expect(
      sAmMMF.connect(stokenAdmin).addSupportedTokenAddress(ethers.ZeroAddress)
    ).to.be.revertedWith("Invalid address");
    await expect(
      sAmMMF
        .connect(stokenAdmin)
        .removeSupportedTokenAddress(ethers.ZeroAddress)
    ).to.be.revertedWith("Invalid address");

    const Fake = await (await ethers.getContractFactory("Oracle")).deploy();
    await Fake.waitForDeployment();
    await expect(
      sAmMMF
        .connect(stokenAdmin)
        .removeSupportedTokenAddress(await Fake.getAddress())
    ).to.be.revertedWith("Token address not found");
  });

  it("subscribe and invalids", async function () {
    await expect(
      sAmMMF
        .connect(stokenAdmin)
        .subscribe(
          1000,
          await usdc.getAddress(),
          100,
          user.address,
          1,
          ethers.ZeroHash,
          ethers.ZeroHash,
          "id"
        )
    ).to.emit(sAmMMF, "subscribeEvent");

    await expect(
      sAmMMF
        .connect(stokenAdmin)
        .subscribe(
          1000,
          await usdc.getAddress(),
          0,
          user.address,
          1,
          ethers.ZeroHash,
          ethers.ZeroHash,
          "id"
        )
    ).to.be.revertedWith("Stoken amount must be greater than zero");

    await expect(
      sAmMMF
        .connect(stokenAdmin)
        .subscribe(
          1000,
          await usdc.getAddress(),
          100,
          ethers.ZeroAddress,
          1,
          ethers.ZeroHash,
          ethers.ZeroHash,
          "id"
        )
    ).to.be.revertedWith("Invalid user address");
  });

  it("onChainRedemption and invalids", async function () {
    await expect(
      sAmMMF.connect(user).onChainRedemption(await usdc.getAddress(), 200)
    ).to.emit(sAmMMF, "onChainRedemptionEvent");

    await expect(
      sAmMMF.connect(user).onChainRedemption(await usdc.getAddress(), 0)
    ).to.be.revertedWith("Amount must be greater than zero");

    const Fake = await (await ethers.getContractFactory("Oracle")).deploy();
    await Fake.waitForDeployment();
    await expect(
      sAmMMF.connect(user).onChainRedemption(await Fake.getAddress(), 100)
    ).to.be.revertedWith("Unsupported token address");
  });

  it("overwriteOnChainSubscribe and invalid", async function () {
    const subId = ethers.keccak256(ethers.toUtf8Bytes("test"));
    await expect(
      sAmMMF
        .connect(stokenAdmin)
        .overwriteOnChainSubscribe(
          subId,
          1000,
          await usdc.getAddress(),
          50,
          user.address,
          1,
          ethers.ZeroHash,
          ethers.ZeroHash,
          "off"
        )
    ).to.emit(sAmMMF, "overwriteOnChainSubscribeEvent");

    await expect(
      sAmMMF
        .connect(stokenAdmin)
        .overwriteOnChainSubscribe(
          subId,
          1000,
          await usdc.getAddress(),
          0,
          user.address,
          1,
          ethers.ZeroHash,
          ethers.ZeroHash,
          "off"
        )
    ).to.be.revertedWith("Stoken amount must be greater than zero");
  });

  it("execute/mint tokens", async function () {
    const tx = await sAmMMF
      .connect(stokenAdmin)
      .subscribe(
        1000,
        await usdc.getAddress(),
        100,
        user.address,
        1,
        ethers.ZeroHash,
        ethers.ZeroHash,
        "id"
      );
    const receipt = await tx.wait();
    const evt = receipt.logs
      .map((l) => sAmMMF.interface.parseLog(l))
      .find((l) => l.name === "subscribeEvent");
    const subId = evt.args[0];

    await expect(sAmMMF.connect(stokenAdmin).execute(subId)).to.emit(
      sAmMMF,
      "executeEvent"
    );
    expect(await sAmMMF.balanceOf(user.address)).to.equal(100);
  });

  it("claim and invalid", async function () {
    const tx = await sAmMMF
      .connect(stokenAdmin)
      .subscribe(
        1000,
        await usdc.getAddress(),
        100,
        user.address,
        1,
        ethers.ZeroHash,
        ethers.ZeroHash,
        "id"
      );
    const receipt = await tx.wait();
    const subId = sAmMMF.interface.parseLog(receipt.logs[0]).args[0];

    await expect(sAmMMF.connect(user).claim(subId)).to.emit(
      sAmMMF,
      "claimEvent"
    );
    expect(await sAmMMF.balanceOf(user.address)).to.equal(100);

    await expect(sAmMMF.connect(admin).claim(subId)).to.be.revertedWith(
      "Only the subscriber can claim"
    );
  });

  it("transfer / transferFrom and blacklisting", async function () {
    // subscribe & execute
    const tx = await sAmMMF
      .connect(stokenAdmin)
      .subscribe(
        1000,
        await usdc.getAddress(),
        100,
        user.address,
        1,
        ethers.ZeroHash,
        ethers.ZeroHash,
        "id"
      );
    const subId = sAmMMF.interface.parseLog((await tx.wait()).logs[0]).args[0];
    await sAmMMF.connect(stokenAdmin).execute(subId);

    await sAmMMF.connect(user).transfer(admin.address, 50);
    expect(await sAmMMF.balanceOf(admin.address)).to.equal(50);

    await sAmMMF.connect(admin).approve(user.address, 50);
    await sAmMMF.connect(user).transferFrom(admin.address, user.address, 20);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(70);

    // blacklist user
    await sAmMMF.connect(stokenAdmin).blacklist(user.address);
    await expect(
      sAmMMF.connect(user).transfer(admin.address, 10)
    ).to.be.revertedWith("Blacklistable: account is blacklisted");

    // blacklist transferFrom caller
    await sAmMMF.connect(admin).approve(user.address, 20);
    await sAmMMF.connect(stokenAdmin).blacklist(admin.address);
    await expect(
      sAmMMF.connect(admin).transferFrom(user.address, admin.address, 10)
    ).to.be.revertedWith("Blacklistable: account is blacklisted");
  });

  it("burn and invalid", async function () {
    const tx = await sAmMMF
      .connect(stokenAdmin)
      .subscribe(
        1000,
        await usdc.getAddress(),
        100,
        user.address,
        1,
        ethers.ZeroHash,
        ethers.ZeroHash,
        "id"
      );
    const subId = sAmMMF.interface.parseLog((await tx.wait()).logs[0]).args[0];
    await sAmMMF.connect(stokenAdmin).execute(subId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(100);
    const tx1 = await sAmMMF
      .connect(stokenAdmin)
      .redemption(
        1000,
        await usdc.getAddress(),
        10,
        user.address,
        1,
        ethers.ZeroHash,
        ethers.ZeroHash,
        "id"
      );
    const redId = sAmMMF.interface.parseLog((await tx1.wait()).logs[0]).args[0];
    await sAmMMF.connect(stokenAdmin).burn(redId);
    expect(await sAmMMF.balanceOf(user.address)).to.equal(90);

    // not admin
    await expect(
      sAmMMF.connect(user).burn(redId)
    ).to.be.revertedWithCustomError(sAmMMF, "AccessControlUnauthorizedAccount");
  });

  it("getTokenData & getTokenDataByRedemptionId", async function () {
    const tx = await sAmMMF
      .connect(stokenAdmin)
      .subscribe(
        1000,
        await usdc.getAddress(),
        100,
        user.address,
        1,
        ethers.ZeroHash,
        ethers.ZeroHash,
        "id"
      );
    const subId = sAmMMF.interface.parseLog((await tx.wait()).logs[0]).args[0];
    await sAmMMF.connect(stokenAdmin).execute(subId);

    // token data by id list
    const tokenIds = await sAmMMF.balanceOfWithId(user.address);
    const tokenIdList = Array.isArray(tokenIds[0])
      ? [...tokenIds[0]]
      : [tokenIds[0]];
    const data = await sAmMMF.connect(stokenAdmin).getTokenData(tokenIdList);

    expect(data.length).to.be.greaterThan(0);
    expect(data[0].id.toString()).to.equal(tokenIds[0].toString());

    const tx1 = await sAmMMF
      .connect(stokenAdmin)
      .redemption(
        1000,
        await usdc.getAddress(),
        100,
        user.address,
        1,
        ethers.ZeroHash,
        ethers.ZeroHash,
        "id"
      );
    const redId = sAmMMF.interface.parseLog((await tx1.wait()).logs[0]).args[0];
    await sAmMMF.connect(stokenAdmin).burn(redId);

    const redDataList = await sAmMMF
      .connect(stokenAdmin)
      .getTokenDataByRedemptionId(redId);
    const redData = redDataList[0];
    // console.log("测试前准备 - 所有者地址1:", redData);
    // expect(redData.id.toString()).to.equal(redId.toString());
    expect(redData.mintTime).to.equal(ethers.ZeroHash);
  });
});
