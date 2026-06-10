# contracts/ — 机器契约（repo law 第一支柱）

App 消费什么事件、显示什么状态、哪些 action 合法——在写第一行 Swift/Rust 之前由本目录钉死。校验由 `scripts/validate_contracts.sh`（python3 stdlib 结构校验：type/required/enum/const/pattern）执行，进 shipgate #2-#4/#8。

**诚实声明**：P0 校验器是 JSON-Schema 的一个严格子集（不解析 `$ref`/`allOf` 等组合器），schema 编写保持在该子集内；完整 Draft 2020-12 校验在 Rust daemon（serde + schemars）落地时接管。子集不是冒充——shipgate 输出会注明 `structural-subset`。

## 演进规则

1. 每个实例必须带 `schema_version`（如 `tos.app.event.v0`）。
2. **加字段 = 向后兼容**，可在同版本内进行（消费者忽略未知字段）。
3. **删字段 / 改语义 / 改枚举值 = breaking**，必须 bump 版本号并保留旧版本 schema 文件供 replay 旧链（ADR-007 同构：不改判历史）。
4. 枚举扩值（如新增 event kind）= minor：允许，但 fixtures 必须同 PR 补覆盖。
5. schema 与 `docs/TRUST_STATES.md` 等人读文档冲突时，**以 schema 为准**并立即修文档。

## 文件索引

| 文件 | 锚定 |
|---|---|
| `event_stream.schema.json` | 事件信封：一切进 tape 投影管道的事件形态 |
| `typed_actions.schema.json` | 全部合法用户动作 + L0-L4 级别 |
| `projection.schema.json` | 投影三件套强制（derive_source/schema_version/rebuild_command） |
| `signature_receipt.schema.json` | 验签回执（verified=false 也是合法回执——失败即状态） |
| `ratification_payload.schema.json` | L4 canonical payload（human_readable_summary 为 required） |
| `predicate_result.schema.json` | verdict 锁死 {PASS,FAIL}；RiskFinding 独立通道 |
