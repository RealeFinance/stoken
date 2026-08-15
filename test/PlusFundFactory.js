const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PlusFundFactory", function () {
  async function deployFixture() {
    const signers = await ethers.getSigners();
    const Implementation = await ethers.getContractFactory("PlusFund");
    const implementation = await Implementation.deploy();
    await implementation.waitForDeployment();

    const Factory = await ethers.getContractFactory("PlusFundFactory");
    const factory = await Factory.deploy(await implementation.getAddress());
    await factory.waitForDeployment();

    return { signers, factory };
  }

  function buildConfig(signers) {
    return {
      productId: ethers.id("NGIPlus"),
      name: "NGIPlus",
      symbol: "NGI+",
      stokenAdmin: signers[1].address,
      poolAdmin: signers[2].address,
      blacklistAdmin: signers[3].address,
      ccipAdmin: signers[4].address,
      assetRecipient: signers[5].address,
      assetSender: signers[6].address,
      serviceFeeRecipient: signers[7].address,
      supportedTokens: [signers[8].address],
      minSubscriptionAmount: 10000n,
      minRedemptionAmount: ethers.parseEther("924.676"),
      maxQueueLength: 100n,
      timelockDelay: 172800n,
      proposers: [signers[1].address],
      executors: [ethers.ZeroAddress],
      cancellers: [signers[1].address],
    };
  }

  it("deploys an isolated proxy and per-token timelock", async function () {
    const { signers, factory } = await deployFixture();
    const config = buildConfig(signers);
    const salt = ethers.id("NGIPlus-1");

    const tx = await factory.deployToken(config, salt);
    const receipt = await tx.wait();
    const deploymentLog = receipt.logs
      .map((log) => {
        try {
          return factory.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((parsed) => parsed?.name === "TokenDeployed");

    expect(deploymentLog).to.not.equal(undefined);
    const proxyAddress = deploymentLog.args.proxy;
    const timelockAddress = deploymentLog.args.timelock;
    const token = await ethers.getContractAt("PlusFund", proxyAddress);
    const timelock = await ethers.getContractAt(
      "TimelockController",
      timelockAddress,
    );

    const defaultAdminRole = await token.DEFAULT_ADMIN_ROLE();
    const stokenAdminRole = await token.STOKEN_ADMIN();
    const poolAdminRole = await token.POOL_ADMIN_ROLE();
    const blacklistAdminRole = await token.STOKEN_BLACKLIST_ADMIN_ROLE();

    expect(await token.name()).to.equal(config.name);
    expect(await token.symbol()).to.equal(config.symbol);
    expect(await token.getAssetRecipient()).to.equal(config.assetRecipient);
    expect(await token.getAssetSender()).to.equal(config.assetSender);
    expect(await token.getServiceFeeRecipient()).to.equal(
      config.serviceFeeRecipient,
    );
    expect(await token.hasRole(defaultAdminRole, timelockAddress)).to.equal(true);
    expect(await token.hasRole(defaultAdminRole, await factory.getAddress())).to.equal(
      false,
    );
    expect(await token.hasRole(stokenAdminRole, config.stokenAdmin)).to.equal(true);
    expect(await token.hasRole(poolAdminRole, config.poolAdmin)).to.equal(true);
    expect(await token.hasRole(blacklistAdminRole, config.blacklistAdmin)).to.equal(
      true,
    );
    expect(await timelock.hasRole(await timelock.DEFAULT_ADMIN_ROLE(), timelockAddress)).to.equal(
      true,
    );
    expect(
      await timelock.hasRole(
        await timelock.DEFAULT_ADMIN_ROLE(),
        await factory.getAddress(),
      ),
    ).to.equal(false);
    expect(
      await timelock.hasRole(
        await timelock.CANCELLER_ROLE(),
        config.cancellers[0],
      ),
    ).to.equal(true);
    expect(await factory.tokenByProductId(config.productId)).to.equal(proxyAddress);
    expect(await factory.timelockByToken(proxyAddress)).to.equal(timelockAddress);
  });

  it("rejects a duplicate product id", async function () {
    const { signers, factory } = await deployFixture();
    const config = buildConfig(signers);

    await factory.deployToken(config, ethers.id("NGIPlus-1"));
    await expect(
      factory.deployToken(config, ethers.id("NGIPlus-2")),
    ).to.be.revertedWithCustomError(factory, "ProductAlreadyExists");
  });

  it("rejects a timelock with no executor or zero-delay governance", async function () {
    const { signers, factory } = await deployFixture();
    const baseConfig = buildConfig(signers);

    await expect(
      factory.deployToken(
        { ...baseConfig, timelockDelay: 0n },
        ethers.id("zero-delay"),
      ),
    ).to.be.revertedWithCustomError(factory, "InvalidConfiguration");

    await expect(
      factory.deployToken(
        { ...baseConfig, executors: [] },
        ethers.id("no-executor"),
      ),
    ).to.be.revertedWithCustomError(factory, "InvalidConfiguration");
  });

  it("rejects a zero-address proposer", async function () {
    const { signers, factory } = await deployFixture();
    const config = {
      ...buildConfig(signers),
      proposers: [ethers.ZeroAddress],
    };

    await expect(
      factory.deployToken(config, ethers.id("zero-proposer")),
    ).to.be.revertedWithCustomError(factory, "ZeroAddress");
  });

  it("rejects a non-UUPS implementation", async function () {
    const { signers, factory } = await deployFixture();
    const TimelockController = await ethers.getContractFactory(
      "TimelockController",
    );
    const invalidImplementation = await TimelockController.deploy(
      1n,
      [signers[1].address],
      [ethers.ZeroAddress],
      ethers.ZeroAddress,
    );
    await invalidImplementation.waitForDeployment();

    await expect(
      factory.setImplementation(await invalidImplementation.getAddress()),
    ).to.be.revertedWithCustomError(factory, "InvalidImplementation");
  });
});
