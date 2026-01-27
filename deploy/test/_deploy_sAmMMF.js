async function main() {
  const hre = require('hardhat')

  const { name: networkName } = hre.network
  console.log(`正在部署到网络: ${networkName}`)

  const { deploySAmMMF } = require('./_deploy_base')

  const token = await deploySAmMMF()
  const tokenAddress = await token.getAddress()
  console.log('SAmMMF Token 地址:', tokenAddress)
}

main().catch(console.error)


// npx hardhat run deploy/test/_deploy_sAmMMF.js --network bscTestnet