# PlusFund v2.1.1 升级说明

发布日期：2026-08-13

## 升级范围

- 合约：`PlusFund`
- 升级类型：UUPS implementation upgrade
- 关联问题：`STK-11`
- Git tag：`v2.1.1`

## 修复内容

`onChainRedemption()` 会先执行 `_burn()`，但原流程不会删除赎回记录。管理员后续通过 `overwriteOnChainRedemption()` 补齐赎回信息后，原 `burn()` 可能再次处理同一条记录，造成重复销毁风险。

本次升级：

1. 在 `RedemptionData` 中新增 `isOnChain` 标记。
2. `onChainRedemption()` 创建记录时设置 `isOnChain = true`。
3. 普通 `redemption()` 创建记录时设置 `isOnChain = false`。
4. `burn()` 仅允许处理线下赎回记录；链上赎回记录会被拒绝。
5. 对升级前创建的历史链上记录，使用已写入的 `tokenTransferDetails` 做兼容识别，避免升级后仍可重复销毁。
6. 合约 `version()` 更新为 `2.1.1`。

## 升级影响

- 不需要调用新的 initializer 或 reinitializer。
- `isOnChain` 作为 `RedemptionData` 结构体的追加字段，新增记录按新逻辑写入。
- 链上赎回仍按原流程执行：

  `onChainRedemption -> overwriteOnChainRedemption -> claimUSD`

- 线下赎回仍按原流程执行：

  `redemption -> burn`

- 链上赎回完成首次 `_burn()` 后，不能再调用 `burn()` 二次销毁。
- `claimUSD()` 的资金领取流程不变。

## 升级步骤

1. 部署新的 `PlusFund` implementation。
2. 使用 `upgrades.validateUpgrade(proxyAddress, NewImplFactory, { kind: "uups" })` 校验升级安全性。
3. 通过 UUPS proxy 执行 `upgradeToAndCall`，本版本无需传入 initializer calldata。
4. 升级后确认 `version()` 返回 `2.1.1`。
5. 使用 `test/PlusFundOnChainRedemption.js` 验证链上赎回不能再次进入 `burn()`。

## 验证结果

- `npx hardhat compile`：通过
- `npx hardhat test test/PlusFundOnChainRedemption.js test/PlusFundFactory.js`：3 passing
