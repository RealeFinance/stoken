const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const parseUnits = ethers.parseUnits;

describe("SAmMMF", function () {
  let SAmMMF, sAmMMF, owner, user, admin, other, otherfee, usdc, usdt;
  const NAME = "Staked AmMMF";
  const SYMBOL = "sAmMMF";

  beforeEach(async function () {
    [owner, user, admin, other, otherfee] = await ethers.getSigners();

    // Deploy mock ERC20 tokens for USDC and USDT
    const MockERC20 = await ethers.getContractFactory("Oracle");
    usdc = await MockERC20.deploy();
    usdt = await MockERC20.deploy();
    await usdc.waitForDeployment();
    await usdt.waitForDeployment();

    // Deploy SAmMMF contract
    const SAmMMFFactory = await ethers.getContractFactory("SAmMMF");
    sAmMMF = await upgrades.deployProxy(
      SAmMMFFactory,
      [NAME, SYMBOL],
      { initializer: "initialize" }
    );
    await sAmMMF.waitForDeployment();

    // Grant STOKEN_ADMIN role to admin
    const STOKEN_ADMIN = await sAmMMF.STOKEN_ADMIN();
    await sAmMMF.grantRole(STOKEN_ADMIN, admin.address);
  });

  it("should initialize correctly", async function () {
    expect(await sAmMMF.name()).to.equal(NAME);
    expect(await sAmMMF.symbol()).to.equal(SYMBOL);
    expect(
      await sAmMMF.hasRole(await sAmMMF.DEFAULT_ADMIN_ROLE(), owner.address)
    ).to.be.true;
    expect(await sAmMMF.hasRole(await sAmMMF.STOKEN_ADMIN(), owner.address)).to
      .be.false;
  });

  // describe("Subscription", function () {
  //   it("should allow onChainSubscribe with supported token", async function () {
  //     await usdc.mint(user.address, ethers.parseUnits("100", 18));
  //     await usdc
  //       .connect(user)
  //       .approve(sAmMMF.getAddress(), ethers.parseUnits("100", 18));
  //     await expect(
  //       sAmMMF
  //         .connect(user)
  //         .onChainSubscribe(
  //           await usdc.getAddress(),
  //           ethers.parseUnits("100", 18),
  //           1
  //         )
  //     ).to.emit(sAmMMF, "onChainSubscribeEvent");
  //   });

  //   it("should revert onChainSubscribe with unsupported token", async function () {
  //     const MockERC20 = await ethers.getContractFactory("Oracle");
  //     const fakeToken = await MockERC20.deploy();
  //     await expect(
  //       sAmMMF
  //         .connect(user)
  //         .onChainSubscribe(await fakeToken.getAddress(), 1000, 1)
  //     ).to.be.revertedWith("Unsupported token address");
  //   });

  //   it("should revert onChainSubscribe with zero amount", async function () {
  //     await expect(
  //       sAmMMF.connect(user).onChainSubscribe(await usdc.getAddress(), 0, 1)
  //     ).to.be.revertedWith("Amount must be greater than zero");
  //   });

  //   it("should allow overwriteOnChainSubscribe by admin", async function () {
  //     await usdc.mint(user.address, 1000000);
  //     await usdc.connect(user).approve(sAmMMF.getAddress(), 1000000);
  //     const tx = await sAmMMF
  //       .connect(user)
  //       .onChainSubscribe(await usdc.getAddress(), 1000000, 1);
  //     const receipt = await tx.wait();
  //     const event = receipt.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "onChainSubscribeEvent");
  //     const subscriptionId = event.args.subscriptionId;
  //     const block = await ethers.provider.getBlock(receipt.blockNumber);

  //     await expect(
  //       sAmMMF
  //         .connect(admin)
  //         .overwriteOnChainSubscribe(
  //           subscriptionId,
  //           100,
  //           1000,
  //           block.timestamp,
  //           ethers.ZeroHash,
  //           "offchainid"
  //         )
  //     ).to.emit(sAmMMF, "overwriteOnChainSubscribeEvent");
  //   });

  //   it("should revert overwriteOnChainSubscribe if not admin", async function () {
  //     await expect(
  //       sAmMMF
  //         .connect(user)
  //         .overwriteOnChainSubscribe(1, 1, 1, 1, ethers.ZeroHash, "id")
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //   });

  //   it("should allow subscribe by admin", async function () {
  //     await expect(
  //       sAmMMF
  //         .connect(admin)
  //         .subscribe(
  //           1000,
  //           await usdc.getAddress(),
  //           100,
  //           user.address,
  //           10,
  //           123456,
  //           ethers.ZeroHash,
  //           "offchainid"
  //         )
  //     ).to.emit(sAmMMF, "subscribeEvent");
  //   });

  //   it("should revert subscribe with zero stokenAmount", async function () {
  //     await expect(
  //       sAmMMF
  //         .connect(admin)
  //         .subscribe(
  //           1000,
  //           await usdc.getAddress(),
  //           0,
  //           user.address,
  //           10,
  //           123456,
  //           ethers.ZeroHash,
  //           "offchainid"
  //         )
  //     ).to.be.revertedWith("Stoken amount must be greater than zero");
  //   });

  //   it("should revert subscribe if not admin", async function () {
  //     await expect(
  //       sAmMMF
  //         .connect(user)
  //         .subscribe(
  //           1000,
  //           await usdc.getAddress(),
  //           100,
  //           user.address,
  //           10,
  //           123456,
  //           ethers.ZeroHash,
  //           "offchainid"
  //         )
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //   });
  // });

  // describe("Redemption", function () {
  //   it("onChainRedemption", async function () {
  //     await usdc.mint(user.address, ethers.parseUnits("100", 18));
  //     await usdc
  //       .connect(user)
  //       .approve(sAmMMF.getAddress(), ethers.parseUnits("100", 18));
  //     const tx = await sAmMMF
  //       .connect(user)
  //       .onChainSubscribe(
  //         await usdc.getAddress(),
  //         ethers.parseUnits("100", 18),
  //         1
  //       );
  //     const receipt = await tx.wait();
  //     const event = receipt.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "onChainSubscribeEvent");
  //     const subscriptionId = event.args.subscriptionId;
  //     const block = await ethers.provider.getBlock(receipt.blockNumber);
  //     await sAmMMF
  //       .connect(admin)
  //       .overwriteOnChainSubscribe(
  //         subscriptionId,
  //         ethers.parseUnits("1000", 18),
  //         ethers.parseUnits("100", 18),
  //         1754209046,
  //         ethers.ZeroHash,
  //         "offchainid"
  //       );

  //     await sAmMMF.connect(admin).execute(subscriptionId);
  //     const balance = await sAmMMF.connect(user).balanceOf(user.address);
  //     console.log("Balance after subscribe:", ethers.formatUnits(balance, 18));
  //     const balance1 = await usdc.connect(user).balanceOf(user.address);
  //     console.log(
  //       "USDC Balance after subscribe:",
  //       ethers.formatUnits(balance1, 6)
  //     );

  //     const tx1 = await sAmMMF
  //       .connect(user)
  //       .onChainRedemption(
  //         await usdc.getAddress(),
  //         ethers.parseUnits("10", 18),
  //         1
  //       );
  //     const receipt1 = await tx1.wait();
  //     const event1 = receipt1.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "onChainRedemptionEvent");
  //     const redemptionId = event1.args.redemptionId;
  //     const balance2 = await sAmMMF.connect(user).balanceOf(user.address);
  //     console.log("Balance after subscribe:", ethers.formatUnits(balance2, 18));
  //     const [tokenIds, amounts] = await sAmMMF
  //       .connect(user)
  //       .balanceOfWithId(user.address);
  //     console.log("Balance after subscribe:", tokenIds);
  //     console.log("Balance after subscribe:", amounts);
  //     const data = await sAmMMF
  //       .connect(user)
  //       .getTokenData(Array.from(tokenIds));
  //     console.log("Token Data:", data);
  //     console.log("Token Data:", redemptionId);

  //     const receipt2 = await (
  //       await sAmMMF.connect(admin).overwriteOnChainRedemption(
  //         redemptionId,
  //         ethers.parseUnits("10", 6), //usdc amount
  //         ethers.parseUnits("1000", 18), // price
  //         1754209046 + 1,
  //         ethers.ZeroHash
  //       )
  //     ).wait();

  //     const overwriteEvent = receipt2.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "overwriteOnChainRedemptionEvent");

  //     const technicalServiceFee = overwriteEvent.args.technicalServiceFee;
  //     const tokenTransferDetails = overwriteEvent.args.tokenTransferDetails;
  //     console.log(
  //       "technicalServiceFee:",
  //       ethers.formatUnits(technicalServiceFee, 18)
  //     );
  //     console.log("tokenTransferDetails:", tokenTransferDetails);

  //     await sAmMMF.connect(admin).setAssetSender(other.address);
  //     await sAmMMF.connect(admin).setServiceFeeRecipient(otherfee.address);
  //     const assetSender = await sAmMMF.assetSender();
  //     const serviceFeeRecipient = await sAmMMF.serviceFeeRecipient();
  //     console.log("assetSender:", assetSender);
  //     console.log("serviceFeeRecipient:", serviceFeeRecipient);

  //     await usdc.mint(other.address, ethers.parseUnits("10", 6));
  //     await usdc
  //       .connect(other)
  //       .approve(sAmMMF.getAddress(), ethers.parseUnits("10", 6));

  //     await sAmMMF.connect(user).claimUSD(redemptionId);

  //     const fee = await usdc.connect(otherfee).balanceOf(otherfee.address);
  //     console.log("Fee:", ethers.formatUnits(fee, 6));
  //     const balance3 = await usdc.connect(user).balanceOf(user.address);
  //     console.log(
  //       "USDC Balance after redemption:",
  //       ethers.formatUnits(balance3, 6)
  //     );
  //   });

  //   it("offChainRedemption", async function () {
  //     await usdc.mint(user.address, ethers.parseUnits("200", 18));
  //     await usdc
  //       .connect(user)
  //       .approve(sAmMMF.getAddress(), ethers.parseUnits("200", 18));

  //     const tx = await sAmMMF.connect(admin).subscribe(
  //       ethers.parseUnits("100", 18),
  //       await usdc.getAddress(),
  //       ethers.parseUnits("100", 18),
  //       user.address,
  //       ethers.parseUnits("1000", 18), //price
  //       1754209046,
  //       ethers.ZeroHash,
  //       "offchainid"
  //     );
  //     const receipt = await tx.wait();
  //     const event = receipt.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "subscribeEvent");
  //     const subscriptionId = event.args.subscriptionId;
  //     console.log("Subscription ID:", subscriptionId);

  //     await sAmMMF.connect(admin).execute(subscriptionId);
  //     const balance = await sAmMMF.connect(user).balanceOf(user.address);
  //     console.log("Balance after subscribe:", ethers.formatUnits(balance, 18));

  //     const tx3 = await sAmMMF.connect(admin).subscribe(
  //       ethers.parseUnits("100", 18),
  //       await usdc.getAddress(),
  //       ethers.parseUnits("100", 18),
  //       user.address,
  //       ethers.parseUnits("1000", 18), //price
  //       1754209046,
  //       ethers.ZeroHash,
  //       "offchainid"
  //     );
  //     const receipt3 = await tx3.wait();
  //     const event3 = receipt3.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "subscribeEvent");
  //     const subscriptionId1 = event3.args.subscriptionId;
  //     console.log("Subscription ID:", subscriptionId);

  //     await sAmMMF.connect(admin).execute(subscriptionId1);
  //     const balance3 = await sAmMMF.connect(user).balanceOf(user.address);
  //     console.log("Balance after subscribe:", ethers.formatUnits(balance3, 18));

  //     const tx1 = await sAmMMF.connect(admin).redemption(
  //       ethers.parseUnits("10", 18),
  //       await usdc.getAddress(),
  //       ethers.parseUnits("120", 18),
  //       user.address,
  //       ethers.parseUnits("1000", 18), //price
  //       1754209046 + 84600,
  //       ethers.ZeroHash,
  //       "offchainid"
  //     );
  //     const receipt1 = await tx1.wait();
  //     const event1 = receipt1.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "RedemptionEvent");
  //     const redemptionId = event1.args.redemptionId;
  //     console.log("Redemption ID:", redemptionId);

  //     const tx2 = await sAmMMF.connect(admin).burn(redemptionId);
  //     const receipt2 = await tx2.wait();
  //     const event2 = receipt2.logs
  //       .map((log) => {
  //         try {
  //           return sAmMMF.interface.parseLog(log);
  //         } catch {
  //           return null;
  //         }
  //       })
  //       .find((e) => e && e.name === "burnEvent");
  //     const technicalServiceFee = event2.args.technicalServiceFee;
  //     const tokenTransferDetails = event2.args.tokenTransferDetails;
  //     console.log(
  //       "Technical Service Fee:",
  //       ethers.formatUnits(technicalServiceFee, 18)
  //     );
  //     console.log("burnEvent tokenTransferDetails:", tokenTransferDetails);
  //     const balance2 = await sAmMMF.connect(user).balanceOf(user.address);
  //     console.log(
  //       "Balance after redemption:",
  //       ethers.formatUnits(balance2, 18)
  //     );
  //   });
  // });

  // describe("Pause/Unpause", function () {
  //   it("should allow admin to pause and unpause", async function () {
  //     await sAmMMF.connect(admin).pause();
  //     expect(await sAmMMF.paused()).to.be.true;
  //     await sAmMMF.connect(admin).unpause();
  //     expect(await sAmMMF.paused()).to.be.false;
  //   });

  //   it("should revert pause/unpause if not admin", async function () {
  //     await expect(sAmMMF.connect(user).pause()).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await sAmMMF.connect(admin).pause();
  //     await expect(
  //       sAmMMF.connect(user).unpause()
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await sAmMMF.connect(admin).unpause();
  //   });

  //   it("should revert subscribe when paused", async function () {
  //     await sAmMMF.connect(admin).pause();
  //     await expect(
  //       sAmMMF
  //         .connect(admin)
  //         .subscribe(
  //           1000,
  //           await usdc.getAddress(),
  //           100,
  //           user.address,
  //           10,
  //           123456,
  //           ethers.ZeroHash,
  //           "offchainid"
  //         )
  //     ).to.be.revertedWithCustomError(sAmMMF, "EnforcedPause");
  //     await sAmMMF.connect(admin).unpause();
  //   });
  // });

  // describe("Blacklist", function () {
  //   it("should allow admin to blacklist and unblacklist", async function () {
  //     await expect(sAmMMF.connect(admin).blacklist(user.address)).to.emit(
  //       sAmMMF,
  //       "Blacklisted"
  //     );
  //     await expect(sAmMMF.connect(admin).unBlacklist(user.address)).to.emit(
  //       sAmMMF,
  //       "UnBlacklisted"
  //     );
  //   });

  //   it("should revert blacklist/unBlacklist if not admin", async function () {
  //     await expect(
  //       sAmMMF.connect(user).blacklist(other.address)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await expect(
  //       sAmMMF.connect(user).unBlacklist(other.address)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //   });
  // });

  // describe("Token Transfer", function () {
  //   beforeEach(async function () {
  //     // Mint tokens for user via subscribe/execute
  //     await sAmMMF
  //       .connect(admin)
  //       .subscribe(
  //         1000,
  //         await usdc.getAddress(),
  //         100,
  //         user.address,
  //         10,
  //         123456,
  //         ethers.ZeroHash,
  //         "offchainid"
  //       );
  //     const subId = ethers.keccak256(
  //       ethers.solidityPacked(
  //         [
  //           "address",
  //           "uint256",
  //           "address",
  //           "uint256",
  //           "uint256",
  //           "uint256",
  //           "string",
  //         ],
  //         [
  //           user.address,
  //           1000,
  //           await usdc.getAddress(),
  //           100,
  //           10,
  //           123456,
  //           "offchainid",
  //         ]
  //       )
  //     );
  //     await sAmMMF.connect(admin).execute(subId);
  //   });

  //   it("should allow transfer and transferFrom", async function () {
  //     await sAmMMF.connect(user).transfer(other.address, 50);
  //     expect(await sAmMMF.balanceOf(other.address)).to.equal(50);

  //     await sAmMMF.connect(other).approve(user.address, 50);
  //     await sAmMMF.connect(user).transferFrom(other.address, user.address, 50);
  //     expect(await sAmMMF.balanceOf(user.address)).to.equal(100);
  //   });

  //   it("should revert transfer to self", async function () {
  //     await expect(
  //       sAmMMF.connect(user).transfer(user.address, 10)
  //     ).to.be.revertedWith("Cannot transfer to self");
  //   });

  //   it("should revert transfer with zero amount", async function () {
  //     await expect(
  //       sAmMMF.connect(user).transfer(other.address, 0)
  //     ).to.be.revertedWith("Transfer amount must be greater than zero");
  //   });

  //   it("should revert transfer if blacklisted", async function () {
  //     await sAmMMF.connect(admin).blacklist(user.address);
  //     await expect(
  //       sAmMMF.connect(user).transfer(other.address, 10)
  //     ).to.be.revertedWith("Blacklisted");
  //   });
  // });

  // describe("Admin Setters", function () {
  //   it("should allow admin to set technicalServiceFeeRate", async function () {
  //     await sAmMMF.connect(admin).setTechnicalServiceFeeRate(20);
  //     // No revert = success
  //   });

  //   it("should allow admin to set assetRecipient", async function () {
  //     await sAmMMF.connect(admin).setAssetRecipient(other.address);
  //   });

  //   it("should allow admin to set assetSender", async function () {
  //     await sAmMMF.connect(admin).setAssetSender(other.address);
  //   });

  //   it("should allow admin to set serviceFeeRecipient", async function () {
  //     await sAmMMF.connect(admin).setServiceFeeRecipient(other.address);
  //   });

  //   it("should allow admin to add/remove supportedTokenAddress", async function () {
  //     const MockERC20 = await ethers.getContractFactory("Oracle");
  //     const fakeToken = await MockERC20.deploy("Fake", "FAKE", 6);
  //     await sAmMMF
  //       .connect(admin)
  //       .addSupportedTokenAddress(await fakeToken.getAddress());
  //     await sAmMMF
  //       .connect(admin)
  //       .removeSupportedTokenAddress(await fakeToken.getAddress());
  //   });

  //   it("should revert admin setters if not admin", async function () {
  //     await expect(
  //       sAmMMF.connect(user).setTechnicalServiceFeeRate(20)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await expect(
  //       sAmMMF.connect(user).setAssetRecipient(other.address)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await expect(
  //       sAmMMF.connect(user).setAssetSender(other.address)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await expect(
  //       sAmMMF.connect(user).setServiceFeeRecipient(other.address)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await expect(
  //       sAmMMF.connect(user).addSupportedTokenAddress(other.address)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //     await expect(
  //       sAmMMF.connect(user).removeSupportedTokenAddress(other.address)
  //     ).to.be.revertedWithCustomError(
  //       sAmMMF,
  //       "AccessControlUnauthorizedAccount"
  //     );
  //   });
  // });

  // describe("Token Data", function () {
  //   it("should return balanceOfWithId and getTokenData", async function () {
  //     await sAmMMF
  //       .connect(admin)
  //       .subscribe(
  //         1000,
  //         await usdc.getAddress(),
  //         100,
  //         user.address,
  //         10,
  //         123456,
  //         ethers.ZeroHash,
  //         "offchainid"
  //       );
  //     const subId = ethers.keccak256(
  //       ethers.solidityPacked(
  //         [
  //           "address",
  //           "uint256",
  //           "address",
  //           "uint256",
  //           "uint256",
  //           "uint256",
  //           "string",
  //         ],
  //         [
  //           user.address,
  //           1000,
  //           await usdc.getAddress(),
  //           100,
  //           10,
  //           123456,
  //           "offchainid",
  //         ]
  //       )
  //     );
  //     await sAmMMF.connect(admin).execute(subId);

  //     const [tokenIds, amounts] = await sAmMMF.balanceOfWithId(user.address);
  //     expect(tokenIds.length).to.be.greaterThan(0);
  //     expect(amounts[0]).to.equal(100);

  //     const tokenData = await sAmMMF.getTokenData(tokenIds);
  //     expect(tokenData.length).to.equal(tokenIds.length);
  //     expect(tokenData[0].tokenOwner).to.equal(user.address);
  //   });
  // });

  describe("mint/burn", function () {
    it("mint", async function () {

      await sAmMMF.setPoolAdmin(owner.address);
      await sAmMMF.mint(user.address, ethers.parseUnits("100", 18));
      const balance = await sAmMMF.connect(user).balanceOf(user.address);
      console.log("Balance after mint:", ethers.formatUnits(balance, 18));


      await sAmMMF.burnFrom(user.address, ethers.parseUnits("40", 18));      
      const balanceAfterBurn = await sAmMMF.connect(user).balanceOf(user.address);
      console.log("Balance after burn:", ethers.formatUnits(balanceAfterBurn, 18));
    });

    
  });
});
