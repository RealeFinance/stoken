# SAmMMF 代码差异说明

旧版基线：用户上传的 SAmMMF 实现合约  
新版目标：当前代码库 `contracts/token/SAmMMF.sol`  
版本变化：`VERSION_2` -> `VERSION_3.1.0`

## 一、总体结论

本次升级属于定点升级，不是业务逻辑重写。申购、赎回、领取、FIFO Token ID 余额模型、黑名单校验、最低金额校验、技术服务费计算等核心逻辑整体保持一致。

主要变化集中在升级权限、资产地址配置权限、Pool 管理入口、新增队列参数，以及链上赎回 USD 地址修正能力。

## 二、主要差异

| 模块 | 旧版实现 | 新版实现 | 影响 |
| --- | --- | --- | --- |
| 版本标识 | `keccak256("VERSION_2")` | `keccak256("VERSION_3.1.0")` | 更新公开版本标识。 |
| 升级角色 | 存在 `UPGRADER_ROLE` | 移除 `UPGRADER_ROLE` | 升级权限模型调整。 |
| 升级授权 | `_authorizeUpgrade()` 要求 `UPGRADER_ROLE` | `_authorizeUpgrade()` 要求 `DEFAULT_ADMIN_ROLE` | 升级控制权转移至默认管理员治理。 |
| 初始化授权 | 初始化时授予 `DEFAULT_ADMIN_ROLE`、`UPGRADER_ROLE`、`STOKEN_BLACKLIST_ADMIN_ROLE` | 初始化时授予 `DEFAULT_ADMIN_ROLE`、`STOKEN_BLACKLIST_ADMIN_ROLE` | 新部署不再使用 `UPGRADER_ROLE`。 |
| 新增状态变量 | 无 | `uint256 public maxQueueLength` | 在现有变量后追加一个存储槽。 |
| 重初始化函数 | 无 | `initializeV2()` 设置 `maxQueueLength = 100` | 既有代理升级后可初始化新增变量。 |
| 主初始化函数 | 不设置队列长度 | 设置 `maxQueueLength = 100` | 新部署默认队列长度为 100。 |
| 资产接收地址配置 | `onlyRole(STOKEN_ADMIN)` | `onlyRole(DEFAULT_ADMIN_ROLE)` | 资产路由配置收敛至默认管理员。 |
| 资产发送地址配置 | `onlyRole(STOKEN_ADMIN)` | `onlyRole(DEFAULT_ADMIN_ROLE)` | 资产路由配置收敛至默认管理员。 |
| 服务费接收地址配置 | `onlyRole(STOKEN_ADMIN)` | `onlyRole(DEFAULT_ADMIN_ROLE)` | 服务费地址配置收敛至默认管理员。 |
| Pool 管理地址读取 | 存在 `getPoolAdmin()` | 已移除 | 外部脚本不应再依赖该 getter。 |
| Pool 管理地址设置 | 存在 `setPoolAdmin()` | 已移除 | `_poolAdmin` 需在升级前配置完成，或由后续治理补丁处理。 |
| Pool mint | 仅校验 `msg.sender == _poolAdmin` | 校验 `POOL_ADMIN_ROLE` 且 `msg.sender == _poolAdmin` | 增加角色权限保护。 |
| Pool burn | 仅校验 `msg.sender == _poolAdmin` | 校验 `POOL_ADMIN_ROLE` 且 `msg.sender == _poolAdmin` | 增加角色权限保护。 |
| 赎回 USD 地址修正 | 无 | 新增 `updateonChainRedemptionUSDAddress(redemptionId, newUSDAddress)` | 默认管理员可修正既有链上赎回记录的受支持 USD 币种地址。 |

## 三、保持不变的核心流程

以下函数的主要业务流程保持一致：

- `onChainSubscribe()`
- `overwriteOnChainSubscribe()`
- `subscribe()`
- `onChainRedemption()`
- `overwriteOnChainRedemption()`
- `redemption()`
- `execute()`
- `claim()`
- `claimUSD()`
- `burn()`
- `transfer()`
- `transferFrom()`
- 黑名单添加与移除
- 最低申购、最低赎回金额配置
- 支持币种地址添加与移除
- 技术服务费计算

## 四、集成方注意事项

如外部脚本、监控面板或运营工具依赖 `getPoolAdmin()` 或 `setPoolAdmin()`，需要同步调整。

Pool 侧调用 `mint()` 或 `burnFrom()` 前，应确认调用地址同时满足 `POOL_ADMIN_ROLE` 和 `_poolAdmin` 地址校验。

