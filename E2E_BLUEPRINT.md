# E2E_BLUEPRINT — 终局对抗蓝图与盲点登记簿

终局验收不是"功能都能点"，而是系统在对抗与混沌下仍满足宪法不变量。三级递进：

## L1 合成混沌

- fixture 农场（`fixtures/`）驱动全部确定性重放。
- 并发 lease 抢占：双 agent 抢同一 WorktreeSlot 必恰好一胜一败。
- `kill -9 turingosd` 于任意写入中途 → 重启后全部投影从 tape 重建，守恒测试绿。
- FSEvents 万级事件风暴 → 背压不丢对账（周期对账兜底收敛）。
- 磁盘满时 CAS 写入 → fail-closed（拒绝并留痕，不静默截断）。
- App Nap / 内存压力 / 效率核调度下的 daemon 心跳与重连。

## L2 对抗渗透（docs/THREAT_MODEL.md 全场景升格为 E2E）

- 伪签名 / 冒名 manifest / 缺 manifest → 三路全拒且 trust_state 正确呈现。
- 重放旧签名回执 → 拒（nonce/seq 防重放）。
- 强行 squash `v4-ratify-*` signed tag 所锚定的 merge → 拒并告警。
- 篡改历史 ref → 审计 panic（绝不静默修复）。
- Goodhart 探针：被评测 agent 实测不可读取评分函数与隐藏政策路径。
- 巨文件/二进制炸弹 worktree → Radar 不卡死、diff hash 分级处理。

## L3 真实全流程宪法基准

真实入口走通：App 添加项目 → Claude Code 与 Codex 各领 WorktreeSlot → 产出签名 WorkTx → Predicate {PASS,FAIL} + Veto {PASS,VETO} 双闸 → merge / reject 上 tape → Replay 重建全程。基准任务采 SWE-bench Lite 子集级别的真实仓库任务。**诚实报告纪律**：上游曾有 "loop 0/3" 失败先例被如实记录——报忧是宪法义务，绿色虚荣指标无效。

## 盲点登记簿（活文档，R-stage 持续增补）

| # | 盲点 | 处置 | 状态 |
|---|---|---|---|
| 1 | ~~Claude worktree hooks 不存在~~ → **实证纠错：存在**（31 事件体系） | ADR-010：hooks 接管生命周期，但 canonical = git+FS 对账 | 已纠正 2026-06-10 |
| 2 | App Sandbox 子进程继承税 → MAS 不可行 | Developer ID + 公证 + Hardened Runtime（每个 Mach-O 都签）；不上 MAS | ADR 化 |
| 3 | 签名算法异构：上游 ed25519 vs SE 仅 P-256 | key_kind 显式建模（docs/TRUST_STATES.md）；SE-P256 用于 App 域 L3/L4，上游互通 ssh-ed25519 | P2 实现 |
| 4 | GUI 进程不继承 shell 环境 | login shell 工具发现（VS Code 同款模式）；TCC responsible-process 归因 | P5 实现 |
| 5 | UDS 本地提权面 | socket 0600 + peer credential + per-user LaunchAgent + 默认无 root + 人类根私钥永不进 daemon（THREAT_MODEL UDS 五件套） | P2/P5 门禁 |
| 6 | 上游 bins-only 无 lib target | 车道 A：CLI-as-API 严格按 docs/CLI_ABI.md；车道 B：上游 lib 化 PR 走上游流程 | ADR-009 |
| 7 | 双仓真相分裂 | PINS.toml 钉 rev + shipgate 校验；UPSTREAM_CONTRACT 三铁律 | shipgate #1/#6 |
| 8 | FSEvents 是 best-effort 提示 | 周期全量对账兜底（与 #1 同一机制一份代码） | P1 实现 |
| 9 | Legacy replay epoch 与 q_t capsule 隐私 | ADR-007；redaction manifest / visibility class 于 P6 R-stage 设计 | 登记 |
| 10 | Beta SDK 漂移（Golden Gate GM 前 API 可变） | ADR-008 双轨；contracts 禁 beta-only API（shipgate #6） | shipgate 化 |
| 11 | 签名疲劳侵蚀 L4 仪式的意义 | RATIFICATION_POLICY 五级分层 + L4 白名单 | P0 立法 |
