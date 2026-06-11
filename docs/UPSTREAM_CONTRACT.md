# UPSTREAM_CONTRACT — 内核边界契约（ADR-015 后的仓内法律）

> 历史沿革：本文件原为双仓契约（ADR-009）。用户 2026-06-11 终裁完全移植（ADR-015）后，**仓界变为目录界**：`runtime/` = 宪法内核（完整版 turingosv4 @ PINS 钉定 rev），其余 = 主权外壳（daemon / SwiftUI / contracts / harness）。三铁律语义不变，约束对象从"两个仓"变为"一仓两域"。本文件防止外壳逐渐长出自己的"小 tape、小 market、小 wallet、小 replay"而成为第二部宪法。

## 三条铁律（仓内版）

1. **外壳不复制 canonical state logic。** ChainTape 追加、CAS 寻址、replay 验证、sequencer 裁决、market 结算的实现只存在于 `runtime/`。外壳如需这些语义，调用 runtime 接口；接口不够，开 runtime 侧 atom（受其全部宪法门禁约束），**不在外壳重写**。
2. **外壳只经声明接口消费内核。** `turingos` CLI（按 [CLI_ABI.md](CLI_ABI.md)；审计结论 1/29 全合规——非合规命令标 non-conformant 隔离适配，逐命令改造排程独立车道）或显式 atom 添加的 lib facade。**外壳代码 import runtime internals = grep 谓词红线**（A1_9_2 起 shipgate 强制）。
3. **任何外壳投影必须声明三件套**：`derive_source` / `schema_version` / `rebuild_command`。contracts/projection.schema.json 强制；shipgate #3 机械校验。无三件套的"状态"不允许存在。

## 内核域纪律

`runtime/` 的全部宪法门禁 + workspace 测试 = 本仓 CI 的 runtime lane（内核的宪法随内核迁居）；触碰 runtime 受限面（门禁覆盖区）的 atom 沿用 v4 的 Class-3/4 + §8 ratification 纪律，本仓 harness 无权旁路。

## 边界判例（先例，遇新情况类推并增补）

| 场景 | 裁决 |
|---|---|
| App 想缓存 worktree 列表加速渲染 | 允许：投影 + 三件套 + 守恒测试 |
| App 想给 proposal 加一个上游没有的状态字段 | 拒绝：先在上游 schema 提案；app 私有字段只能进 `app_annotations` 命名空间且不参与任何裁决 |
| daemon 想本地结算 market 余额 | 拒绝：结算是 canonical 语义，observe-only 投影即可 |
| App 想在上游不可达时"暂记"一笔 ratification | 拒绝：fail-closed，仪式不可用就是不可用 |
