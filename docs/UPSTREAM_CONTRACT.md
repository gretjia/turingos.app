# UPSTREAM_CONTRACT — 与 turingosv4 的双仓契约（ADR-009 细则）

`turingosv4` = constitutional runtime。`turingos.app` = sovereign projection & control surface。本文件防止本仓逐渐长出自己的"小 tape、小 market、小 wallet、小 replay"而成为第二部宪法。

## 三条铁律

1. **不复制 canonical state logic。** ChainTape 追加、CAS 寻址、replay 验证、sequencer 裁决、market 结算的实现只存在于上游。本仓如需这些语义，调用上游接口；如上游接口不够，走车道 B 提 PR，**不在本仓重写**。
2. **只经 pinned runtime interface 读写 receipts。** 消费的上游 rev 必须钉死在 `constitution/PINS.toml`（`[upstream.turingosv4].rev`），UNPINNED 状态下禁止消费任何上游接口。升 rev = 一次显式提交 + 兼容性验证。
3. **任何 app-side projection 必须声明三件套**：`derive_source`（从何派生）、`schema_version`、`rebuild_command`（如何从 canonical truth 一键重建）。contracts/projection.schema.json 把这三项设为 required；shipgate #3 机械校验。无三件套的"状态"不允许存在。

## 集成车道

- **车道 A（默认）**：`turingos` CLI-as-API，输出契约严格按 [CLI_ABI.md](CLI_ABI.md)。
- **车道 B（演进）**：上游 lib 化（增加 `[lib]` target）PR；触及上游受限面（164 门禁覆盖区）严格走上游 Class-3/4 + §8 ratification 流程，本仓无权旁路。

## 边界判例（先例，遇新情况类推并增补）

| 场景 | 裁决 |
|---|---|
| App 想缓存 worktree 列表加速渲染 | 允许：投影 + 三件套 + 守恒测试 |
| App 想给 proposal 加一个上游没有的状态字段 | 拒绝：先在上游 schema 提案；app 私有字段只能进 `app_annotations` 命名空间且不参与任何裁决 |
| daemon 想本地结算 market 余额 | 拒绝：结算是 canonical 语义，observe-only 投影即可 |
| App 想在上游不可达时"暂记"一笔 ratification | 拒绝：fail-closed，仪式不可用就是不可用 |
