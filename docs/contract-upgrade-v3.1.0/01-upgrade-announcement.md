# SAmMMF 合约升级公告

公示日期：2026-07-05

## 一、升级概述

Asseto Fintech Limited 计划将 SAmMMF 实现合约由 `VERSION_2` 升级至 `VERSION_3.1.0`。本次升级延续现有 UUPS 代理模式，保留原有申购、赎回、领取、转账、黑名单和技术服务费计算等核心流程。

本公告及配套文件用于升级前公开审阅，说明本次升级目的、主要变更、兼容性影响及运维注意事项。

## 二、升级目标

本次升级主要包含以下内容：

- 将 UUPS 升级授权由独立 `UPGRADER_ROLE` 调整为 `DEFAULT_ADMIN_ROLE`。
- 新增 `initializeV2()`，用于已部署代理合约在升级后初始化新增队列参数。
- 新增 `maxQueueLength`，默认值为 `100`。
- 将资产接收地址、资产发送地址、服务费接收地址的配置权限由 `STOKEN_ADMIN` 调整为 `DEFAULT_ADMIN_ROLE`。
- 为 Pool 侧 `mint()` 与 `burnFrom()` 增加 `POOL_ADMIN_ROLE` 权限校验，并保留 `_poolAdmin` 地址校验。
- 新增链上赎回记录 USD 币种地址修正函数 `updateonChainRedemptionUSDAddress()`。

## 三、用户影响

本次升级不涉及代理地址迁移，不改变用户余额存储位置，不要求用户重新授权或迁移资产。

正常用户侧申购、赎回、领取、转账、黑名单校验、最低金额限制及技术服务费计算逻辑预计保持不变。

## 四、管理影响

升级后需要关注以下管理变化：

- 持有 `DEFAULT_ADMIN_ROLE` 的治理地址将负责实现合约升级授权。
- 资产收发及服务费接收地址由 `DEFAULT_ADMIN_ROLE` 管理。
- Pool 侧增发和销毁需要同时满足：
  - 调用方持有 `POOL_ADMIN_ROLE`；
  - 调用方地址等于合约内已存储的 `_poolAdmin`。
- 既有代理合约升级后应执行一次 `initializeV2()`，确保 `maxQueueLength` 初始化为 `100`。

## 五、公开审阅重点

建议社区、审计方及运维方重点核查：

- `DEFAULT_ADMIN_ROLE` 是否由预期的多签、Timelock 或其他治理账户控制。
- `_poolAdmin` 是否已在升级前正确配置；新版合约已移除公开 `setPoolAdmin()` 与 `getPoolAdmin()`。
- 预期 Pool 管理地址是否已被授予 `POOL_ADMIN_ROLE`。
- 新增 `updateonChainRedemptionUSDAddress()` 是否仅用于必要的运营纠错，并建议后续版本补充事件以提升链上可追踪性。

