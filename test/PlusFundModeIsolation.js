const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

function findEvent(receipt, iface, name) {
  return receipt.logs
    .map((log) => {
      try {
        return iface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find((parsed) => parsed?.name === name);
}

describe("PlusFund online/offline mode isolation", function () {
  async function deployFixture() {
    const [owner, user, admin] = await ethers.getSigners();
    const PlusFund = await ethers.getContractFactory("PlusFund");
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    const paymentToken = await MockUSDC.deploy();
    await paymentToken.waitForDeployment();

    const token = await upgrades.deployProxy(
      PlusFund,
      ["PlusFund", "PLUS"],
      { initializer: "initialize" },
    );
    await token.waitForDeployment();

    const stokenAdmin = await token.STOKEN_ADMIN();
    const poolAdmin = await token.POOL_ADMIN_ROLE();
    await token.grantRole(stokenAdmin, admin.address);
    await token.grantRole(poolAdmin, admin.address);
    await token
      .connect(admin)
      .addSupportedTokenAddress(await paymentToken.getAddress());

    const subscriptionAmount = ethers.parseUnits("100", 6);
    await paymentToken.mint(user.address, subscriptionAmount * 2n);
    await paymentToken
      .connect(user)
      .approve(await token.getAddress(), subscriptionAmount * 2n);

    return { owner, user, admin, token, paymentToken, subscriptionAmount };
  }

  it("keeps online and offline subscription workflows separate", async function () {
    const { user, admin, token, paymentToken, subscriptionAmount } =
      await deployFixture();
    const stokenAmount = ethers.parseEther("1");

    const offlineTx = await token.connect(admin).subscribe(
      subscriptionAmount,
      await paymentToken.getAddress(),
      stokenAmount,
      user.address,
      ethers.parseEther("1"),
      1n,
      ethers.ZeroHash,
      "offline-subscription",
    );
    const offlineReceipt = await offlineTx.wait();
    const offlineEvent = findEvent(
      offlineReceipt,
      token.interface,
      "subscribeEvent",
    );
    const offlineId = offlineEvent.args.subscriptionId;

    await expect(
      token.connect(admin).overwriteOnChainSubscribe(
        offlineId,
        ethers.parseEther("1"),
        stokenAmount,
        1n,
        ethers.ZeroHash,
        "offline-subscription",
      ),
    ).to.be.revertedWith("Only on-chain subscription");

    await expect(token.connect(user).claim(offlineId)).to.be.revertedWith(
      "Only on-chain subscription",
    );
    await expect(token.connect(admin).execute(offlineId)).not.to.be.reverted;

    const onlineTx = await token
      .connect(user)
      .onChainSubscribe(
        await paymentToken.getAddress(),
        subscriptionAmount,
        0,
      );
    const onlineReceipt = await onlineTx.wait();
    const onlineEvent = findEvent(
      onlineReceipt,
      token.interface,
      "onChainSubscribeEvent",
    );
    const onlineId = onlineEvent.args.subscriptionId;

    await token.connect(admin).overwriteOnChainSubscribe(
      onlineId,
      ethers.parseEther("1"),
      stokenAmount,
      1n,
      ethers.ZeroHash,
      "online-subscription",
    );

    await expect(token.connect(admin).execute(onlineId)).to.be.revertedWith(
      "Only off-chain subscription",
    );
    await expect(token.connect(user).claim(onlineId)).not.to.be.reverted;
  });

  it("does not allow an offline redemption to use the online overwrite path", async function () {
    const { user, admin, token, paymentToken } = await deployFixture();
    const stokenAmount = ethers.parseEther("1");

    await token.connect(admin).mint(
      user.address,
      stokenAmount,
      [[1n, user.address, 31337n]],
      [stokenAmount],
    );

    const redemptionTx = await token.connect(admin).redemption(
      ethers.parseUnits("100", 6),
      await paymentToken.getAddress(),
      stokenAmount,
      user.address,
      ethers.parseEther("1"),
      1n,
      ethers.ZeroHash,
      "offline-redemption",
    );
    const redemptionReceipt = await redemptionTx.wait();
    const redemptionEvent = findEvent(
      redemptionReceipt,
      token.interface,
      "RedemptionEvent",
    );
    const redemptionId = redemptionEvent.args.redemptionId;

    await expect(
      token.connect(admin).overwriteOnChainRedemption(
        redemptionId,
        ethers.parseUnits("100", 6),
        ethers.parseEther("1"),
        1n,
        ethers.ZeroHash,
      ),
    ).to.be.revertedWith("Only on-chain redemption");

    await expect(token.connect(admin).burn(redemptionId)).not.to.be.reverted;
  });
});
