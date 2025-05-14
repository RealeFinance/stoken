const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("reUSD Token", function () {
  let reUSD, reUSDToken, owner, addr1, addr2;

  async function deployReUSD() {
    const reUSDFactory = await ethers.getContractFactory("ReUSD");
    const reUSDToken = await upgrades.deployProxy(
      reUSDFactory,
      [owner, _mAmMMF, _rAmMMF, owner],
      { initializer: "initialize" }
    );
    await reUSDToken.waitForDeployment();
    return reUSDToken;
  }

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    reUSDToken = await deployReUSD();
  });

  it("Should have correct name and symbol", async function () {
    expect(await reUSDToken.name()).to.equal("reUSD");
    expect(await reUSDToken.symbol()).to.equal("reUSD");
  });

  it("Should mint tokens to owner", async function () {
    const mintAmount = ethers.utils.parseUnits("1000", 18);
    await reUSDToken.mint(owner.address, mintAmount);
    expect(await reUSDToken.balanceOf(owner.address)).to.equal(mintAmount);
  });

  it("Should transfer tokens between accounts", async function () {
    const mintAmount = ethers.utils.parseUnits("1000", 18);
    await reUSDToken.mint(owner.address, mintAmount);

    await reUSDToken.transfer(addr1.address, mintAmount.div(2));
    expect(await reUSDToken.balanceOf(addr1.address)).to.equal(
      mintAmount.div(2)
    );
    expect(await reUSDToken.balanceOf(owner.address)).to.equal(
      mintAmount.div(2)
    );
  });

  it("Should fail if sender doesn’t have enough tokens", async function () {
    await expect(
      reUSDToken.connect(addr1).transfer(owner.address, 1)
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
  });

  it("Should allow approvals and transferFrom", async function () {
    const mintAmount = ethers.utils.parseUnits("1000", 18);
    await reUSDToken.mint(owner.address, mintAmount);

    await reUSDToken.approve(addr1.address, mintAmount);
    await reUSDToken
      .connect(addr1)
      .transferFrom(owner.address, addr2.address, mintAmount.div(2));

    expect(await reUSDToken.balanceOf(addr2.address)).to.equal(
      mintAmount.div(2)
    );
    expect(await reUSDToken.allowance(owner.address, addr1.address)).to.equal(
      mintAmount.div(2)
    );
  });
});
