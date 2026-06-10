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

## Generative UI 八条设计法律（R_GENUI §6，用户 2026-06-10 批准并入）

全部可机械判定；推翻任何一条须新 ADR + 对应层级批准（R1 为 L4）。判定细则见 `research/R_GENUI_memo.md` §6。

- **R1 — 永久禁止 Level (c)**（模型字符串→可执行视图/eval/WebView 执行通道 grep=0；layout 只经 `layout_dsl.schema.json` 反序列化为白名单组件）。推翻须新 ADR + L4。
- **R2 — 仪式屏永远确定性渲染**（仪式管线无 LLM 调用；`render_ceremony(payload)` 纯函数双渲染 sha256 一致；渲染输入与 §8 token 一并上 tape）。
- **R3 — 生成区必带 `generated` 徽章 + 折叠 provenance**；用 gray 语义，禁止 green/purple；永不与 verified 混排。
- **R4 — 生成式只在解释/编排层，永不进裁决层**（Predicate/Veto/信任徽章/签名回执渲染组件为审计白名单，数据绑定只来自 typed projection 字段）。
- **R5 — layout DSL 必须 schema 校验 + 上 tape + fail-closed**（校验失败→不渲染+RiskFinding，禁止尽力渲染）。
- **R6 — 生成区只引用 read-only 投影 + L≤2 action**；永不自带"已签名"语义；L3/L4 入口不得出现在 generated 子树。
- **R7 — App Intents 仅限 L0/L1**；L3/L4 永不可被 Siri/Spotlight 一句话触发（intent 注册表 × typed_actions level 交叉校验，level≥3 有对应 intent 即门禁红）。
- **R8 — 生成文本过语言门禁 + 必须并置原始证据**（market-claim 门禁对生成文本生效；生成摘要节点旁必有可展开证据节点）。

## Software 3.0 三定律（用户 2026-06-10 五次裁决，信息架构最高法）

用户裁定：此前稿件犯 Software 1.0/2.0 **看板哲学**根本错误（数据轰炸、抓不住重点），
以 Software 3.0 理念重构；执行 agent 获设计自主权（V6 降格为材质参考）。三定律：
**①注意力优先**（每屏只回答"我现在需要行动吗？对什么？"）**②语言优先**（投影的人类
形态=可下钻的一句话结论，不是计数网格）**③安静即成功**（一切健康时界面近乎空）。
完整宪章与反模式黑名单：`design/SOFTWARE3_UX.md`。

## V6 材质语言参考（用户自绘，2026-06-10 批准；五次裁决降格为参考）

星系美学（项目=星云、worktree=节点、主干=轨道）、Litho-Glass、语义发光、语义缩放的
**材质与隐喻**继续沿用（`design/mockups/v6/` + `design/V6_RECONCILIATION.md` 对账表）；
**信息密度与层级不再忠实复刻 V6**——由 Software 3.0 三定律治理（V6 原稿的多行数据卡、
等权重计数网格属看板形态，已被五次裁决否定）。TRUST_STATES × VISUAL_SEMANTICS 仍是
徽章与状态色的唯一法源。

## Onboard 流程（用户 2026-06-10 裁定）

「如何把项目交给系统」定型为三段：①**Connect**——优先无缝复用用户既有 git 体系（gh CLI 登录态 → GitHub Device Flow → 纯本地模式，逐级降档、fail-visible）；②**Select**——列出用户全部 repo（GitHub + 本地发现），用户勾选纳管哪些（开发完结的可不纳入）= 批量 RegisterProject(L1)；③**Observe**——进入 Global Workspace 全景面板，默认压缩态（语义缩放宏观视角），可整体观察、（P4+）派发任务，或点入单项目放大操作。auth token 永不入 tape/事件流。

## 平台语言与扩展姿态

- Liquid Glass（macOS 26 引入、27 Golden Gate 精修）：Design Preview Lane（ADR-008）持续适配研究；细则由 R1 设计简报钉死。中文/英文双语一等公民。
- **主权宿主拓扑**（ADR-011）：Mac 持密钥/daemon/worktree；未来 iOS/iPadOS/visionOS 仅为投影+审批面（消费 Projection API + 签 canonical payload）。第一阶段不写一行移动代码，但协议层从今天起 projection-safe。
