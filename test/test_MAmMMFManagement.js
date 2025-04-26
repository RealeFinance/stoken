const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("MAmMMFManagement", function () {
    let MAmMMFManagement, mAmMMFManagement;
    let MAmMMFMock, AmMMFMock;
    let owner, admin, user;

    beforeEach(async function () {
        [owner, admin, user] = await ethers.getSigners();

        // Deploy mock contracts for AmMMF
        async function deployAmMMFMock() {
            const MockERC20 = await ethers.getContractFactory("MAmMMF");
            const amMMFMock = await MockERC20.deploy("AmMMF Token", "AmMMF", 18);
            await amMMFMock.deployed();
            return amMMFMock;
        }

        // Deploy mock contracts for MAmMMF
        async function deployMAmMMFMock() {
            const MockMAmMMF = await ethers.getContractFactory("MAmMMF");
            const mAmMMFMock = await MockMAmMMF.deploy();
            await mAmMMFMock.deployed();
            return mAmMMFMock;
        }

        // Deploy MAmMMFManagement contract
        async function deployMAmMMFManagement(mAmMMFAddress, amMMFAddress) {
            const MAmMMFManagementFactory = await ethers.getContractFactory(
            "MAmMMFManagement"
            );
            const mAmMMFManagement = await upgrades.deployProxy(
            MAmMMFManagementFactory,
            [
                "MAmMMF Token",
                "MAmMMF",
                mAmMMFAddress,
                amMMFAddress
            ],
            { initializer: "initialize" }
            );
            await mAmMMFManagement.deployed();
            return mAmMMFManagement;
        }

        // Deploy all contracts
        AmMMFMock = await deployAmMMFMock();
        MAmMMFMock = await deployMAmMMFMock();
        mAmMMFManagement = await deployMAmMMFManagement(
            MAmMMFMock.address,
            AmMMFMock.address
        );

        // Grant admin role to another account
        await mAmMMFManagement.grantRole(
            await mAmMMFManagement.DEFAULT_ADMIN_ROLE(),
            admin.address
        );
    });

    it("should initialize correctly", async function () {
        expect(await mAmMMFManagement.owner()).to.equal(owner.address);
        expect(await mAmMMFManagement.MAmMMF()).to.equal(MAmMMFMock.address);
        expect(await mAmMMFManagement.AmMMF()).to.equal(AmMMFMock.address);
    });

    it("should allow owner to transfer ownership", async function () {
        await mAmMMFManagement.transferOwnership(user.address);
        expect(await mAmMMFManagement.owner()).to.equal(user.address);
    });

    it("should revert if non-owner tries to transfer ownership", async function () {
        await expect(
            mAmMMFManagement.connect(user).transferOwnership(user.address)
        ).to.be.revertedWith("Caller is not the owner");
    });

    it("should calculate max mintable MAmMMF correctly", async function () {
        await AmMMFMock.mint(user.address, ethers.utils.parseEther("100"));
        expect(
            await mAmMMFManagement.getMaxMintableMAmMMF(user.address)
        ).to.equal(ethers.utils.parseEther("100"));
    });

    it("should allow admin to mint MAmMMF", async function () {
        await AmMMFMock.mint(user.address, ethers.utils.parseEther("100"));
        await mAmMMFManagement
            .connect(admin)
            .mintFromAmMMF(user.address, ethers.utils.parseEther("50"));

        expect(await MAmMMFMock.balanceOf(user.address)).to.equal(
            ethers.utils.parseEther("50")
        );
        expect(await mAmMMFManagement.mintedAmounts(user.address)).to.equal(
            ethers.utils.parseEther("50")
        );
    });

    it("should revert if mint amount exceeds AmMMF balance", async function () {
        await AmMMFMock.mint(user.address, ethers.utils.parseEther("50"));
        await expect(
            mAmMMFManagement
                .connect(admin)
                .mintFromAmMMF(user.address, ethers.utils.parseEther("100"))
        ).to.be.revertedWith("Insufficient AmMMF balance");
    });

    it("should allow admin to burn MAmMMF", async function () {
        await AmMMFMock.mint(user.address, ethers.utils.parseEther("100"));
        await mAmMMFManagement
            .connect(admin)
            .mintFromAmMMF(user.address, ethers.utils.parseEther("50"));

        await mAmMMFManagement
            .connect(admin)
            .burnMAmMMF(user.address, ethers.utils.parseEther("20"));

        expect(await MAmMMFMock.balanceOf(user.address)).to.equal(
            ethers.utils.parseEther("30")
        );
        expect(await mAmMMFManagement.mintedAmounts(user.address)).to.equal(
            ethers.utils.parseEther("30")
        );
    });

    it("should revert if burn amount exceeds MAmMMF balance", async function () {
        await AmMMFMock.mint(user.address, ethers.utils.parseEther("100"));
        await mAmMMFManagement
            .connect(admin)
            .mintFromAmMMF(user.address, ethers.utils.parseEther("50"));

        await expect(
            mAmMMFManagement
                .connect(admin)
                .burnMAmMMF(user.address, ethers.utils.parseEther("60"))
        ).to.be.revertedWith("Insufficient MAmMMF balance");
    });
});