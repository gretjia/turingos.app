# R0_memo — Phase 0 调研备忘（R→D→S 自举件）

P0 自己也要过 R-stage：本备忘归档奠基决策的证据链。所有外部事实带验证日期；**验证结论本身会过期**（见 §4 的活教材）。

## 1. 宪法与上游运行时（2026-06-10 验证）

- 《TuringOS 宪法》1258 行逐字快照于 `constitution/constitution.md`（sha256 见 PINS.toml）。关键约束：Art.0 tape canonical / Art.I 谓词 {0,1} / Art.III 渐进披露与 Goodhart 屏蔽 / Art.V 三权分立。
- turingosv4（README/AGENTS.md/Cargo.toml，WebFetch）：ChainTape+CAS canonical；164 道宪法门禁；**bins-only 无 `[lib]` target**（→ ADR-009 车道 A/B）；签名栈 ed25519-dalek v2（→ 与 SE P-256 异构，key_kind 显式建模）；禁改写历史 evidence（→ ADR-007）。
- v1.2 工程计划（用户上传）：ADR-001~004 既定；PR #340 fail-closed identity 四态金标；Class 0-4 风险分级与 §8 ratification。

## 2. macOS 平台约束（2026-06-10，Apple 官方文档核查）

App Sandbox 子进程继承税 → MAS 不可行，Developer ID+公证+Hardened Runtime（盲点 #2）；SE 仅 P-256（OS 26 起增 ML-DSA，无 Curve25519）；SSH/FIDO2 git 签名可行；SMAppService per-user LaunchAgent + UDS 官方背书；FSEvents 合并/best-effort（盲点 #8）；TCC responsible-process 归因；GUI 进程不继承 shell PATH（盲点 #4）。

## 3. 平台目标（2026-06-10，WWDC26 公开信息）

macOS 27 "Golden Gate"：Liquid Glass 精修、仅 Apple Silicon、9 月 GM；Xcode 27 beta（27A5194q）：Swift 6.4、SwiftUI 自适应布局、agent 规划一等公民。**Beta 到 GM 会漂** → ADR-008 双轨（stable build lane 为 repo law；27 beta 仅 design preview lane）。

## 4. Claude Code 能力面（2026-06-10 重验，**含公开纠错**）

- **纠错记录**：本仓规划早期曾依据一次 agent 文档核查得出"WorktreeCreate/WorktreeRemove hooks 不存在"的结论，并据此设计了纯对账方案。用户终审指出与现行官方文档不符；重验（https://code.claude.com/docs/en/hooks）确认 **两个 hook 均存在**：WorktreeCreate 于 `--worktree`/`isolation:"worktree"` 触发、可替换默认 git 行为、必须返回绝对路径、非零退出即创建失败；WorktreeRemove 不可阻断、仅清理。hooks 体系共 31 事件。
- **教训入法**：M7 升级为"验证结论也会过期"——`verified_external_facts` 必须带 `verified_on` 日期；每个 Phase R-stage 重验其依赖面。
- **架构后果**：ADR-010 —— hooks 用于接管生命周期，但 canonical discovery 永远是 git registry + filesystem 对账（hooks 可被禁用/配错/缺席，且 Cursor/人类/脚本不经过它）。

## 5. 生态范式（2026-06-10）

- 官方 Remote Control 与第三方（Tactic Remote/CC Pocket/Nimbalyst）：进程留本机、移动端只是投影+审批面 → 主权宿主拓扑（ADR-011）。
- Codex：app-server 双向 JSON-RPC（progress/tool/approvals/diff 即 UI-ready events）为深集成首选；Codex worktrees 基于 git worktree、detached HEAD（用户终审引证，R5 复核钉版本）。
- GitHub 支持 GPG/SSH/S-MIME 签名 Verified 徽章 → P2 Git-native signing 路线成立。

## 6. P0 设计裁决小结

repo law 与 Claude developer 层分离（ADR-006）；contracts+fixtures 先于一切实现（"没有 fixture 的功能不许开工"）；P0 校验器诚实声明为 structural-subset；R→D→S 由 `guard_spec_alignment` 机械执行。
