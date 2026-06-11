# Turing Agentic OS 白皮书 v0.3

**Apple-native 个人 Agentic OS：让 AI 在你的法律下自治**

版本：v0.3  
日期：2026-06-11  
状态：根据 Operating Flow v3、Software 3.0 UI 哲学、TuringOS 宪法、Apple feasibility 与前两版白皮书重写

---

## 0. 一句话

**Turing Agentic OS 是一个 Apple-native 的个人 Agentic OS。它以 Facilitator AI 的动态气泡作为入口，以 Meta AI 编译用户意图，以 TuringOS Kernel 管理 Spec、预算、谓词、工作树、回执与人类签名，让内部或外部 Agent 在用户批准的法律下自治。**

它不是另一个传统 macOS 应用，也不是另一个聊天机器人。它是一个把「人类意图 → 可执行法律 → Agent 行动 → 机器验证 → 人类签名 → 可回放状态变更」连成闭环的操作层。

> **AI 已经会动手。TuringOS 让它在你的法律下动手。**

---

## 1. v0.3 的核心修正

v0.1 把 Turing 描述为 macOS 上的 agent 治理层，强调同意、可见性、审计与可撤销。v0.2 把它升级为 Apple-native 的个人 Agentic OS。v0.3 进一步完成三项关键修正。

### 1.1 从 Seatbelt 升级为 Agentic OS

TuringOS 不能只是 OpenClaw、Hermes、Claude Code、Codex 的安全带。外部 Agent 应当可接入，但 TuringOS 必须自带第一方运行时、第一方工具、第一方 Apple 集成与第一方 UI 哲学。外部 Agent 是执行面之一，不是产品成立的前提。

### 1.2 从 setup helper 升级为 Facilitator AI

早期的 “Waiter AI” 改名为 **Facilitator AI**。它不是一次性 setup helper，而是长期存在的用户操作协助员。它可以由 Apple Foundation Models 在本地驱动，也可以由用户输入的 API key 进行联网驱动。两者不是两个角色，而是同一个 Facilitator AI 的两种 runtime。

Facilitator AI 的职责是解释、引导、陪伴、设置、提醒、生成界面、帮助用户理解系统状态。它不是主规划器。涉及 Git、ChainTape、项目理解、Init/Spec、任务分解与策略判断时，必须尽早引入 Meta AI。

### 1.3 从传统 UI 改为 Software 3.0 界面

v0.3 正式否定传统软件范式：**取消固定 MenuBar，取消左侧导航栏，取消把软件理解为页面集合，也取消以「无边际滑布」作为主交互容器的旧设计。**

TuringOS 的第一屏应当是一个 Apple Intelligence 气泡式的动态入口。用户通过语音或文字与这个气泡沟通。Facilitator AI 与 Meta AI 根据当前状态实时生成临时的、任务相关的 Generative HTML 投影。界面不是预制页面，而是内核状态与用户意图的实时投影。

Software 3.0 的核心定义是：

> **人类不再操作功能，也不再筛选 AI 输出；人类治理意图、法律、边界、证据和例外。界面不是菜单，界面是系统状态的生成式投影。**

---

## 2. TuringOS 要解决的问题

个人 AI Agent 正从“会聊天”进入“会动手”。它们会读写文件、操作浏览器、运行命令、安排日程、处理邮件、调用 MCP、生成代码、开 PR、执行外部工具。用户真正的问题不是“有没有 AI 能做事”，而是：

- 它到底在做什么？
- 它能不能在我睡觉时持续 loop？
- 它会不会越权？
- 它用了多少钱和多少时间？
- 它做错了能不能撤销？
- 它完成的东西凭什么能交付？
- 它给 Codex / Claude / Kimi / Grok 做的外部分派，TuringOS 还能不能治理？
- 如果 GitHub CI 失败，系统如何进入下一轮修复？
- 如果 GitHub CI 通过，谁决定可以 merge？

TuringOS 的回答不是频繁弹 Touch ID，也不是裸奔 auto mode，而是 **Lawful Auto Mode**：先由用户批准 Spec、预算和自治边界，再让 Agent 在这些法律中自治。越界、不可逆动作、保护写入、预算扩展、修宪和高风险合并，才需要人类的物理签名。

---

## 3. 设计底座：TuringOS 宪法到产品的映射

TuringOS 宪法把系统定义为一个真正的通用机器：paper 是 `tape_t`，pencil 是 append-only 写入，rubber 是失败提案不上升为新世界状态，strict discipline 是谓词、Veto-AI 与宪法约束。任何四要素缺失，系统都只是“近似图灵机”。

v3 白皮书在产品层继承以下宪法约束：

1. **所有信号必须可从 tape 重建。** cost、time、provenance、market price、wallet state、rejection feedback、search history、失败分支都不能只是 UI 状态或 side ledger。
2. **自然语言约束不够。** 用户意图必须被编译为 Spec、预算、权限、验收谓词、CI、结构化校验与可执行工具策略。
3. **Veto-AI 不是代码评审官。** 它只做违宪否决，输出 PASS / VETO，不做主观质量、性能、可读性或测试覆盖率评价。
4. **Q_t 是 version-controlled 状态。** TuringOS 的真实运行必须围绕 `Q_t = ⟨q_t, HEAD_t, tape_t⟩`，并逐步走向真 Git substrate。
5. **市场信号不是真理。** Market 只能作为资源、优先级与注意力信号，不能替代 Spec、CI、谓词、Veto-AI 与人类签名。

---

## 4. 角色系统

### 4.1 Facilitator AI

Facilitator AI 是用户的操作协助员。它负责：

- 首次打开 TuringOS 时的引导；
- 检测本机能力并解释选择；
- 配置 Meta AI、Worker AI、GitHub、权限、预算；
- 解释当前状态；
- 帮用户理解 Spec、预算、失败、待批准项；
- 实时生成 Generative HTML 界面；
- 作为用户与 TuringOS 内核之间的自然语言入口。

推荐 runtime：本地 Apple Foundation Models 优先。若设备不支持、内存过紧或用户选择云端，使用 API-backed Facilitator AI。

### 4.2 Meta AI

Meta AI 是主规划器、治理者、状态解释器。它应该是用户能负担的最强模型。

职责包括：

- 读取 Git、ChainTape、Spec、GitHub PR/CI、历史回执；
- 帮用户完成新项目 Init 或已有项目 Retro-Init；
- 生成 Spec、Definition of Done、验收谓词、工作树计划；
- 生成预算与自治契约建议；
- 分解任务，生成内部 Worker 或外部 Agent prompt；
- 解释 CI 失败，生成 repair prompt；
- 在 CI 通过后生成 Merge Dossier；
- 维护 Project Strategy Loop 和 Project Stumps。

Meta AI 不直接替代谓词。它可以解释和建议，但最终是否推进世界状态，取决于 TuringOS Kernel 的 predicate product、Veto-AI、预算、权限和人类签名。

### 4.3 ArchitectAI

ArchitectAI 是宪法允许的架构改进提出者和部分实现者。它负责提出新工具、新谓词、新 schema、新 tape 结构和新 UI 投影模式。默认可复用 Meta AI endpoint，但在系统内部保持逻辑角色独立。

### 4.4 Veto-AI

Veto-AI 是违宪否决者。它只做一件事：判定某个架构变更、工具调用、策略升级或写入动作是否违宪。默认实现应采用：确定性规则先行，快速模型处理明显案件，模糊高风险案件回落 Meta AI，并且 fail-closed。

### 4.5 Worker AI

Worker AI 是执行者。它的核心要求是 **fast / low-latency / low-thinking / high-throughput**，不必一定 cheap。

在 ChainTape 外部化思考之后，Worker AI 不需要承担重度战略推理。它应该快速尝试、快速失败、快速回报、快速进入下一轮修复。可选形态包括本地模型、本地服务、远程 API，或 Codex、Claude Code、Kimi、Grok 等外部 Agent。

---

## 5. Software 3.0 UI 哲学

### 5.1 反传统软件

TuringOS 不应该像传统 macOS 应用那样，左侧一个 MenuBar，中间一个无限画布，右侧一些属性面板。那仍然是 Software 2.0 的遗产：用户在一个固定空间里寻找功能、点击菜单、管理对象。

TuringOS 的 Software 3.0 原则是：

> **软件不再呈现功能列表，而是呈现一个可对话、可生成、可治理的状态世界。**

因此，后续 UI/UX 开发必须遵守以下设计指令：

- 禁止把左侧菜单栏作为主导航；
- 禁止把无限 canvas 当作主交互形态；
- 禁止把功能分区、页面、Tab 当作产品的第一组织原则；
- 第一入口必须是动态智能气泡；
- 用户诉求首先进入 Facilitator AI 或 Meta AI，而不是静态按钮；
- 系统回应不是切换页面，而是生成与当前任务相关的临时界面；
- 这些界面应当是 Generative HTML / Generative View / State Projection；
- 所有界面都必须能追溯到 Tape、Spec、Budget、Policy 或 Receipt。

### 5.2 Dynamic Orb：第一屏

TuringOS 打开后，用户首先看到的不是菜单，而是一个动态气泡。这个气泡可以被理解为 Apple Intelligence 风格的本地智能入口。

用户可以说：

- “帮我初始化这个项目。”
- “读取我最近活跃的 Git 项目。”
- “帮我设置 Meta AI。”
- “今天帮我规划三个 worktree。”
- “把这个任务分派给 Claude Code。”
- “解释为什么 CI 失败。”
- “哪些项目还没有 TuringOS Ready？”

气泡背后先由 Facilitator AI 接住用户，涉及深度项目理解时切换到 Meta AI。这个切换对用户不应表现为“更换页面”，而应表现为对话深度和生成界面的变化。

### 5.3 Generative HTML / State Projection

TuringOS 的界面不是预先写死的 dashboard，而是由当前上下文生成的状态投影。例如：

- 初始化时生成权限说明、模型选择卡、Git 项目选择卡；
- Init 时生成 Spec 草案、风险问题、验收谓词草案；
- 预算时生成预算雷达和自治边界卡；
- 工作分派时生成 worktree map、agent assignment cards；
- CI 失败时生成 nearest failed predicate 和 repair prompt；
- Merge 前生成 Merge Dossier；
- 早晨生成 Morning Ritual。

这些界面可以是 HTML，但必须受 schema 和 policy 约束。模型可以生成呈现层，但不能生成放行逻辑。UI 是 projection，不是 source of truth。

### 5.4 人类在 UI 中的角色

人类不是菜单操作员。人类是：

- 意图提供者；
- Spec 批准者；
- 预算批准者；
- 不可逆动作批准者；
- 高风险 merge 批准者；
- 宪法维护者；
- 异常与例外的裁决者。

所有日常微操作都应由系统在已批准法律下自动推进。

---

## 6. Operating Flow v3

以下流程是 v3 的闭环流程：

```mermaid
flowchart TD
    A[0 Launch TuringOS.app] --> B[1 Capability Check]
    B --> C{2 Facilitator AI Runtime?}
    C -->|Local Apple Foundation Models| C1[2A Local Facilitator AI]
    C -->|API key| C2[2B API-backed Facilitator AI]
    C1 --> D[3 Configure Meta AI]
    C2 --> D

    D --> E{4 Project Intake}
    E -->|New Project| E1[4A New Project Init]
    E -->|Existing Project| E2[4B Retro-Init / Takeover]
    E1 --> F[5 Init Spec Package]
    E2 --> F

    F --> H1[[Touch ID #1 Approve Init Spec]]
    H1 --> G[6 Budget & Autonomy Contract]
    G --> H2[[Touch ID #2 Approve Budget]]
    H2 --> I[7 Configure Worker AI]
    I --> J[8 Meta AI Builds WorkGraph]
    J --> K{9 Choose Execution Surface}

    K -->|Internal| K1[9A Internal Agents]
    K -->|External Prompt| K2[9B External Agents]
    K -->|Computer Use MCP| K3[9C Assisted External Session]

    K1 --> L[10 Branch / PR Candidate]
    K2 --> L
    K3 --> L

    L --> M[GitHub PR / CI Loop]
    M -->|CI fails| N[Meta AI parses logs and writes repair prompt]
    N --> J
    M -->|CI green| O[12 Turing Predicate Gate]

    O -->|fail| P[Failure Node: Q unchanged, failure enters tape]
    P --> J
    O -->|pass| Q[13 Merge Dossier]
    Q --> H3[[Touch ID #3 or Autonomy-approved Merge]]
    H3 --> R[14 GitHub Merge]
    R --> S[Q_{t+1}: receipt, HEAD anchor, Morning Ritual]
    S --> T[Project Strategy Loop / Stumps / Market Signals]
    T --> J
```

### 6.1 初始化阶段

TuringOS 启动后，先进行硬件与能力检测。若本地 Apple Foundation Models 可用且内存足够，Facilitator AI 默认本地运行；否则由用户输入联网 API key 驱动同一个 Facilitator AI。

Facilitator AI 随后帮助用户配置 Meta AI。Meta AI 一旦可用，就接管深度项目理解：读取 Git、ChainTape、GitHub 状态、项目文档与历史分支。

### 6.2 Project Ready

任何项目进入 TuringOS 之前必须变成 TuringOS Ready。

新项目需要 New Project Init。已有项目需要 Retro-Init。Retro-Init 的本质是后补 Genesis：Meta AI 读取现有 repo、docs、tests、issues、PR、CI、tape，并生成 Backfilled Spec、Current State Anchor、Known Debt 和下一步 readiness tasks。

没有 Init Spec 的项目，不能正式执行普通任务，只能运行 readiness task。

### 6.3 Init Spec Package

Init Spec Package 是项目的小宪法，包含：

- 项目目标；
- 非目标；
- 当前状态；
- Definition of Done；
- 验收谓词；
- 数据边界；
- 工具权限；
- GitHub / CI 规则；
- 初始 worktree 计划；
- 风险清单；
- 预算建议；
- 外部 Agent 可分派策略。

Init Spec 必须由用户 Touch ID 批准。批准后，项目进入 TuringOS Ready。

### 6.4 Budget & Autonomy Contract

Meta AI 主动引导用户设置预算。预算可以按今日、本周、项目、任务目标或 worktree 设定。

预算包括：

- money；
- tokens；
- wall-clock；
- tool calls；
- CI cycles；
- human review burden；
- external-agent spend；
- stop-loss 条件。

Autonomy Contract 定义哪些动作可自动执行，哪些只能暂存，哪些必须拦截，哪些需要 Touch ID。用户签的不是每一步，而是法律边界。

### 6.5 WorkGraph 与执行面

Meta AI 读取 Spec、Git、ChainTape、GitHub issues / PRs 后，生成 WorkGraph。WorkGraph 包含 worktree 分解、风险、预期谓词、回滚计划、内部 Worker 分派、外部 Agent prompts。

执行面有三类：

1. **Internal Agents**：TuringOS 内部直接运行 Worker AI，治理最完整。
2. **External Agents**：Meta AI 生成 prompt，用户复制到 Codex、Claude Code、Kimi、Grok 等工具执行。
3. **Assisted External Session**：若启用 Computer Use MCP，TuringOS 可以打开外部 App，新建 session，粘贴 prompt，启动执行。

外部 Agent 若不经 TuringOS 通道执行，TuringOS 必须标注 provenance partial，不得声称拥有完整 action-level receipt。

### 6.6 GitHub PR / CI Loop

CI、PR、branch protection、merge commit 继续交给 GitHub 做。TuringOS 不应复制 GitHub 的执行功能。

TuringOS 的角色是 Meta Governor：

- 观察 PR、commit SHA、diff、changed files；
- 导入 CI 状态、check-run URL、日志摘要；
- 在 CI 失败时，Meta AI 解释日志，找 nearest failed predicate，生成 repair prompt；
- 在重复失败时，把典型错误抽象成全局规则，而不是把原始日志污染给所有 Agent；
- 在 CI 通过时，把 GitHub CI 作为外部谓词之一送入 Turing Predicate Gate。

GitHub 是执行场，TuringOS 是治理场。GitHub 说 “CI green”；TuringOS 判断 “这个 green 是否足以让当前 Spec 下的世界状态前进”。

### 6.7 Turing Predicate Gate

CI 通过不是最终放行。TuringOS 还要检查：

- 是否符合 Init Spec；
- 是否符合 Definition of Done；
- diff 是否在 approved worktree scope 内；
- budget 是否合规；
- receipts 是否完整；
- provenance 是否足够；
- data scope 是否越界；
- Veto-AI 是否 PASS；
- 是否需要人类批准 merge。

若 predicate product 为 0，Q 不前进，失败进入 tape。若 predicate product 为 1，进入 Merge Dossier。

### 6.8 Merge Dossier

Merge Dossier 由 Meta AI 生成，但由 TuringOS Kernel 约束结构。它包含：

- Spec delta；
- CI summary；
- test evidence；
- changed files；
- risk notes；
- rollback plan；
- budget used；
- provenance level；
- receipts；
- human review burden；
- known limitations。

保护分支、发布、不可逆外部动作、高爆炸半径 diff 默认需要 Touch ID。低风险 merge 只有在事先 Autonomy Contract 允许时才能自动合并。

### 6.9 Q_{t+1}

GitHub 执行 merge 后，TuringOS 观察 merge commit SHA，将其记录为 `HEAD_{t+1}` anchor。wtool 写入 receipt：PR、CI、approval、merge SHA、rollback plan。Morning Ritual 展示 Done / Staged / Blocked / Failed / Needs Approval。

---

## 7. TuringOS Kernel

TuringOS Kernel 是整个 operating flow 的中心，不是 UI 的后端附属物。

```text
Q_t = ⟨q_t, HEAD_t, tape_t⟩
        ↓ rtool
input = current state + relevant tape + spec + git + PR + CI evidence
        ↓
Middle Blackbox = Meta AI / Worker AI / external agents
        ↓
output = candidate action / branch / PR / tool proposal / policy proposal
        ↓
Top Whitebox = predicates + Veto-AI + budget + market signal + shielding
        ↓
if ∏p = 1: wtool commits Q_{t+1}
if ∏p = 0: Q_t unchanged, failure enters tape
```

### 7.1 Bottom Whitebox

负责读取和执行：Git、Tape、Spec、Policy、工具 manifest、GitHub 状态、CI 证据、外部 Agent 产物。

### 7.2 Middle Blackbox

负责提议：Meta AI 规划、Worker AI 执行、外部 Agent 生成候选。黑盒内部推理不被信任。系统只信可观察、可验证、可重建的行为结果。

### 7.3 Top Whitebox

负责量化、广播、屏蔽：

- 量化：CI、tests、lint、budget、scope、receipts、provenance；
- 广播：典型错误、策略树桩、价格信号、repair rules；
- 屏蔽：坏日志、Goodhart 细节、横向相关性污染、过期上下文。

### 7.4 Failure Node

失败不是垃圾。失败必须进入 tape。Failure Node 包括 reject_class、nearest failed predicate、attempt summary、budget used、suggested repair、provenance。它是下一轮搜索的资产。

---

## 8. Touch ID 节点

Touch ID 不是微操作确认器。它是法律边界、不可逆动作和保护写入的物理签名。

必须 Touch ID 的默认节点：

1. Approve Init Spec / Project Ready；
2. Approve Budget & Autonomy Contract；
3. Approve sensitive data scopes / external credentials；
4. Approve irreversible external actions；
5. Approve protected write / merge / release / publish；
6. Approve over-budget extension；
7. Approve tool / predicate / policy upgrade when required；
8. Approve constitution amendment / sudo ritual。

每次签名绑定规范化 approval screen hash。Secure Enclave 只证明“谁签了字节”，所以 TuringOS 必须把“批准时所见”纳入签名负载。

---

## 9. Project Strategy Loop：项目树桩与 MCTS-lite（TBD）

复杂项目不是线性任务，而是策略树。Meta AI 应主动帮助用户生成 Project Stumps，即项目拓展树桩：

- 一个可能的产品方向；
- 一个可验证的技术路线；
- 一个 worktree arm；
- 一个实验假设；
- 一个风险隔离分支；
- 一个候选 PR；
- 一个文档 / 架构 / 市场方向。

v3 建议先采用 **portfolio search + visible strategy tree**，而不是立即实现完全自动的 opaque MCTS。

MCTS-lite 的可能定义：

- Node = Project Stump / Worktree / PR candidate；
- Edge = WorkTx / agent attempt；
- Reward = predicate pass + CI signal + user approval + value claim - cost - risk；
- Exploration = 新方向、新 worker、新 prompt、新 tool；
- Exploitation = 已经高成功率的方向持续推进；
- Market signal = 资源与注意力权重，不是真理。

这块标注为 **TBD / 待总加工师详细讨论**。开放问题包括：

- 哪些 stump 可以自动生成？
- 哪些 stump 必须用户批准？
- MCTS reward 是否会引发 Goodhart？
- 如何计价 CI cycles、API cost、人类注意力和 merge risk？
- Market 是 auction、credits、UCB、MCTS reward，还是混合机制？

---

## 10. Market Module：信号，不是真理

TuringOS 宪法允许价格信号作为统计信号和广播信号，但 v3 不把 market 作为性能引擎宣称。

v0：observe-only。

记录：

- 预算消耗；
- 队列拥堵；
- 重复失败；
- CI 成本；
- worker reliability；
- human review burden；
- task value claims。

v1：辅助队列排序、worker 选择、review queue ordering、strategy stump ranking。

边界：

> **Market signal ≠ predicate truth.**

任何写入仍必须通过 Spec、CI、谓词、Veto-AI、预算和人类批准。

---

## 11. Apple-native 技术策略

TuringOS 应深度拥抱 Apple 生态，但不把自己伪装成系统级监控软件。

### 11.1 Foundation Models

Facilitator AI 默认优先使用 Apple Foundation Models。其定位是本地、轻量、隐私优先的操作协助、摘要、分类、解释和界面生成辅助。

它不替用户做最终决策，不进入核心策略执行链，也不替代 Meta AI。

### 11.2 Touch ID / Secure Enclave

用于签名批准 Init Spec、Budget、敏感权限、不可逆动作、protected merge、工具/谓词升级和 sudo 修宪。

### 11.3 Shadow Workspace

可逆本地动作应先进入影子工作区。TuringOS 不承诺系统级 APFS 快照还原，而用用户态副本、Git 语义和版本化暂存实现诚实撤销。

### 11.4 GitHub

GitHub 继续负责 PR、CI、branch protection、merge commit。TuringOS 负责解释、记录、验证、生成修复任务、准备 Merge Dossier 和更新 Q。

### 11.5 External Agent Boundary

凡经由 TuringOS 工具通道的动作，可生成 action-level receipt。凡发生在外部 App 内且未经过 TuringOS 通道的动作，只能生成 repo-level / PR-level receipt，并标注 partial provenance。

---

## 12. 产品体验：从第一秒到闭环

### 12.1 首次打开

屏幕中央出现动态气泡。用户说：“帮我设置 TuringOS。” Facilitator AI 解释它将检查本机能力、设置模型、读取项目、建立第一个 Spec。

### 12.2 配置 Meta AI

Facilitator AI 引导用户输入或选择 Meta AI endpoint。Meta AI 被设置为主规划器。

### 12.3 项目发现

Meta AI 读取 Git 项目、最近活跃分支、GitHub PR、现有文档，生成项目选择卡。用户选择一个项目。

### 12.4 Init / Retro-Init

Meta AI 与用户沟通，生成 Spec。若项目是半途接手，则生成 Retro-Init。用户通过 Touch ID 批准。

### 12.5 预算与自治契约

Meta AI 提出预算。用户通过 Touch ID 批准。

### 12.6 WorkGraph

系统生成 worktree map。用户可以说：“今天并行开三个 worktree。” Meta AI 生成内部 worker 分派，也生成给外部 Agent 的 prompt。

### 12.7 执行

内部 Worker 或外部 Agent 执行任务。TuringOS 记录治理范围内的动作，并观察 Git/PR 状态。

### 12.8 CI / Repair Loop

GitHub CI 跑。失败则 Meta AI 生成修复 prompt 并回到 WorkGraph。成功则进入 Turing Predicate Gate。

### 12.9 Merge Dossier

系统生成可签名合并档案。用户批准或自治契约放行。

### 12.10 Morning Ritual

用户早上看到 Done / Staged / Needs Approval / Blocked / Failed。失败项不是日志垃圾，而是 Failure Certificate 和下一轮建议。

---

## 13. 对外定位

面向公众：

> **TuringOS is the Apple-native Agentic OS that lets AI work under your law.**

面向开发者：

> **TuringOS turns agent work into Spec-bound, CI-aware, receipt-backed, human-signable state changes.**

中文主张：

> **TuringOS 不是让 AI 更会说，而是让 AI 更敢做；不是把用户塞进软件，而是让软件围绕用户意图实时生成。**

---

## 14. 路线图

### v0.3-alpha：Software 3.0 Shell

- Dynamic Orb；
- Facilitator AI；
- API-backed fallback；
- Meta AI configuration；
- Generative HTML prototype；
- project discovery；
- basic Git read-only state。

### v0.3-beta：Project Ready

- Init Spec；
- Retro-Init；
- Touch ID approval for Spec；
- Budget & Autonomy Contract；
- WorkGraph generation。

### v0.4：Execution Loop

- internal Worker AI；
- external prompt delegation；
- Computer Use MCP handoff；
- GitHub PR/CI observation；
- CI failure repair prompt；
- Merge Dossier。

### v0.5：Kernel Receipt Loop

- tape / receipt schema；
- provenance levels；
- predicate gate；
- Failure Certificate；
- Morning Ritual。

### v0.6：Strategy Loop

- Project Stumps；
- portfolio search；
- Market observe-only；
- MCTS-lite experiment。

---

## 15. 不可谈判项

1. UI 不得退回传统菜单导航。
2. Facilitator AI 是长期角色，不是 setup helper。
3. Meta AI 必须尽早介入项目理解。
4. Init Spec 是所有项目的启动门槛。
5. 没有 Spec 的项目只能做 readiness task。
6. GitHub CI 是外部谓词，不是 TuringOS 要复制的功能。
7. Merge 需要 Merge Dossier，不接受“CI 绿了所以直接合”。
8. Veto-AI 只做违宪否决。
9. Market signal 不是真理。
10. 外部 Agent 产物必须标注 provenance level。
11. 不可逆动作 draft-by-default。
12. 所有关键状态必须可从 tape 重建。

---

## 16. 结语

TuringOS 的产品机会不是做一个更聪明的 Agent，而是做一个让 Agent 能被普通人真正托付的操作世界。

Software 1.0 让人点击功能。  
Software 2.0 让人喂模型、筛输出。  
**Software 3.0 让人立法，让 Agent 在法律下行动，让界面从状态中生成。**

TuringOS v3 的方向因此非常明确：

> **从菜单到气泡；从页面到投影；从 prompt 到 Spec；从 auto mode 到 lawful auto mode；从 AI 输出到可签名状态变更。**

