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
- **设计北极星 = macOS 27**（用户 2026-06-10 停机点裁定）：界面按 27 的 Liquid Glass 精修形态设计；27 rollout 预期快。
- **向下兼容 = deployment target macOS 26**："面向 27 设计、26 起可运行"。代码默认只用 26 可用 API；27 专属增强一律 `if #available(macOS 27)` 渐进增强，**禁止成为功能依赖**。
- **构建车道**：CI / 对外构件用最新稳定 Xcode（当前 26.5，PINS 钉版）；Xcode 27 beta 为 design preview lane（27 GM + runner 镜像就位后整体切换为主车道，届时只换工具链不改代码——以上"26 起可运行 + 渐进增强"纪律保证零返工）。
- **arm64-only** 不变。core contracts 禁止依赖 beta-only API（shipgate #6）不变。

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

## ADR-012 运行授权协议（用户 2026-06-10 当面裁定，PR #1 合并时授予）
- **自主域**：R→D→S 全流程的执行环节由执行 agent 自主决策执行——含 **repo law（shipgate + CI）全绿后的 PR 合并**。宪法约束与 harness 监督全程在场。
- **停机点（唯一例外）**：每个 Phase/Module 的 R-stage 调研思辨完成后、形成可执行细节（Atom 卡集）之前——**设计简报与关键裁决必须停机等用户确认**（"探讨"环节）；UX-heavy Phase 的设计评审属此列。
- **合并纪律**：FAIL 状态下无合并权，原文上报；合并方式保留分支历史（不 squash 宪法域锚定的 merge——T5 防线）。
- **权力边界**：本 ADR 不下放宪法权力——L3/L4 域动作（宪法/PINS/RATIFICATION_POLICY/本协议自身的变更）仍需用户显式批准。
- **增补（R1 停机点裁定）**：UI 设计为共创流程——执行 agent 出草图/效果图方案，**用户参与初期设计与测试**；UI 实现 Atom 在对应草图获用户认可前不开工（内核轨不受此限）。细则见 DESIGN.md「设计共创协议」。

## ADR-013 签名抽象层（硬件签名零重构预留，用户 2026-06-10 裁定）
- **法律**：一切签名/验签必须经统一抽象接口（Rust trait `Signer`/`Verifier`、Swift protocol 同构）：`key_kind() / fingerprint() / sign(canonical_payload) -> signature / attestation()`。业务代码（提案、仪式、回执、merge guard）**只依赖抽象，永不触碰具体算法/介质**。
- **key_kind 开放枚举**：`contracts/signature_receipt.schema.json` 的 key_kind 扩值 = minor 版本（加值向后兼容，contracts/README 既定规则）；未来硬件签名介质（FIDO2 token、外置 HSM、新 SE 形态、多设备 SignerSet 成员）以**新增 key_kind + 新 Signer 实现**接入，**底层与业务代码零重构**。
- **接线时点**：P2 第一颗签名 Atom 即以 trait 落地（SE-P256 与 ssh-ed25519 是首两个实现，本身就互为"第二调用方"——M1 满足）；attestation 字段在 receipt schema 预留 optional。
- **验收谓词**：P2 起 shipgate 增加"具体算法类型名不得出现在 daemon 业务模块"的 grep 谓词（只许出现在 signer 实现目录）。
