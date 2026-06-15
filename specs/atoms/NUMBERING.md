# Atom 编号车道注册表（2026-06-12 立，用户授权 orchestrator 裁决）

并行会话共用一棵树，atom 编号按车道分配，禁止跨道取号：

| 车道 | 前缀/号段 | 归属 |
|---|---|---|
| Claude orchestrator | A1_14 – A1_55 | 本车道（Sprint 0-3 落地队列见 docs/04_ALPHA_EXECUTION_PLAN.md）；2026-06-14 经 orchestrator 裁决从 A1_39 扩到 A1_49，容纳回路2 执行回路垂直切片（A1_40–A1_45）；2026-06-14（二次）再扩到 A1_53：用户裁决执行序 3→2→1 把原 A1_49 卡设想的大捆绑 A1_50（逐分支节点+fork+LOD+gh-compare+merged-green）拆开——A1_50=gh-compare 诚实**关系观测**（daemon 基础；对抗复核 wf_ee716a30 证廉价 ancestry/PR **无法 sound 判 merged**[revert 让 mergeCommit 仍可达却内容已撤]，故范围收敛为「只发 merge_status/ahead/behind/contained 中性观测，merged_into_default 恒 false」）、A1_51=galaxy 逐分支节点+fork DAG+语义 LOD+中性渲染、A1_52=回路2 接 Orb+真机端到端、A1_53=sound merged-green（内容/树级核验或人工确认信号；廉价信号路已死，另立认真做对）；2026-06-14（三次，无限缩放望远镜，ADR-016 + research/R1_infinite_zoom_memo.md）再扩到 A1_55：A1_51 经对抗复核拆为 **A1_51a**（相机骨架 tldraw+log-zoom+floating-origin）/ **A1_51b**（分支+commit 节点派生+星系/泳道布局）/ **A1_51c**（Metal 实例化+LOD+tile-tree+DeferredRef）/ **A1_51d**（V6 美学），原 A1_51 卡标 superseded（superseded_by + 留痕）；**A1_52 重指派**为 daemon commit/commit-graph 观测（galaxy commit 层底座，A1_50 姊妹原子——深读实锤 daemon 今天最深只到分支顶点、无 per-commit 事件）；原 A1_52「回路2 接 Orb+真机端到端」顺延至 **A1_54**；A1_53=sound merged-green 不变。执行序：A1_51a ∥ A1_52（独立 lane，谁先都行）→ A1_51b → A1_51c → A1_51d（b/c/d 共享 RadarViews/DesignTokens，严格一次一颗 CURRENT，不并行） |
| Codex 接续会话 | C1_01 起（C 前缀） | Codex 自建 AGENTS/INIT 与接手工作 |
| 历史 | A0_*、A1_01–A1_13 | 已收口，不再复用 |

冲突规则：**已提交（committed）的卡片拥有编号**；未提交的撞号卡片由其会话改名。
现存事实：`A1_13_codex_init.md`（Codex 会话，未跟踪）与已提交的 A1_13（whitepaper v0.5）
撞号——按本规则应由 Codex 会话改名为 C1_01_codex_init.md；其文件本注册表不代动。
