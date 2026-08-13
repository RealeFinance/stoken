const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("PlusFund on-chain redemption", function () {
  async function deployFixture() {
    const [owner, user, admin] = await ethers.getSigners();
    const PlusFund = await ethers.getContractFactory("PlusFund");
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
    await token.connect(admin).addSupportedTokenAddress(owner.address);

    return { token, user, admin, paymentToken: owner.address };
  }

  it("rejects burning an on-chain redemption after it has already burned", async function () {
    const { token, user, admin, paymentToken } = await deployFixture();
    const amount = ethers.parseEther("10");

    await token.connect(admin).mint(
      user.address,
      ethers.parseEther("100"),
      [[1n, user.address, 31337n]],
      [ethers.parseEther("100")],
    );

    const redemptionTx = await token
      .connect(user)
      .onChainRedemption(paymentToken, amount, 1);
    const redemptionReceipt = await redemptionTx.wait();
    const redemptionEvent = redemptionReceipt.logs
      .map((log) => {
        try {
          return token.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((parsed) => parsed?.name === "onChainRedemptionEvent");
    const redemptionId = redemptionEvent.args.redemptionId;

    await token.connect(admin).overwriteOnChainRedemption(
      redemptionId,
      ethers.parseUnits("10", 6),
      ethers.parseEther("1"),
      1n,
      ethers.ZeroHash,
    );

    await expect(token.connect(admin).burn(redemptionId)).to.be.revertedWith(
      "Cannot burn on-chain redemption",
    );
    expect(await token.balanceOf(user.address)).to.equal(ethers.parseEther("90"));
  });
});
