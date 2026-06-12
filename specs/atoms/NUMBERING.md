# Atom 编号车道注册表（2026-06-12 立，用户授权 orchestrator 裁决）

并行会话共用一棵树，atom 编号按车道分配，禁止跨道取号：

| 车道 | 前缀/号段 | 归属 |
|---|---|---|
| Claude orchestrator | A1_14 – A1_39 | 本车道（Sprint 0-3 落地队列见 docs/04_ALPHA_EXECUTION_PLAN.md） |
| Codex 接续会话 | C1_01 起（C 前缀） | Codex 自建 AGENTS/INIT 与接手工作 |
| 历史 | A0_*、A1_01–A1_13 | 已收口，不再复用 |

冲突规则：**已提交（committed）的卡片拥有编号**；未提交的撞号卡片由其会话改名。
现存事实：`A1_13_codex_init.md`（Codex 会话，未跟踪）与已提交的 A1_13（whitepaper v0.5）
撞号——按本规则应由 Codex 会话改名为 C1_01_codex_init.md；其文件本注册表不代动。
