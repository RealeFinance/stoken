const { ethers, upgrades } = require('hardhat')
async function main() {
  const hre = require('hardhat')

  const { name: networkName } = hre.network
  console.log(`正在部署升级合约到网络: ${networkName}`)

  const { deploySAmMMFUpgrade } = require('./_deploy_base')

  const SAmMMFToken = await deploySAmMMFUpgrade(
    hre,
    "0x1775504c5873e179Ea2f8ABFcE3861EC74D159bc"
  )
  const sAmMMFAddress = await SAmMMFToken.getAddress()

  console.log('SAmMMF升级成功...代理地址:', sAmMMFAddress)
}

main().catch(console.error)


// npx hardhat run deploy/test/_deploy_sAmMMF_upgrade.js --network bscTestnet