# SAmMMF 存储布局与权限核查

## 一、存储布局核查

新版实现新增一个状态变量：

```solidity
uint256 public maxQueueLength;
```

该变量追加在 SAmMMF 合约既有状态变量之后，未插入到原有变量之间，预期不会改变既有状态变量的存储槽位置。

以下关键状态变量在新版中保持原有顺序：

- `_subscribeDataMap`
- `_redemptionDataMap`
- `_tokenDataMap`
- `_tokenList`
- `_tokenMap`
- `_totalSupply`
- `nextId`
- `MIN_SUBSCRIPTION_USD_AMOUNT`
- `MIN_REDEMPTION_CASH_AMOUNT`
- `_ccipAdmin`
- `_poolAdmin`
- `POOL_ADMIN_ROLE`

对于已部署代理合约，升级后应执行一次：

```solidity
initializeV2()
```

以设置：

```solidity
maxQueueLength = 100;
```

## 二、权限变化核查

| 函数 | 旧版权限 | 新版权限 | 核查结论 |
| --- | --- | --- | --- |
| `_authorizeUpgrade()` | `UPGRADER_ROLE` | `DEFAULT_ADMIN_ROLE` | 需确认默认管理员由预期治理账户控制。 |
| `setAssetRecipient()` | `STOKEN_ADMIN` | `DEFAULT_ADMIN_ROLE` | 资产接收地址配置权限收紧。 |
| `setAssetSender()` | `STOKEN_ADMIN` | `DEFAULT_ADMIN_ROLE` | 资产发送地址配置权限收紧。 |
| `setServiceFeeRecipient()` | `STOKEN_ADMIN` | `DEFAULT_ADMIN_ROLE` | 服务费接收地址配置权限收紧。 |
| `mint()` | `_poolAdmin` 地址校验 | `POOL_ADMIN_ROLE` 加 `_poolAdmin` 地址校验 | 权限增强，但依赖角色配置。 |
| `burnFrom()` | `_poolAdmin` 地址校验 | `POOL_ADMIN_ROLE` 加 `_poolAdmin` 地址校验 | 权限增强，但依赖角色配置。 |
| `updateonChainRedemptionUSDAddress()` | 无 | `DEFAULT_ADMIN_ROLE` | 新增运营纠错函数。 |

## 三、升级前置依赖

升级前建议确认：

- `_poolAdmin` 已存储为预期 Pool 管理地址。
- 预期 Pool 管理地址可被授予 `POOL_ADMIN_ROLE`。
- `DEFAULT_ADMIN_ROLE` 由预期多签、Timelock 或治理账户控制。
- `STOKEN_ADMIN` 仍由预期运营账户控制，用于暂停、申购赎回覆盖、黑名单等操作。

## 四、兼容性说明

新版移除了 SAmMMF 中公开的 `getPoolAdmin()` 与 `setPoolAdmin()`。底层 `_poolAdmin` 存储变量仍然存在，但新版不再提供公开读取和设置入口。

如 `_poolAdmin` 在升级前未完成配置，升级后 Pool 侧 `mint()` 与 `burnFrom()` 将无法正常使用，除非后续通过治理补丁恢复受控设置能力或采用其他明确治理方案。

