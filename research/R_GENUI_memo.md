# R_GENUI_memo — 生成式 UI 作为 Software 3.0 的 HCI 基石：对 TuringOS.app 的调研备忘

> 调研日期：2026-06-10。除非另注，所有 "(verified 2026-06-10)" 均指当日通过 WebSearch/WebFetch 实证。凡未能取得一手确认者，显式标注 **UNVERIFIED** 或 **[二手]**。
> 与本仓法律的接口：本备忘的结论必须落在 typed projection / {PASS,FAIL} predicate / fail-closed / 证据非黑箱（M8）/ 唯一 badge 体系（VISUAL_SEMANTICS）/ L0–L4（RATIFICATION_POLICY）之内。任何与之冲突的"业界最佳实践"在此被显式拒绝。

---

## 0. TL;DR（先给裁决，再给证据）

1. 2025–2026 全行业已经收敛到一个共识，而且这个共识恰好就是 TuringOS 的架构：**生成式 UI = 模型产出受约束的声明式数据（typed JSON），由宿主用一份"可信组件目录（trusted component catalog）"渲染；模型不执行任意代码。** 三个独立阵营（Google A2UI、Anthropic/OpenAI 的 MCP Apps、Vercel）都把"任意代码生成"当作要规避的安全风险，而非卖点。
2. 因此对 TuringOS 而言，正确的插入点是 **Level (a)+(b)：模型从一份经审计的 SwiftUI 组件注册表里组合布局，产出一段声明式 layout DSL(JSON)，该 DSL 本身被 schema 校验 + 上 tape**。Level (c)（运行时生成新交互代码）**应永久拒绝**——它与 fail-closed、与可重放、与签名仪式的确定性根本冲突，且已有 CHI 2025 实证显示其会无提示地产出欺骗性设计。
3. **仪式屏（P3 Ratification Center）永远确定性渲染，永不进入生成式管线**——这是不可推翻的设计法律，下文给出 8 条可证伪规则。

---

## 1. State of the art 2025–2026：业界"生成式 UI"到底指什么

### 1.1 三个层级的精确定义（本备忘后续统一沿用）

- **Level (a) Schema-driven composition**：LLM 从一组**预定义组件**里挑选并填参（function/tool calling → 组件）。
- **Level (b) Runtime layout/view from typed data**：LLM 从 typed data 在运行时产出**布局/视图的声明式描述**（JSON DSL），宿主用本地原生组件渲染，**不执行模型产出的代码**。
- **Level (c) Novel interactive code-gen**：LLM 当场生成新的、可执行的交互代码（HTML/JS/任意逻辑）。

> 结论 — 行业 2026 的主流框架几乎一致地把产品化能力锁在 (a)+(b)，把 (c) 标记为安全风险。 — Google A2UI README / 开发者博客（verified 2026-06-10），https://github.com/google/A2UI ，https://developers.googleblog.com/a2ui-v0-9-generative-ui/

### 1.2 Vercel AI SDK（generative UI / RSC）

> 结论 — Vercel AI SDK 用 `streamUI` + Zod typed tools 把 LLM 响应映射到 React 组件（tool 返回 ReactNode 而非字符串），是 Level (a) 的范式实现。 — ai-sdk.dev streamUI 文档（verified 2026-06-10），https://ai-sdk.dev/docs/reference/ai-sdk-rsc/stream-ui

> 结论 — 但 **AI SDK RSC 当前"开发暂停（development paused）/ experimental"，官方建议生产用 AI SDK UI**；暂停原因是工程性而非概念性：无法 abort 流、组件重挂载、多 Suspense 崩溃、二次（quadratic）数据传输。 — ai-sdk.dev 迁移文档 + Vercel 社区（verified 2026-06-10），https://ai-sdk.dev/docs/ai-sdk-rsc/migrating-to-ui ，https://community.vercel.com/t/ai-sdk-rsc/29082
>
> **对 TuringOS 的启示**：连最激进的"流式服务端组件"路线都因为流控/重渲染/传输成本退守。我们的事件流→投影→视图管线本就是订阅式 + 确定性快照，不该照搬推流式生成；这反而印证了"先校验再渲染、可重建快照"的路线更稳。

### 1.3 OpenAI ChatGPT Apps SDK（2025-10）

> 结论 — OpenAI Apps SDK（2025-10 发布）扩展 MCP，让 MCP server 返回**自定义 UI 组件**，运行在 ChatGPT 内的 **sandboxed iframe**，通过 **MCP Apps bridge（JSON-RPC over postMessage）** 与宿主通信。 — OpenAI Developers / OpenAI 博客（verified 2026-06-10），https://developers.openai.com/apps-sdk ，https://openai.com/index/introducing-apps-in-chatgpt/

> 结论 — 安全姿态：widget 跑在 **strict CSP 的 sandboxed iframe**；子 iframe 默认禁止，仅当 `_meta.ui.csp.frameDomains` 显式放行才允许，且这类 app **额外人工审查、通常不获广泛分发批准**。 — OpenAI Apps SDK Security/Privacy 文档（verified 2026-06-10），https://developers.openai.com/apps-sdk/guides/security-privacy

> 结论 — 关键 UX 原则（直接对应我们 M8）：**data tool 与 render tool 分离**——data tool 返回完整 `structuredContent` 供模型推理，render tool 只拿"已定稿数据"贴模板；组件应从真实的 `structuredContent` 渲染，而**非模型臆造的内容**；并要求 tool 输出附带 IDs/timestamps/status 供模型推理。 — OpenAI Apps SDK UX principles（verified 2026-06-10，经 WebSearch 摘要确认；页面对 WebFetch 返回 403，故标 **[二手but官方域名]**），https://developers.openai.com/apps-sdk/concepts/ux-principles

### 1.4 Anthropic / MCP Apps（2026-01-26，行业标准化时刻）

> 结论 — 2026-01-26，MCP Apps 作为 **MCP 官方扩展（SEP）** 标准化：tool 可返回交互式 UI（dashboards/forms/可视化/多步工作流）。**UI 是服务端预声明的模板（`ui://` scheme 提供 bundled HTML/JS），不是运行时生成的代码**；宿主 fetch 资源、在 **sandboxed iframe** 渲染、**JSON-RPC over postMessage** 双向通信。 — MCP 官方博客（verified 2026-06-10），https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/

> 结论 — MCP Apps 的四层安全模型（与 TuringOS 高度同构）：① 所有 UI 跑在受限权限的 sandboxed iframe；② **宿主可在渲染前审查 HTML（pre-declared templates）**；③ **所有 UI↔host 通信走可记录（loggable）的 JSON-RPC**；④ 宿主可对 UI 发起的 tool call **要求显式批准**。首发客户端：Claude（web+desktop）、Goose、VS Code Insiders 当日可用，ChatGPT 同周接入。 — 同上 + The Register（verified 2026-06-10），https://www.theregister.com/2026/01/26/claude_mcp_apps_arrives/

> 结论 — Anthropic Artifacts 侧：MCP 集成 + 持久存储已在 Pro/Max/Team/Enterprise 开放；**所有 action 要求显式用户批准**。 — Anthropic 新闻 + 支持中心（verified 2026-06-10），https://www.anthropic.com/news/build-artifacts ，https://support.claude.com/en/articles/9487310

### 1.5 Google（A2UI，2025-12-22）

> 结论 — Google A2UI（2025-12 开源，截至调研为 v0.8/v0.9 Public Preview）让 agent "speak UI"：发送**声明式 JSON** 描述组件/布局/数据绑定，客户端用原生组件（Angular/Flutter/Lit）渲染。**显式设计哲学："运行 LLM 生成的任意代码可能有安全风险。A2UI 是声明式数据格式，不是可执行代码。"** 客户端维护**可信、预批准组件目录（Card/Button/TextField…），agent 只能引用目录内类型**。 — Google Developers Blog + A2UI README（verified 2026-06-10），https://developers.googleblog.com/introducing-a2ui-an-open-project-for-agent-driven-interfaces/ ，https://github.com/google/A2UI

> 结论 — A2UI 用 ID 引用以便 LLM **增量生成 / 渐进渲染**；已用于 Opal、Gemini Enterprise、Flutter GenUI SDK 等生产系统（**[二手]**，来源未给逐条生产证据）。 — 同上 / CopilotKit（verified 2026-06-10），https://www.copilotkit.ai/blog/build-with-googles-new-a2ui-spec-agent-user-interfaces-with-a2ui-ag-ui

### 1.6 学术框架（adaptive UI / model-driven UI）

> 结论 — "生成式/自适应 UI"在学术上有长谱系：CAMELEON、SUPPLE、MyUI 等 model-driven 自适应 UI（尤其面向无障碍/老龄）；ACM Computing Surveys 有 "Adaptive Model-Driven User Interface Development Systems" 综述。近期把 LLM 接入 MDE 管线（UICoder 迭代生成合法 HTML/CSS 等）。 — arXiv / ACM（verified 2026-06-10），https://dl.acm.org/doi/10.1145/2597999 ，https://arxiv.org/pdf/2508.19227 （"Generative Interfaces for Language Models"）

> 结论 — 数据-自适应方法的核心机制是"**用开发者定义的约束扩展数据模型，在预期上下文输入下生效，产出 context-aware 动态界面**"——即"约束化生成"，而非自由生成。这正是 (b) 的学术表述。 — arXiv 2110.01781 等（verified 2026-06-10），https://arxiv.org/pdf/2110.01781

### 1.7 哪些已被生产验证 vs 仍是研究？

| 层级 | 代表 | 状态（2026-06） |
|---|---|---|
| (a) schema-driven 选组件 | Vercel streamUI tools；MCP Apps 预声明模板 | **生产验证**（多客户端已发） |
| (b) typed data → 声明式 layout DSL，原生渲染、不执行代码 | **A2UI**、Apple App Intents Snippets（见 §2） | **生产/准生产**（A2UI 仍 Preview，但路线明确且最贴合我们） |
| (c) 运行时生成新交互代码 | Artifacts 的 code execution、"vibe-coded" app、VibeOS 类 | **研究/演示，且带已证实风险**（见 §3） |

---

## 2. Apple-native 视角：SwiftUI 里有什么"模型/服务端驱动 UI"

### 2.1 SwiftUI 的数据驱动本质与动态布局原语（都是确定性的）

> 结论 — SwiftUI 提供 `ViewThatFits`（在候选视图里选第一个"装得下"的）与 `AnyLayout`（在保持子视图 identity 的前提下在布局类型间切换）。这些是**确定性、数据驱动**的自适应原语，**不是生成式**——源自 WWDC22 而非新 AI 能力。 — Hacking with Swift / Apple WWDC22（verified 2026-06-10），https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-an-adaptive-layout-with-viewthatfits ，https://developer.apple.com/videos/play/wwdc2022/10056/
>
> **启示**：我们的"自适应"99% 应由确定性手段满足；"生成式"只在真正需要"模型决定呈现什么证据/摘要"时才动用。

> 结论 — 第三方 SwiftUI server-driven UI（JSON→SwiftUI 视图）是成熟社区模式，但属 **(b) 的弱形式**，默认无信任分区/无 provenance/无 tape，**不可直接采纳**。 — 社区文（verified 2026-06-10），https://blog.jacobstechtavern.com/p/backend-driven-swiftui

### 2.2 App Intents / Apple Intelligence（WWDC25）——Apple 给出的"正确答案"

> 结论 — WWDC25 把 **App Intents 定位为 typed action 协议**：把动作与 entity 暴露给 Apple Intelligence/Spotlight/Shortcuts。**关键架构区分：App Intents 调用 typed intents，而不是让模型直接组合 app UI。** — Apple WWDC25 Session 275（verified 2026-06-10），https://developer.apple.com/videos/play/wwdc2025/275/

> 结论 — `SnippetIntent` 返回的是**应用自己提供的 SwiftUI View，由系统渲染**；模型/系统**不合成 app 的 UI**。Apple 话术："intents define **what** the app does, views define **how** that displays"。 — 同上（verified 2026-06-10）
>
> **这是对 TuringOS 架构的最强外部背书**：Apple 自家 AI 栈 = typed Action API + 应用提供的确定性视图，与"read-only Projection API + typed Action API（L0–L4）"逐字对应。

### 2.3 macOS 26/27 改变的用户期待

- **动作可被系统 AI 唤起** → L0/L1 做成 App Intents；**L3/L4 永不暴露为 Siri 可一句话触发的 intent**。
- **屏上内容可被 AI 追问** → 投影对象可结构化导出（read-only、带 provenance）。
- **Liquid Glass 视觉** → generated 徽章在该材质下仍需对比度达标（0/1 谓词覆盖）。

> **UNVERIFIED**：WWDC26 / macOS 27 的具体 AI-composed-interface 能力——截至 2026-06-10 无一手 Apple 文档确认，不得作为设计依据。

---

## 3. 治理类 app 的生成式 UI 信任与安全：先例与教训

### 3.1 已证实的失效：生成式 UI 会无提示地产出欺骗性设计

> 结论 — CHI 2025《"Create a Fear of Missing Out": ChatGPT Implements Unsolicited Deceptive Designs in Generated Websites Without Warning》：20 名参与者用**中性 prompt** 生成网站，**20/20 个至少含 1 个欺骗性设计（均 5 个、最多 9 个），GPT-4 全程无警告**；事后**仅 20% 用户表达担忧**。 — ACM CHI 2025 / arXiv 2411.03108（verified 2026-06-10；全文 403，数字经两次独立摘要交叉确认，标 **[摘要级]**），https://dl.acm.org/doi/abs/10.1145/3706598.3713083

> 结论 — 《Hidden Darkness in LLM-Generated Designs》（arXiv 2502.13499）：跨 4 模型生成 312 个电商组件，**逾 1/3 至少含 1 个 dark pattern**，且与公司利益相关的组件更易产出。 — arXiv（verified 2026-06-10），https://arxiv.org/html/2502.13499v1
>
> **直接含义**：在"UI 即治理界面"的 app 里，让模型自由生成可执行 UI = 主动引入 dark pattern 与不可问责表面；80% 用户察觉不到 → 必须**结构性禁止 (c)**，并让生成区域**视觉上必然区别于 verified 状态**。

### 3.2 可借鉴的正向先例

1. **声明式数据 + 可信组件目录**（A2UI、MCP Apps）→ 映射：经审计 SwiftUI 组件注册表 + typed layout DSL。
2. **typed action + 显式批准**（MCP Apps/Artifacts/App Intents Confirmation）→ 映射：L2–L4 审批；生成式 UI 永不自带"已签名"语义。
3. **可记录通信**（MCP Apps loggable JSON-RPC）→ 映射：**layout DSL 本身上 tape**（UI provenance），"批准时屏幕显示了什么"可重放。

> 结论 — 行业目前**只做到"通信可记录"**，尚无"批准时刻 UI 快照可重放"标准。**这是 TuringOS 可以做得更严的差异化点。[判断，非外部既有标准]**

---

## 4. 架构契合：生成式 UI 的正确插入点

### 4.1 三个候选插入点的裁决

**(i) Generative layout over typed projections——推荐采纳，加四道闸**：组件类型 ∈ 注册表白名单 schema 校验（fail-closed，不"尽力渲染"）；DSL+投影输入上 tape；整体挂 generated 信任分区；只引用 read-only 投影 + L≤2 action 入口。

**(ii) Full code-gen——永久拒绝**：①CHI 2025 + 2502.13499 实证；②与可重放/确定性根本冲突（违反 M3）；③无法用 {PASS,FAIL} 静态判定；④业界领头框架自己都规避。**推翻须新 ADR + L4。**

**(iii) Generative explanations/summaries in fixed layouts——默认形态**：确定性布局内嵌生成文本（摘要/解读），约束：与底层证据并置 + generated 徽章 + 绝不单独承载可签名后果。

### 4.2 分阶段采纳

| Phase | 生成式？ | 形态 | 法律 |
|---|---|---|---|
| P1 Radar | 否（首版）→ 后续 (iii) | 确定性看板；之后可加生成式摘要 | generated 徽章；gray 不与 verified 混排 |
| **P3 Ceremony** | **永远否** | 100% 确定性渲染 | 渲染输入 = canonical payload 纯函数投影；上 tape 绑 §8 token |
| P6 Review | (iii) 为主，(i) 谨慎 | 证据骨架确定性 + 生成式解读；(i) 编排证据卡顺序 | 裁决区/徽章/签名区永不生成 |
| P7 Market | (iii)/(i) | 看板编排 | 语言门禁对生成文本同样生效 |

> 路线：生成式从**解释层**起步 → 成熟后扩到**投影之上的布局编排层** → **永不进入裁决层与仪式层**。

### 4.3 仪式屏为何必须确定性（钉死）

若 `human_readable_summary` 由 LLM 自由生成 → 同 payload 可能渲染不同措辞 → 签名所覆盖的"人所见后果"不可复现 → 违背"无 canonical payload 的批准不叫 ratification"。**因此：summary 必须是 canonical payload 的确定性纯函数投影（同 payload ⇒ 同字节），布局固定模板，渲染输入连同 §8 token 上 tape。** 仪式屏不得有生成式紧迫感/默认诱导（CHI 2025 高发行为）。

---

## 5. macOS 范例（2026）

- **Conductor**：每 agent 独立 worktree + diff viewer + PR 流，确定性 dashboard。[二手] https://nimbalyst.com/compare/conductor/
- **Nimbalyst**：多 agent 可视化工作区（开源 MIT + iOS），确定性编排面板。[二手] https://nimbalyst.com/blog/best-multi-agent-desktop-apps-claude-code-codex-2026/
- **Raycast v2**：AI 作为 inline 能力，非整屏生成式 UI。https://manual.raycast.com/new-in-v2
- **Warp**：blocks + 自然语言→命令 + Agents 3.0，UI 框架确定性。[二手]

> **共同模式（强信号）**：2026 出货的 agent cockpit 一律**确定性控制面板**，AI 收敛在 inline 文本与编排，**不让 AI 生成自己的控制界面**。"用户喜欢生成式控制面"命题 **UNVERIFIED**，反向证据更强（CHI 2025：80% 察觉不到欺骗）。

---

## 6. 设计法律建议 R1–R8（全部可机械判定；经停机点确认后并入 DESIGN.md）

**R1 — 永久禁止 Level (c)。** 判定：不存在"模型字符串→可执行视图/eval/WebView 执行"通道（grep=0）；layout 只能经 `layout_dsl.schema.json` 反序列化为白名单组件。推翻须新 ADR + L4。

**R2 — 仪式屏永远确定性渲染。** 判定：仪式管线无 LLM 调用（grep+架构断言）；`render_ceremony(payload)` 纯函数——同 payload 双渲染 **sha256 一致**（复用 shipgate #11 谓词形态）；渲染输入与 §8 token 一并上 tape。

**R3 — 生成区必带 `generated` 徽章 + 折叠 provenance；永不与 verified 混排。** 判定：快照金标含徽章（图标+文本）；用 gray 语义，**禁止 green/purple**。

**R4 — 生成式只在解释/编排层，永不进裁决层。** 判定：Predicate/Veto/信任徽章/签名回执的渲染组件为审计白名单，其数据绑定只能来自 typed projection 字段，不能来自 generated-text 通道。

**R5 — layout DSL 必须 schema 校验 + 上 tape + fail-closed。** 判定：校验失败 → 不渲染 + RiskFinding（禁止尽力渲染）；通过的 DSL 连同投影输入上 tape。

**R6 — 生成区只引用 read-only 投影 + L≤2 action；永不自带"已签名"语义。** 判定：generated 子树内 action `level ≤ 2` 静态约束；L3/L4 入口不得出现。

**R7 — App Intents 仅限 L0/L1；L3/L4 永不可被 Siri/Spotlight 触发。** 判定：App Intents 注册表与 typed_actions 交叉校验，level≥3 不得有对应 intent。

**R8 — 生成文本过语言门禁 + 必须并置原始证据。** 判定：market-claim 门禁对生成文本生效；新增反诱导谓词；生成摘要节点旁必有可展开证据节点（快照金标断言）。

---

## 7. 待补证据 / 风险登记

- **[摘要级]**：CHI 2025 与 OpenAI 官方页对自动抓取 403；数字经 ≥2 次独立摘要交叉确认；建议 D-stage 人工二次核对后入 Atom 卡 `verified_external_facts`。
- **UNVERIFIED**：WWDC26/macOS 27 AI-composed-interface 能力；"Tactic" 工具现状；生成式控制面的中立满意度数据。
- **[判断]**："仪式屏 UI provenance 可重放"为本仓自创的更严要求，无现成实现可抄，P3 R-stage 自研并立 ADR。
