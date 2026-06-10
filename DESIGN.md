# DESIGN — UX 宪章（体验维度的根文档）

UI/UX 与美学是独立且贯穿全程的一等任务。本文档与 `docs/NAVIGATION_MODEL.md`（去哪）、`docs/VISUAL_SEMANTICS.md`（看见什么颜色）、`docs/TRUST_STATES.md`（徽章语义）、`docs/RATIFICATION_POLICY.md`（何时签名）共同构成体验维度法律。

## Software 3.0 UX 范式

1. **用户是 agent 群体的治理者，不是工具操作员。** 界面呈现证据与签名（回执、溯源链、谓词裁决），而不是替用户干活的黑箱按钮（M8）。
2. **Ambient / 异步优先。** Agent 以分钟-小时工作：可瞥视（菜单栏常驻面）、通知驱动、永不模态阻塞人类。
3. **信任校准是视觉系统的主轴。** 签名状态/信任态是一等视觉语言：全产品唯一 badge 体系（TRUST_STATES × VISUAL_SEMANTICS），任何页面不得自造红黄绿。
4. **失败即状态。** 拒绝、否决、验签失败都上 tape、都有界面呈现——不存在"消失的失败"。

## 五个关键 UX 时刻

| 时刻 | 用户问题 | 表面 |
|---|---|---|
| **Glance** | 一切健康吗？ | 菜单栏常驻 + Global Ops；零点击得到答案 |
| **Review** | 这个提案凭什么过？ | 证据链（谓词裁决/签名/溯源）优先于 raw diff 的分层呈现 |
| **Sign** | 我正在行使宪法权力 | **L4 全注意力仪式屏**：人类可读 payload 摘要 + canonical hash + 后果声明。体感上必须与普通确认不同；仪式稀缺性由 RATIFICATION_POLICY 保障 |
| **Replay** | 当时发生了什么？ | 时间轴拖动重放 tape 区间；一切投影可重建的可视化证明 |
| **Onboard** | 如何把项目交给系统？ | 添加项目 + 身份注册首程；fail-closed 默认（未注册 agent 自动 observe-only）以可理解的方式呈现 |

## 双轨法

每个 Phase 的 R-stage 必须同时回答**内核问**（实现什么）与**体验问**（入口/可见性/参与方式），并把 UX 对内核的反向塑形登记进 PLAN.md 登记簿。已立法的三例：仪式屏 → payload 强制 `human_readable_summary`（schema required）；实时 Radar → IPC 事件订阅式（ADR-005）；Replay 拖动 → tape 范围查询 API（P6 约束）。

## 美学的可门禁化

- **Design tokens 单文件**（P1 起）：颜色/字阶/间距/动效预算集中定义，杜绝散落魔数。
- **快照金标测试**：关键视图 golden screenshot 比对，进 shipgate（P1 起）。
- **可达性 0/1 谓词**：VoiceOver 标签覆盖率、对比度阈值——机器可判，进 shipgate。
- **主观美学**永远走 R-stage 人类设计评审与 RiskFinding 通道，**绝不冒充谓词**（M6/M8）。

## 设计共创协议（用户 2026-06-10 裁定，ADR-012 增补）

UI 设计从草图开始共创：**执行 agent 出方案（草图/效果图，落盘 `design/mockups/<phase>/`）→ 用户参与初期设计与测试 → 认可后才开 UI 实现 Atom**。内核轨（daemon/契约/数据通路）不受此限可并行。效果图是证据不是装饰：每轮方案带变体对比与取舍说明，用户的裁定记录进对应 R-stage 简报。

## Generative UI 北极星（独立调研中）

用户裁定：generative UI 是 Software 3.0 人机交流的基石策略，直接面向未来设计。独立 R-stage 调研进行中（产出 `research/R_GENUI_memo.md`）；其设计法律（生成区域的信任边界、与确定性仪式屏的关系、typed 组件调色板等）经停机点确认后并入本宪章。**在此之前的既定底线**：签名仪式屏（L4）永远确定性渲染，永不生成。

## 平台语言与扩展姿态

- Liquid Glass（macOS 26 引入、27 Golden Gate 精修）：Design Preview Lane（ADR-008）持续适配研究；细则由 R1 设计简报钉死。中文/英文双语一等公民。
- **主权宿主拓扑**（ADR-011）：Mac 持密钥/daemon/worktree；未来 iOS/iPadOS/visionOS 仅为投影+审批面（消费 Projection API + 签 canonical payload）。第一阶段不写一行移动代码，但协议层从今天起 projection-safe。
