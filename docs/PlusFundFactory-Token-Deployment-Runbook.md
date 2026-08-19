# PlusFundFactory Token 发布 Runbook

## 目标

通过 `PlusFundFactory` 部署一个新的 PlusFund Token 及其专属 Timelock。

## 0. 部署工厂并拆分权限

工厂部署时直接传入三个参数：

```javascript
const factory = await Factory.deploy(
  implementationAddress, // 已审计的 PlusFund implementation
  factoryAdminSafe,      // 工厂 DEFAULT_ADMIN_ROLE
  operatorAddress,       // 工厂 DEPLOYER_ROLE
);
```

权限关系：

- `factoryAdminSafe`：管理 implementation、授予/撤销部署权限。
- `operatorAddress`：只能调用 `deployToken()` 和 `batchDeploy()`。
- 两者不应使用同一个地址。
- `factoryAdminSafe` 必须是已部署的合约地址，建议使用 Safe。

## 1. 发布前准备

- 确认当前工厂 `implementation` 已指向经过测试和审计的 PlusFund 实现。
- 准备唯一的 `productId` 和 `salt`。
- 准备 Token 名称、符号和业务参数。
- 准备治理地址：
  - `stokenAdmin`：必须是合约地址，建议使用 Safe 多签。
  - `proposers`：必须是合约地址，建议使用 Safe 多签。
  - `cancellers`：如配置，必须是合约地址。
  - `executors`：可使用 Safe、EOA 或 `address(0)`；`address(0)` 表示开放执行。
- 准备资产地址：`assetRecipient`、`assetSender`、`serviceFeeRecipient`。
- 准备合法且已部署的 `supportedTokens`。

注意：当前 `deployToken()` 和 `batchDeploy()` 要求调用者拥有工厂的 `DEPLOYER_ROLE`。

## 2. 配置 TokenConfig

```javascript
const config = {
  productId: ethers.id("RWA-USDC-001"),       // bytes32，产品唯一标识
  name: "Example RWA Token",                  // Token 名称
  symbol: "ERWA",                             // Token 符号

  stokenAdmin: "0x1111111111111111111111111111111111111111",       // 治理/业务 Safe
  poolAdmin: "0x2222222222222222222222222222222222222222",         // 跨链铸销管理员，可为 0 地址
  blacklistAdmin: "0x3333333333333333333333333333333333333333",   // 黑名单角色地址，可为 0 地址
  ccipAdmin: "0x4444444444444444444444444444444444444444",       // CCIP 管理员，可为 0 地址

  assetRecipient: "0x5555555555555555555555555555555555555555",  // 接收申购资金
  assetSender: "0x6666666666666666666666666666666666666666",     // 赎回资金来源
  serviceFeeRecipient: "0x7777777777777777777777777777777777777777", // 服务费接收地址

  supportedTokens: [
    "0x8888888888888888888888888888888888888888", // USDC/USDT 等已部署 ERC20
  ],

  minSubscriptionAmount: 100n,                    // 最小申购金额，按业务金额配置
  minRedemptionAmount: ethers.parseEther("0.948"), // 最小赎回 Cash+ 数量，18 位精度
  maxQueueLength: 100n,                            // 用户 FIFO 队列最大长度

  timelockDelay: 2n * 24n * 60n * 60n,             // Timelock 延迟，单位：秒
  proposers: [
    "0x1111111111111111111111111111111111111111", // Safe 多签提案地址
  ],
  executors: [
    "0x1111111111111111111111111111111111111111", // Safe 执行地址；也可填 address(0) 开放执行
  ],
  cancellers: [
    "0x1111111111111111111111111111111111111111", // Safe 取消提案地址
  ],
};
```

地址示例均为占位地址，正式发布时必须替换为目标网络上的真实地址。

字段说明：

| 字段 | 示例 | 说明 |
| --- | --- | --- |
| `productId` | `ethers.id("RWA-USDC-001")` | 全局唯一的产品 ID |
| `name` | `"Example RWA Token"` | ERC20 名称 |
| `symbol` | `"ERWA"` | ERC20 符号 |
| `stokenAdmin` | Safe 地址 | 必须是合约地址，负责 Token 业务管理 |
| `poolAdmin` | 管理员地址 | 跨链铸币/销毁权限，可为空 |
| `blacklistAdmin` | 管理员地址 | 黑名单角色地址，可为空 |
| `ccipAdmin` | CCIP 管理员地址 | CCIP 配置权限，可为空 |
| `assetRecipient` | 资金接收地址 | 申购资金接收方 |
| `assetSender` | 资金发送地址 | 赎回时提供稳定币的一方 |
| `serviceFeeRecipient` | 服务费地址 | 服务费接收方 |
| `supportedTokens` | `[USDC地址]` | 支持的 ERC20 地址数组 |
| `minSubscriptionAmount` | `100n` | 最小申购金额配置 |
| `minRedemptionAmount` | `ethers.parseEther("0.948")` | 最小赎回 Token 数量 |
| `maxQueueLength` | `100n` | 用户 Token FIFO 队列长度 |
| `timelockDelay` | `172800n` | Timelock 延迟，2 天，单位秒 |
| `proposers` | `[Safe地址]` | Timelock 提案人数组 |
| `executors` | `[Safe地址]` | Timelock 执行人数组；零地址表示开放执行 |
| `cancellers` | `[Safe地址]` | Timelock 取消人数组 |

校验要求：

- `productId` 不能为零且不能重复。
- `stokenAdmin`、`assetRecipient`、`assetSender`、`serviceFeeRecipient` 不能为零地址。
- `timelockDelay` 必须大于零。
- `proposers`、`executors` 不能为空。
- `stokenAdmin`、`proposers`、`cancellers` 必须是合约地址。

## 3. 部署 Token

单个部署：

```javascript
const tx = await factory.deployToken(config, salt);
const receipt = await tx.wait();
```

批量部署：

```javascript
const tx = await factory.batchDeploy(configs, salts);
const receipt = await tx.wait();
```

批量部署最多 5 个 Token。

## 4. 获取并核验部署结果

从 `TokenDeployed` 事件读取：

- `proxy`：新 Token 地址
- `timelock`：该 Token 的治理 Timelock 地址
- `implementation`：部署时使用的实现地址
- `productId`
- `salt`

核验以下状态：

```text
Token name / symbol
Token DEFAULT_ADMIN_ROLE = timelock
Factory 不再拥有 Token DEFAULT_ADMIN_ROLE
stokenAdmin 角色已授予目标治理地址
supportedTokens 配置正确
assetRecipient / assetSender 配置正确
```

## 5. 部署后准备

- 确认 Safe 拥有 Timelock 的 proposer/canceller 权限。
- 确认 executor 配置符合预期。
- 为 `assetSender` 配置稳定币余额和 Token allowance。
- 如使用跨链功能，确认 `poolAdmin` 和 `ccipAdmin` 已配置。
- 记录 Token、Timelock 和 implementation 地址。

## 6. 版本升级规则

发布新版 PlusFund implementation 时：

1. 部署新版 implementation。
2. 完成测试、审计和验证。
3. 由工厂管理员/多签调用 `setImplementation(newImplementation)`。
4. 后续新创建的 Token 使用新版实现。

`setImplementation()` 不会升级已部署 Token。已部署 Token 需要通过各自的 Timelock 执行 UUPS 升级。

## 7. 当前注意事项

- 工厂当前不是 Permissionless，普通用户需要先拥有 `DEPLOYER_ROLE`。
- `address(0)` 作为 executor 会开放 Timelock 执行权限。
- 当前 `blacklistAdmin` 角色配置与 PlusFund 实际 `blacklist()` 权限要求仍需保持一致后再作为正式合规流程使用。
