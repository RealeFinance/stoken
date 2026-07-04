# SAmMMF 合约升级公示五件套

公示日期：2026-07-05

本目录用于公示 SAmMMF 合约由上传的旧版实现 `VERSION_2` 升级至当前代码库实现 `VERSION_3.1.0` 的升级材料。

## 文件清单

1. [升级公告](./01-upgrade-announcement.md)
2. [代码差异说明](./02-code-difference-report.md)
3. [存储布局与权限核查](./03-storage-and-permission-review.md)
4. [升级执行清单](./04-upgrade-execution-checklist.md)
5. [风险与回滚预案](./05-risk-and-rollback-plan.md)

## 对比范围

本次对比基于上传的旧版 SAmMMF 合约与当前代码库中的新版实现，重点覆盖以下文件：

- `contracts/token/SAmMMF.sol`
- `contracts/Interfaces/ISAmMMF.sol`
- `contracts/base/BaseStorage.sol`

本材料仅作为合约升级前的公开说明和执行参考，最终执行仍应以链上治理、多签或 Timelock 的实际交易为准。

