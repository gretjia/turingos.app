# ADR — 架构裁决记录（001-011）

推翻任何一条须新增 ADR 条目并走 RATIFICATION_POLICY 对应层级，不得默改。

## ADR-001 控制面不是 IDE（承继 v1.2）
只做 Mission / Worktree / Identity / Proposal / Predicate / Ratification / Replay。Claude Code、Codex、Cursor 是执行器，不内嵌编辑器与终端复刻。

## ADR-002 git worktree = 共享物理层（承继）
所有 agent 与人类共用 git worktree 作为工作空间原语；App 不发明私有工作区格式。

## ADR-003 Git-backed ChainTape/CAS 是唯一 canonical truth（承继）
UI 状态、SQLite、内存缓存一律 derived projection：可删、可重建，并以守恒测试（`view == derive_from_tape(tape)`）背书。投影必须声明 `derive_source` / `schema_version` / `rebuild_command`（contracts/projection.schema.json 强制）。

## ADR-004 Fail-closed agent identity（承继，PR #340 对齐）
无 manifest → 拒；签名无效/冒名 → 拒；未注册 → observe-only。信任状态全集见 docs/TRUST_STATES.md。

## ADR-005 技术栈：SwiftUI 壳 + Rust `turingosd`
内核语义复用上游（见 ADR-009 车道）；GUI↔daemon = UDS + JSON-RPC，**事件订阅式**（UX 实时性反向塑形：纯请求响应不满足 Radar/仪式屏的流式需求）。Human Root 私钥只存在于 App 进程侧 Secure Enclave；daemon 只验签、永不持有人类根私钥。

## ADR-006 双层 Harness：repo law vs developer UX
- **Canonical Harness（repo law）**：`scripts/shipgate.sh` + `contracts/*.schema.json` + `fixtures/**` + `scripts/predicates/*.grep` + 确定性测试。**在无 Claude 的环境（CI、Codex、人类本地）可完整运行**，对一切贡献者一视同仁。
- **Claude Developer Harness（contributor UX）**：`.claude/{hooks,skills,agents}`，只是 Claude Code 贡献者的加速与防呆层，**绝不承载仓库法律**。
杜绝"只有 Claude Code 能正确开发本仓"的隐性锁定。

## ADR-007 Replay Rule Epoch / Legacy Evidence Guard（承继 v1.2 §3.5）
新验证规则 fail-closed forward 生效；历史链标 `legacy_pre_rule`，**绝不改判历史**。重放旧链用旧 epoch 规则。

## ADR-008 双轨平台目标
- **Stable Build Lane（repo law）**：CI 与对外构件使用最新稳定 Xcode；deployment target（macOS 26 或 27）由 R1 实证决定；**core contracts 禁止依赖 beta-only API**。
- **Design Preview Lane（探索）**：Xcode 27 beta（PINS.toml 钉版号）仅用于 DESIGN.md 研究、Liquid Glass 适配、快照原型；**不作为 release gate**。
- **arm64-only**：与 Golden Gate 仅 Apple Silicon 的方向、Secure Enclave 依赖、agent 算力假设一致。

## ADR-009 双仓契约
- `turingosv4` = constitutional runtime（ChainTape/CAS/replay/sequencer/market/verifier，canonical receipts/predicates/economic tx）。
- `turingos.app` = sovereign host（UX shell + daemon + adapters + projections）。
- 本仓**不得重定义 runtime truth、不得复制 canonical state logic、只能经 PINS.toml 钉死的 runtime interface 读写 receipts**。细则与集成车道（A：CLI-as-API 按 docs/CLI_ABI.md；B：上游 lib 化 PR 走上游 Class-3/4 流程）见 docs/UPSTREAM_CONTRACT.md。

## ADR-010 Worktree 真相层级
Claude Code 的 WorktreeCreate/WorktreeRemove hooks **存在且可用**（2026-06-10 官方文档实证，纠正本仓早期错误结论——见 research/R0_memo.md §4）：用于主动接管 Claude 管理的 worktree 生命周期。**但 hooks 不是 canonical source of truth**：canonical discovery 永远是 `git worktree` registry + filesystem 周期对账。理由：①用户可能不用 hooks；②Cursor/VS Code/人类/脚本不经过 Claude hooks；③hooks 可配错、被禁用、随版本变化；④worktree 的最终真相是 git + filesystem。

## ADR-011 三级 API（投影安全）
- **Projection API**：只读；无私钥、默认无 raw transcript、无隐藏评分内幕；可安全投射到远端/移动表面。
- **Action API**：typed action（contracts/typed_actions.schema.json）；策略检查；可要求本地签名人；**禁止任意命令转发**。
- **Signing API**：仅接受 canonical payload；显式人类确认；预留 m-of-n SignerSet（未来 iPhone SE 可注册为 Class-4 第二签名因子）。
未来 iOS/iPadOS/visionOS 客户端只消费 Projection + 提交 typed action + 签 canonical payload，**永不成为第二个 daemon**（主权宿主拓扑：Mac 持密钥/daemon/worktree）。字段分级见 docs/PROJECTION_POLICY.md。
