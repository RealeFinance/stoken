# SAmMMF 升级执行清单

## 一、升级前检查

- 确认代理合约地址、当前实现合约地址、目标实现合约地址。
- 确认当前实现版本为 `VERSION_2`。
- 确认目标实现源码对应 `VERSION_3.1.0`。
- 确认治理、多签或 Timelock 持有 `DEFAULT_ADMIN_ROLE`。
- 确认升级交易将由授权治理流程执行。
- 如升级后需要 Pool 侧增发或销毁，确认 `_poolAdmin` 已在升级前配置完成。
- 确认可向预期 Pool 管理地址授予 `POOL_ADMIN_ROLE`。
- 确认支持的 USDT、USDC 或其他 USD 币种地址配置正确。
- 升级前完成编译、测试及必要的人工复核。

## 二、升级执行步骤

1. 部署新版 SAmMMF 实现合约。
2. 如适用，在目标链浏览器验证新版实现合约源码。
3. 准备 UUPS 升级 calldata。
4. 通过授权治理账户、多签或 Timelock 执行升级。
5. 对既有代理合约执行一次 `initializeV2()`；如升级交易已包含该调用，则无需重复执行。
6. 如尚未授权，将 `POOL_ADMIN_ROLE` 授予已配置的 Pool 管理地址。

## 三、升级后检查

- 确认代理合约 implementation 指向新版实现合约地址。
- 确认 `VERSION()` 等于 `keccak256("VERSION_3.1.0")`。
- 确认 `maxQueueLength()` 返回 `100`。
- 确认申购、赎回、领取等核心流程可用。
- 确认 `setAssetRecipient()`、`setAssetSender()`、`setServiceFeeRecipient()` 仅可由 `DEFAULT_ADMIN_ROLE` 调用。
- 确认未授权账户无法调用 `mint()` 与 `burnFrom()`。
- 确认 `mint()` 与 `burnFrom()` 仅在调用方同时持有 `POOL_ADMIN_ROLE` 且等于 `_poolAdmin` 时可执行。
- 确认 `updateonChainRedemptionUSDAddress()` 仅接受已支持的 USD 币种地址。

## 四、建议公开材料

- 代理合约地址。
- 新版实现合约地址。
- 升级交易哈希。
- 初始化交易哈希，如与升级交易分开执行。
- `POOL_ADMIN_ROLE` 授权交易哈希，如适用。
- 对应 Git commit hash。
- 链浏览器源码验证链接，如适用。

