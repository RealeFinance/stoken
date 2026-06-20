const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const parseEther = ethers.parseEther;

describe("MAmMMFManagement", function () {
    let MAmMMFManagement, mAmMMFManagement;
    let MAmMMFMock, AmMMFMock;
    let owner, admin, user;

    beforeEach(async function () {
        [owner, admin, user] = await ethers.getSigners();

        // Deploy mock contracts for AmMMF
        // Function to deploy a mock contract for the AmMMF token
        async function deployAmMMFMock() {
            const MockERC20 = await ethers.getContractFactory("AmMMF");
            return await MockERC20.deploy();
        }

        // Deploy mock contracts for MAmMMF
        async function deployMAmMMFMock() {
            const MockMAmMMF = await ethers.getContractFactory("MAmMMF");
            const mAmMMF = await upgrades.deployProxy(
                MockMAmMMF,
                [
                    admin.address,
                    admin.address
                ],
                { initializer: "initialize" }
            );
            await mAmMMF.waitForDeployment();
            return mAmMMF;
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
            await mAmMMFManagement.waitForDeployment();
            return mAmMMFManagement;
        }

        // Deploy all contracts
        AmMMFMock = await deployAmMMFMock();
        MAmMMFMock = await deployMAmMMFMock();
        mAmMMFManagement = await deployMAmMMFManagement(
            await MAmMMFMock.getAddress(),
            await AmMMFMock.getAddress()
        );

        await MAmMMFMock.connect(admin).setEscrowAdmin(mAmMMFManagement.getAddress());

        // Grant admin role to another account
        await mAmMMFManagement.grantRole(
            await mAmMMFManagement.DEFAULT_ADMIN_ROLE(),
            admin.address
        );
    });

    it("should initialize correctly", async function () {
        expect(await mAmMMFManagement.owner()).to.equal(owner.address);
        expect(await mAmMMFManagement.MAmMMF()).to.equal(await MAmMMFMock.getAddress());
        expect(await mAmMMFManagement.AmMMF()).to.equal(await AmMMFMock.getAddress());
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
        await AmMMFMock.mint(user.address, parseEther("100"));
        expect(
            await mAmMMFManagement.getMaxMintableMAmMMF(user.address)
        ).to.equal(parseEther("100"));
    });

    it("should allow admin to mint MAmMMF", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await mAmMMFManagement
            .connect(admin)
            .mintFromAmMMF(user.address, parseEther("50"));

        expect(await MAmMMFMock.balanceOf(user.address)).to.equal(
            parseEther("50")
        );
        expect(await mAmMMFManagement.mintedAmounts(user.address)).to.equal(
            parseEther("50")
        );
    });

    it("should revert if mint amount exceeds AmMMF balance", async function () {
        await AmMMFMock.mint(user.address, parseEther("50"));
        await expect(
            mAmMMFManagement
                .connect(admin)
                .mintFromAmMMF(user.address, parseEther("100"))
        ).to.be.revertedWith("Insufficient AmMMF balance");
    });

    it("should allow admin to burn MAmMMF", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await mAmMMFManagement
            .connect(admin)
            .mintFromAmMMF(user.address, parseEther("50"));

        await mAmMMFManagement
            .connect(admin)
            .burnMAmMMF(user.address, parseEther("20"));

        expect(await MAmMMFMock.balanceOf(user.address)).to.equal(
            parseEther("30")
        );
        expect(await mAmMMFManagement.mintedAmounts(user.address)).to.equal(
            parseEther("30")
        );
    });

    it("should revert if burn amount exceeds MAmMMF balance", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await mAmMMFManagement
            .connect(admin)
            .mintFromAmMMF(user.address, parseEther("50"));

        await expect(
            mAmMMFManagement
                .connect(admin)
                .burnMAmMMF(user.address, parseEther("60"))
        ).to.be.revertedWith("Insufficient MAmMMF balance");
    });
});