# SAmMMF 风险与回滚预案

## 一、主要风险

### 1. 升级权限迁移风险

新版将 UUPS 升级授权由 `UPGRADER_ROLE` 调整为 `DEFAULT_ADMIN_ROLE`。如果默认管理员权限范围大于原升级角色，可能导致升级治理边界发生变化。

缓释措施：

- 确认 `DEFAULT_ADMIN_ROLE` 由预期治理地址控制。
- 生产环境建议使用多签或 Timelock 执行升级。
- 如存在多余默认管理员，应按治理流程评估是否移除。

### 2. Pool 管理地址配置风险

新版移除了 `setPoolAdmin()` 与 `getPoolAdmin()`，但 `mint()` 和 `burnFrom()` 仍要求调用方等于 `_poolAdmin`，并新增 `POOL_ADMIN_ROLE` 校验。

缓释措施：

- 升级前确认 `_poolAdmin` 已正确配置。
- 将 `POOL_ADMIN_ROLE` 授予同一地址。
- 如 `_poolAdmin` 尚未配置，不建议直接升级，除非治理方明确接受影响或先发布受控补丁。

### 3. 新增赎回 USD 地址修正函数风险

`updateonChainRedemptionUSDAddress()` 允许 `DEFAULT_ADMIN_ROLE` 修改既有链上赎回记录的 USD 币种地址，前提是新地址属于支持币种列表。

缓释措施：

- 严格限制 `DEFAULT_ADMIN_ROLE`。
- 仅在运营纠错场景使用该函数。
- 建议后续版本增加专用事件，便于链上索引和外部审计。

### 4. 新增变量初始化风险

`maxQueueLength` 为新增状态变量。既有代理合约升级后需要执行 `initializeV2()` 才能设置预期默认值。

缓释措施：

- 将 `initializeV2()` 纳入升级执行流程。
- 升级后检查 `maxQueueLength() == 100`。

## 二、回滚策略

本合约采用 UUPS 升级模式。若升级后出现重大异常，回滚方式为通过授权升级路径将代理合约 implementation 指回上一版已验证实现，或指向经审查的热修复实现。

回滚前提：

- 已记录上一版实现合约地址。
- 回滚执行账户持有新版要求的 `DEFAULT_ADMIN_ROLE`。
- 治理、多签或 Timelock 能在预期响应时间内执行回滚交易。

回滚步骤：

1. 如异常影响用户操作，且 `STOKEN_ADMIN` 可用，优先暂停合约。
2. 准备指向上一版实现或热修复实现的 UUPS 回滚 calldata。
3. 通过 `DEFAULT_ADMIN_ROLE` 控制的治理流程执行回滚。
4. 核对代理合约 implementation 地址。
5. 重新检查申购、赎回、领取、转账及权限控制。
6. 公示回滚交易哈希、影响范围和后续处理说明。

## 三、升级后监控

升级后建议重点监控：

- 升级与初始化交易是否成功。
- `maxQueueLength()` 返回值。
- `DEFAULT_ADMIN_ROLE`、`STOKEN_ADMIN`、`POOL_ADMIN_ROLE` 的授权和撤销事件。
- 资产接收地址、资产发送地址、服务费接收地址变更。
- Pool 侧 `mint()` 与 `burnFrom()` 调用。
- `updateonChainRedemptionUSDAddress()` 调用。
- 申购、赎回、领取、转账相关异常 revert。

