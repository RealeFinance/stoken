async function main() {
    const hre = require("hardhat");

    const { name: networkName } = hre.network;
    console.log(`正在部署到网络: ${networkName}`);

    const { deployBlackList, deployAllowList } = require("./_deploy_base");

    const BlackListToken = await deployBlackList(hre);
    const BlackListAddress = await BlackListToken.getAddress();
    const AllowListToken = await deployAllowList(hre);
    const AllowListAddress = await AllowListToken.getAddress();

    console.log("BlackList Token地址:", BlackListAddress);
    console.log("AllowList Token地址:", AllowListAddress);
}

main().catch(console.error);