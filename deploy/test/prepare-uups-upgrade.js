const { ethers, upgrades } = require("hardhat");

async function main() {
  // ===== 你要改的参数 =====
  const proxyAddress = "0x9EA9cd205783F08700d2A12C325FC4e1BF8e99a2";
  const newContractName = "SToken";

  // 如果升级后要顺便执行 reinitializer，就打开下面两行
  const callInitializer = false;
  const initializerArgs = []; // 例如 [123, "abc"]

  // ===== 1) 获取新实现合约工厂 =====
  const NewImplFactory = await ethers.getContractFactory(newContractName);

  // ===== 2) 校验升级安全性 =====
  await upgrades.validateUpgrade(proxyAddress, NewImplFactory, {
    kind: "uups",
  });

  // ===== 3) 仅部署新的 implementation，不执行升级 =====
  const newImplementationAddress = await upgrades.prepareUpgrade(
    proxyAddress,
    NewImplFactory,
    {
      kind: "uups",
    },
  );

  console.log("New implementation deployed:", newImplementationAddress);

  // ===== 4) 构造多签要执行的 calldata =====

  const proxyAsUUPS = await ethers.getContractAt(
    [
      "function upgradeToAndCall(address newImplementation, bytes data) external payable",
    ],
    proxyAddress,
  );

  let upgradeCallData;

  if (callInitializer) {
    // 假设你的 V2 里有：
    // function initializeV2(uint256 x, string memory y) reinitializer(2)
    const implInterface = NewImplFactory.interface;
    const initData = implInterface.encodeFunctionData(
      "initializeV2",
      initializerArgs,
    );

    upgradeCallData = proxyAsUUPS.interface.encodeFunctionData(
      "upgradeToAndCall",
      [newImplementationAddress, initData],
    );
  } else {
    upgradeCallData = proxyAsUUPS.interface.encodeFunctionData(
      "upgradeToAndCall",
      [newImplementationAddress, "0x"],
    );
  }

  console.log("\n=== Submit this transaction in Safe ===");
  console.log("to:", proxyAddress);
  console.log("value:", "0");
  console.log("data:", upgradeCallData);

  // 也可以顺便打印更适合复制的 JSON
  const payload = {
    to: proxyAddress,
    value: "0",
    data: upgradeCallData,
    newImplementationAddress,
  };

  console.log("\nSafe payload JSON:");
  console.log(JSON.stringify(payload, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
