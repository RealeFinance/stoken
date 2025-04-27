const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const parseEther = ethers.parseEther;

describe("SAmMMF", function () {
    let SAmMMF, sAmMMF;
    let AmMMFMock;
    let owner, admin, upgrader, user;

    beforeEach(async function () {
        [owner, admin, upgrader, user] = await ethers.getSigners();

        // Deploy mock contract for AmMMF
        const MockERC20 = await ethers.getContractFactory("AmMMF");
        AmMMFMock = await MockERC20.deploy();

        // Deploy SAmMMF contract
        const SAmMMFFactory = await ethers.getContractFactory("SAmMMF");
        sAmMMF = await upgrades.deployProxy(
            SAmMMFFactory,
            [admin.address, AmMMFMock.getAddress(), upgrader.address],
            { initializer: "initialize" }
        );
        await sAmMMF.waitForDeployment();
    });

    it("should initialize correctly", async function () {
        expect(await sAmMMF.name()).to.equal("sAmMMF");
        expect(await sAmMMF.symbol()).to.equal("MTK");
        expect(await sAmMMF.ammmf()).to.equal(await AmMMFMock.getAddress());
        expect(await sAmMMF.hasRole(await sAmMMF.DEFAULT_ADMIN_ROLE(), admin.address)).to.be.true;
        expect(await sAmMMF.hasRole(await sAmMMF.UPGRADER_ROLE(), upgrader.address)).to.be.true;
    });

    it("should allow wrapping AmMMF tokens", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await AmMMFMock.connect(user).approve(sAmMMF.getAddress(), parseEther("50"));

        await sAmMMF.connect(user).wrap(parseEther("50"));

        expect(await sAmMMF.balanceOf(user.address)).to.equal(parseEther("50"));
        expect(await AmMMFMock.balanceOf(user.address)).to.equal(parseEther("50"));
        expect(await AmMMFMock.balanceOf(sAmMMF.getAddress())).to.equal(parseEther("50"));
    });

    it("should revert when wrapping zero AmMMF tokens", async function () {
        await expect(sAmMMF.connect(user).wrap(0)).to.be.revertedWith("sAmMMF: can't wrap zero AmMMF tokens");
    });

    it("should revert when wrapping without sufficient allowance", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await expect(sAmMMF.connect(user).wrap(parseEther("50"))).to.be.revertedWith("sAmMMF: Transfer failed");
    });

    it("should allow unwrapping sAmMMF tokens", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await AmMMFMock.connect(user).approve(sAmMMF.getAddress(), parseEther("50"));
        await sAmMMF.connect(user).wrap(parseEther("50"));

        await sAmMMF.connect(user).unwrap(parseEther("30"));

        expect(await sAmMMF.balanceOf(user.address)).to.equal(parseEther("20"));
        expect(await AmMMFMock.balanceOf(user.address)).to.equal(parseEther("80"));
        expect(await AmMMFMock.balanceOf(sAmMMF.getAddress())).to.equal(parseEther("20"));
    });

    it("should revert when unwrapping zero sAmMMF tokens", async function () {
        await expect(sAmMMF.connect(user).unwrap(0)).to.be.revertedWith("sAmMMF: can't unwrap zero sAmMMF tokens");
    });

    it("should revert when unwrapping more than balance", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await AmMMFMock.connect(user).approve(sAmMMF.getAddress(), parseEther("50"));
        await sAmMMF.connect(user).wrap(parseEther("50"));

        await expect(sAmMMF.connect(user).unwrap(parseEther("60"))).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });

    it("should allow admin to pause and unpause the contract", async function () {
        await sAmMMF.connect(admin).pause();
        expect(await sAmMMF.paused()).to.be.true;

        await sAmMMF.connect(admin).unpause();
        expect(await sAmMMF.paused()).to.be.false;
    });

    it("should revert wrapping or unwrapping when paused", async function () {
        await AmMMFMock.mint(user.address, parseEther("100"));
        await AmMMFMock.connect(user).approve(sAmMMF.getAddress(), parseEther("50"));
        await sAmMMF.connect(admin).pause();

        await expect(sAmMMF.connect(user).wrap(parseEther("50"))).to.be.revertedWith("Pausable: paused");
        await expect(sAmMMF.connect(user).unwrap(parseEther("50"))).to.be.revertedWith("Pausable: paused");
    });

    it("should allow upgrader to upgrade the contract", async function () {
        const NewSAmMMF = await ethers.getContractFactory("SAmMMF");
        const newImplementation = await NewSAmMMF.deploy();

        await sAmMMF.connect(upgrader).upgradeTo(newImplementation.getAddress());
        // Ensure the upgrade was successful (e.g., by checking the implementation address)
    });

    it("should revert upgrade if caller is not upgrader", async function () {
        const NewSAmMMF = await ethers.getContractFactory("SAmMMF");
        const newImplementation = await NewSAmMMF.deploy();

        await expect(sAmMMF.connect(user).upgradeTo(newImplementation.getAddress())).to.be.revertedWith(
            "AccessControl: account"
        );
    });
});