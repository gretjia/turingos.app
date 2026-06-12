# Turing Agentic OS 白皮书 v0.5

**Apple-native × protocol-native 个人 Agentic OS：让 AI 在你的法律下自治**

版本 v0.5 · 2026-06-12 · 状态：在 v0.4 基础上完成定位升级（依用户 8 条评审与对谈，[原文存档](research/REVIEW_v04_user_gpt_dialogue.md)）——新增 Agentic 协议层、Model Gateway、Capability Registry、Skill Library、Live Software 3.0 回路、Hostile Host 安全模型、Canvas Projection 与外部 Agent Adapter Contract。本版取代 v0.1 / v0.3 / v0.4。

> 配套文档：[FEASIBILITY.md](FEASIBILITY.md)（外部论断核验状态与来源，含 v0.5 调研附录 Part IV）· [research/R_agentic_os_sources.md](research/R_agentic_os_sources.md)（A1_11 论断库）· [research/R_v05_protocol_live_sources.md](research/R_v05_protocol_live_sources.md)（v0.5 论断库，41 条）。本版凡引外部事实，仅限两库内已核条目，措辞强度不超过其核验状态。

---

## 0. 一句话

**Turing Agentic OS 是一个 Apple-native、protocol-native 的个人 Agentic OS。它以 Facilitator AI 的动态气泡作为入口，以 Meta AI 编译用户意图，以 TuringOS Kernel 管理 Spec、预算、谓词、工作树、回执与人类签名，把外部模型、工具、技能与 Agent 全部变成受法律约束、有回执背书、可由人类签名的状态迁移。**

它不是另一个传统 macOS 应用，也不是另一个聊天机器人。它是一个把「人类意图 → 可执行法律 → Agent 行动 → 机器验证 → 人类签名 → 可回放状态变更」连成闭环的操作层。

> **AI 已经会动手。TuringOS 让它在你的法律下动手。**
>
> TuringOS is an Apple-native, protocol-native personal Agentic OS that turns external models, tools, skills, and agents into law-bound, receipt-backed, human-signable state transitions.

三权分明：**Apple-native 是产品体验与本地可信能力；protocol-native 是生态扩展能力；ChainTape、Predicate Gate、人类签名与 provenance 是 TuringOS 自己不可让渡的主权。**

---

## 1. 版本沿革与本版修正

v0.1 把 Turing 描述为 macOS 上的 agent 治理层（安全带），强调同意、可见性、审计与可撤销。v0.2/v0.3 把它升级为 Apple-native 的个人 Agentic OS，并确立三项修正：

1. **从 Seatbelt 升级为 Agentic OS。** 外部 Agent 应当可接入，但 TuringOS 必须自带第一方运行时、第一方工具、第一方 Apple 集成与第一方 UI 哲学。外部 Agent 是执行面之一，不是产品成立的前提。
2. **从 setup helper 升级为 Facilitator AI。** 它是长期存在的用户操作协助员，可由 Apple Foundation Models 本地驱动或 API key 联网驱动——同一角色的两种 runtime。涉及 Git、ChainTape、项目理解、Init/Spec、任务分解与策略判断时，必须尽早引入 Meta AI。
3. **从传统 UI 改为 Software 3.0 界面。** 取消固定应用内菜单与左侧导航，取消把软件理解为页面集合。第一屏是动态智能气泡；界面是内核状态与用户意图的实时生成投影。

v0.4 在此之上完成三项工作：

1. **宪法对齐。** TuringOS 宪法（Art. 0 图灵机原教旨 / Tape Canonical / Q_t 三元组 / 量化·广播·屏蔽 / 三权分立）逐条映射到产品层（§4），凡宪法已有裁决处不发明新教义。
2. **Operating Flow 补全。** v0.3 的单线流程图缺终止态、止损护栏、并发语义、异步批准与 Meta 演化回路（审计判定 4 项 blocker + 13 项 major）。v0.4 以**四回路 + 一条注意通道**重画（§7）。
3. **回收 v0.1 诚实资产。** 操守五条、三类动作风险地图、覆盖边界横切声明、逐 agent 硬事实（Claude Code MCP-deny 缺口、Codex Cloud 例外等）在 v0.3 升级定位时丢失；产品形态变大，这些声明只会更必要，全部回收（§3 / §10 / §14 / §15）。

v0.5 依用户 8 条评审完成**定位升级：Apple-native → Apple-native × protocol-native**，闭合三个缺口：

1. **生态接口系统化。** MCP / A2A / MCP Apps / A2UI / AG-UI / SKILL.md / 模型 API 不再是零散集成点，而是一个有铁律的协议层（§13.6）+ Model Gateway（§13.7）+ View IR（§6.6）。原则一句话：**外部协议负责互操作；TuringOS 负责法律、谓词、签名、审计、状态迁移。**
2. **能力面底层白盒化。** 不做传统插件市场，做 **Capability Registry**（§13.8）：每个工具/技能/连接器都是带 manifest、权限、动作类、eval 与回执的可审计对象——Install ≠ trust。Skill Library（§13.9）与 Live Software 3.0 回路（§13.10）让系统在使用中演化白盒脚手架。术语纪律：反奥利奥架构是**顶层白盒（谓词与管理）/ 中间黑盒（agent）/ 底层白盒（工具）**三层——本文凡称"白盒工具/白盒能力"，一律指**底层白盒**，与顶层白盒严格分层、不得混称。
3. **安全模型升维。** Touch ID + SE 是 v0.x 的本地批准层；面对"宿主 OS 被完全攻破"的 AGI 威胁模型，v0.5 写入 **Hostile Host 公理**与两层安全架构（§9.1），不夸大 Secure Enclave 的能力边界。

---

## 2. TuringOS 要解决的问题

个人 AI Agent 正从"会聊天"进入"会动手"。它们会读写文件、操作浏览器、运行命令、安排日程、处理邮件、调用 MCP、生成代码、开 PR、执行外部工具。用户真正的问题不是"有没有 AI 能做事"，而是：

- 它到底在做什么？
- 它能不能在我睡觉时持续 loop？
- 它会不会越权？
- 它用了多少钱和多少时间？
- 它做错了能不能撤销？
- 它完成的东西凭什么能交付？
- 它给 Codex / Claude / Kimi / Grok 做的外部分派，TuringOS 还能不能治理？
- 如果 GitHub CI 失败，系统如何进入下一轮修复？
- 如果 GitHub CI 通过，谁决定可以 merge？

TuringOS 的回答不是频繁弹批准框，也不是裸奔 auto mode，而是 **Lawful Auto Mode**：先由用户批准 Spec、预算和自治边界，再让 Agent 在这些法律中自治。越界、不可逆动作、保护写入、预算扩展、修宪和高风险合并，才需要人类的物理签名。

---

## 3. 设计操守（产品的不可谈判项，先于一切功能）

继承自 v0.1，在 Agentic OS 形态下逐条重申。违反任何一条的功能，不做。

1. **只治理经由 Turing 通道的动作。** 第一方 Worker 经内核工具行动，治理完整；外部 Agent 自愿接入（MCP / CLI 包装 / hooks），接入即同意。我们不会、也无法静默监管你电脑上的一切——**我们绝不作此声称**。通道之外的动作面在 §14 与每个集成的边界卡中如实披露。
2. **不可逆动作默认是草稿。** 文件编辑这类可撤销动作在影子工作区暂存、批准后应用。发邮件、付款、发帖这类对外动作**无法真正撤回**——唯一诚实的设计是 draft-by-default：先存为草稿，经你签名确认后才执行。我们不向你承诺"撤回一封已发出的邮件"这种工程谎言。
3. **批准记录的是"你当时看到了什么"。** 每一次签名，连同批准卡所呈现内容的规范化哈希一起进入被签名的负载。事后回看时，你看到的不只是"批准了"，而是"基于什么批准的"。
4. **对 agent 诚实。** 当一个动作被暂存而非执行，返回给 agent 的结果必须如实说明（`status=staged` / 待批准 / 已拒绝），不让 agent 误以为动作已完成——否则它后续的计划会建立在假事实上。这是回路 2 中的显式回边，不是注释（§7.3）。
5. **本地优先。** tape、回执、批准历史存在你的电脑上，归你所有，可导出、可回放。TuringOS 不是一个把你的操作上传到别处的服务。模型辅助的呈现功能优先端侧。

### 3.1 它不是什么

- 不是杀毒软件，不是入侵检测——它不扫描、不拦截未接入的进程。
- 不是另一个替你决策的 agent——它不自动"纠正"你的 Agent，它执行你批准的法律。
- 不是合规监控——它是给你自己用的，不是给别人看你的。

---

## 4. 设计底座：TuringOS 宪法到产品的逐条映射

TuringOS 宪法把系统定义为一台真正的通用机器：paper 是 `tape_t`，pencil 是 append-only 写入，rubber 是失败提案不上升为新世界状态，strict discipline 是谓词、Veto-AI 与宪法约束。四要素任何一者缺失，系统都只是"近似图灵机"。本节是宪法条款到产品机制的映射表——凡仓库 ADR 已有裁决处直接引用，不另立教义。

### 4.1 四要素映射（Art. 0.1）

| Turing 1948 | 宪法对应 | 产品对应 |
|---|---|---|
| **Paper** | `tape_t` | **ChainTape**：append-only 的本地事实账本（动作、提案、批准、失败、回执全部入带） |
| **Pencil** | wtool append-only 写入 | 内核唯一写入口：tape 追加 + git commit/merge；仅 ∏p=1 时世界状态前进 |
| **Rubber** | 失败提案不上升为新状态 | ∏p=0 时 Q 不前进，失败以 `verified=false` + `reject_class` 入带；draft-by-default 即 rubber 在对外动作上的形态 |
| **Strict discipline** | 谓词 + Veto-AI + 宪法 | Turing Predicate Gate + Veto-AI {PASS,VETO} + 三级法律层级（§4.4） |

### 4.2 Tape Canonical（Art. 0.2 / ADR-003）

> **所有信号必须可从 tape 重建。**

产品义务（ADR-003 已裁决为仓库法律）：

- **Git-backed ChainTape/CAS 是唯一 canonical truth。** UI 状态、缓存、索引一律是**派生投影**：可删、可重建，并以守恒测试（`view == derive_from_tape(tape)`）背书。
- 每个投影必须声明 `derive_source` / `schema_version` / `rebuild_command`（contracts/projection.schema.json 强制）。**Software 3.0 的生成式界面同样是派生投影，受同一纪律约束**——这是 §6 的物理基础。
- 失败分支（被否决 / 解析失败 / 谓词拒绝）必须以 `verified=false, reject_class=...` 形态入带——失败也是状态，是下一轮搜索的资产（§8.4 Failure Node）。
- cost / provenance / 预算消耗 / 市场观测 / 批准记录都不能只是 UI 状态或旁路账本——frozen tape 上必有充分信息可推导。
- ChainTape 节点带哈希链（Art. 0.3 的预留语义槽位）：每条目携带自身内容与前序哈希，启动时验链，篡改可检测。批准卡哈希（操守第 3 条）是这条链上的一类节点，不是孤立机制。

### 4.3 Q_t 三元组的产品映射（Art. 0.4）

宪法规定 Q_t = ⟨q_t, HEAD_t, tape_t⟩ 是 version-controlled 三元组，并指出"真 git substrate"是满分实现路径。产品层的落位：

| 宪法元素 | 产品落位 |
|---|---|
| `q_t` | 内核会话状态（项目的 WorkGraph 进度、挂起批准、止损计数）——从 tape 可重建的派生量，崩溃后据此恢复 |
| `HEAD_t` | git HEAD / merge commit SHA 锚点（每项目一条锚链；GitHub merge 后由内核观察并记录为 HEAD_{t+1}） |
| `tape_t` | Git-backed ChainTape/CAS（本地 canonical）+ git 对象库；GitHub 是执行场与远端副本，不是账本的替身 |
| `rtool` | 状态装配：git 读取 + tape 相关切片 + GitHub PR/CI 观测 → 组装为最小充分上下文（Art. III.2） |
| `wtool` | tape 追加 + git commit/merge，仅 ∏p=1 放行 |

**一句话说清这层对齐**：用户 v0.3 选择"GitHub 继续做 PR/CI/merge，TuringOS 做治理场"——这正是宪法 Art. 0.4 路径 B（真 git substrate）在产品层的实现：版本机制不自研，git 久经验证的 hash chain、不可变对象与 reflog 直接成为 Q_t 的物理底座；ChainTape 作为 canonical 账本叠于其上，记录 git 本身不记录的事实（批准、拒绝、预算、provenance）。

### 4.4 三级法律层级（Art. V.1.1 的产品化）

| 层级 | 载体 | 批准方式 | 修订方式 |
|---|---|---|---|
| **L0 系统宪法** | TuringOS 宪法（随产品分发，含本操守） | 安装时知情同意 | 仅人类 sudo + 签名#8，修订日志留痕（Art. V.3） |
| **L1 项目小宪法** | Init Spec Package + 预算与自治契约 | 签名#1 / #2 / #3 | 修订再入回路 1：范围变更重签 Spec；超预算走签名#6 |
| **L2 任务法** | WorkGraph 谓词 + 工具策略 | 自治契约范围内自动生效 | Meta AI 维护；触及策略面的升级走回路 3（Veto-AI + 必要时签名#7） |

人类不再规定"系统应该怎么做"，而是立法、批准预算、裁决例外。用户签的不是每一步，而是法律边界。

### 4.5 量化 · 广播 · 屏蔽：顶层白盒的三项产品义务（Art. I–III）

| 宪法条款 | 产品义务 |
|---|---|
| **量化 I.1** 布尔谓词 | 自然语言约束不够：意图必须编译为 Spec、预算、权限、验收谓词、CI、结构化校验。谓词输出域 {PASS,FAIL} |
| **量化 I.1.1** PCP 谓词 / 疑罪从无 | UI 合理性、文风这类无完美谓词的域：谓词退化为 PCP 形态（正确解绝不误杀，错误解高概率拦截）；**主观判断走独立 RiskFinding 通道附在 Merge Dossier 上供人类裁决，永不冒充谓词** |
| **量化 I.2** 统计信号 | 市场模块 v0 的观测量（预算消耗、重复失败、worker 可靠度、人类审阅负担）= 对 tape 的确定性统计，不含主观估值（§12） |
| **广播 II.1** 典型错误 | CI 失败 → 修复指引**精准注入**该 worktree；重复跌倒 → Meta AI 抽象为全局规则入规则库，注入后续 WorkGraph。**绝不把原始日志群发给所有 agent——那是上下文污染** |
| **广播 II.2** 价格信号 | 市场信号只作资源、优先级与注意力权重（探索/利用平衡见 §11），不替代谓词与签名 |
| **屏蔽 III.1** 园丁 / GC | 定期清扫过期规则、陈旧文档、死分支与影子副本；清扫动作本身入回执（§7.4） |
| **屏蔽 III.2** 封装细节 | Worker 的上下文是 rtool 装配的最小充分切片（目录式渐进披露），不是全量历史 |
| **屏蔽 III.3** 横向相关性 | 并行 worktree 的 Worker 上下文相互隔离：独立 tape 切片、独立会话线程，一个 worktree 的失败叙事不得污染另一个的规划上下文——否则群体智慧退化为单体智慧 |
| **屏蔽 III.4** Goodhart | Worker 收到"做什么、有什么工具"，**不收到谓词内部与评分细节**；它只通过 error message 感受边界。公开谓词（repo 内 CI）按其本性公开；内核侧验收检查（范围合规、Dossier 证据核对）保持在 Worker 不可读的区域 |

---

## 5. 角色系统

### 5.1 Facilitator AI

用户的操作协助员：首启引导、能力检测与解释、配置 Meta AI / Worker / GitHub / 权限 / 预算、解释当前状态、帮助理解 Spec 与失败、实时生成界面投影、作为自然语言入口。

推荐 runtime：本地 Apple Foundation Models 优先；设备不支持或用户选择云端时用 API-backed runtime。**它不是主规划器**：涉及 Git、ChainTape、项目理解、Init/Spec、任务分解与策略判断时，必须尽早交给 Meta AI。

### 5.2 Meta AI

主规划器、治理者、状态解释器，应该是用户能负担的最强模型。职责：读取 Git/ChainTape/Spec/GitHub PR·CI/历史回执；主持 Init 与 Retro-Init；生成 Spec、DoD、验收谓词、worktree 计划；生成预算与自治契约建议；分解任务并生成内部 Worker 与外部 Agent prompt；解析 CI 失败并生成修复 prompt；CI 通过后生成 Merge Dossier；维护策略回路与 Project Stumps。

Meta AI 不替代谓词。它可以解释和建议，但世界状态是否前进，取决于 Kernel 的 predicate product、Veto-AI、预算、权限和人类签名。

### 5.3 ArchitectAI

宪法允许的架构改进提出者与实现者：新工具、新谓词、新 schema、新 tape 结构、新投影模板。按宪法 Art. V.1.2，**不触及宪法的变更经 Veto-AI PASS 后可直接落盘**（manifest 更新 + 修订入 tape）；自治契约可以要求其中某些类别仍走签名#7。默认可复用 Meta AI endpoint，但保持逻辑角色独立。**园丁职责挂在此角色下**（Art. III.1）：定期清扫陈旧规则与死分支。

### 5.4 Veto-AI

违宪否决者，输出域只有 **{PASS, VETO}**（Art. V.1.3）。它不做主观质量、性能、可读性、测试覆盖率评价——那些属于独立审计与 RiskFinding 通道。实现采用：确定性规则先行，快速模型处理明显案件，模糊高风险案件回落 Meta AI，**fail-closed**。

### 5.5 Worker AI

执行者，核心要求 **fast / low-latency / low-thinking / high-throughput**，不必一定 cheap。在 ChainTape 外部化思考之后，Worker 不承担重度战略推理：快速尝试、快速失败、快速回报、快速进入下一轮。可选形态：本地模型、本地服务、远程 API，或 Codex、Claude Code、Kimi、Grok 等外部 Agent。

### 5.6 角色即路由：按判据清晰度分配模型

五个角色构成一条与判据清晰度对齐的模型路由律——这不是成本偏好，是验证的非对称性使然：

- **判据可机械验证的工作**（回执审计、合规检查、明显违宪案件）→ 轻量模型甚至 rule-based 先行（Veto-AI 的确定性规则层、Facilitator 的模板句）。
- **可分解、判据需显式化的工作**（按既定 Spec 执行、结构化评审）→ Worker 档：快、吞吐高。
- **开放式、专家域、不可逆后果的工作**（立法、契约设计、策略裁决、Merge Dossier、终审）→ Meta 档：最强模型，**永不降档**。

---

## 6. Software 3.0 UI 哲学

### 6.1 反传统软件

TuringOS 不应该像传统 macOS 应用那样，左侧一个导航栏，中间一个无限画布，右侧一些属性面板。那是 Software 2.0 的遗产：用户在固定空间里寻找功能、点击菜单、管理对象。

> **软件不再呈现功能列表，而是呈现一个可对话、可生成、可治理的状态世界。**

设计指令：

- 禁止把左侧菜单栏作为主导航；
- 禁止把无限 canvas 当作主交互形态；
- 禁止把功能分区、页面、Tab 当作产品的第一组织原则；
- 第一入口必须是动态智能气泡；
- 用户诉求首先进入 Facilitator AI 或 Meta AI，而不是静态按钮；
- 系统回应不是切换页面，而是生成与当前任务相关的临时界面；
- 这些界面应当是 Generative HTML / Generative View / State Projection（宪法约束见 §6.3）；
- 所有界面都必须能追溯到 Tape、Spec、Budget、Policy 或 Receipt。

### 6.2 Dynamic Orb：第一屏

打开 TuringOS，用户首先看到的不是菜单，而是一个动态气泡。用户可以说：

- "帮我初始化这个项目。"
- "读取我最近活跃的 Git 项目。"
- "今天帮我规划三个 worktree。"
- "把这个任务分派给 Claude Code。"
- "解释为什么 CI 失败。"
- "哪些项目还没有 TuringOS Ready？"

气泡背后先由 Facilitator AI 接住用户，涉及深度项目理解时切换到 Meta AI。切换对用户不表现为"换页面"，而是对话深度和生成界面的变化。

### 6.3 Generative HTML / State Projection——以及它的宪法约束

界面不是预先写死的 dashboard，而是当前上下文生成的状态投影：初始化时生成权限说明与模型选择卡；Init 时生成 Spec 草案与风险问题；预算时生成预算雷达与自治边界卡；分派时生成 worktree map；CI 失败时生成最近失败谓词与修复 prompt；Merge 前生成 Merge Dossier；早晨生成 Morning Ritual。

约束（来自 §4.2，不是风格建议）：

- **模型可以生成呈现层，但不能生成放行逻辑。** 放行只来自谓词、契约与签名。
- **每一个生成式投影都是 tape 的派生视图**：声明 `derive_source`，可重建，可与 tape 对账。界面上的每个数字、每句结论都能下钻到产生它的事实。
- 生成失败或模型不可用时，优雅降级为确定性模板投影——呈现可以降级，事实不会丢失。

### 6.4 注意通道：安静即成功

Software 3.0 的另一半不是"问什么答什么"，而是"什么时候打扰你"。三定律：**注意力优先、语言优先、安静即成功。**

- 需要你裁决的事（批准队列、止损报告、失败证书）置顶呈现；
- 进行中的事低调呼吸；
- 一切安静时界面近乎空——安静不是没有信息，是系统替你扛住了信息。

注意通道是 operating flow 的一等公民（§7.5）：挂起的签名请求不阻塞其他 worktree，用户回来时一次性裁决。其具体物理载体（orb 脉动、系统通知、常驻微标）属 UI 设计轨，由设计稿另行裁决——本白皮书只锁定通道语义。

### 6.5 人类在 UI 中的角色

人类不是菜单操作员。人类是：意图提供者、Spec 批准者、预算批准者、不可逆动作批准者、高风险 merge 批准者、宪法维护者、异常与例外的裁决者。所有日常微操作都应由系统在已批准法律下自动推进。

### 6.6 Turing View IR：生成式界面的统一中间表示

生态正在收敛到"工具/agent 返回界面"：MCP Apps 已成为首个 official MCP extension（2026-01；与 OpenAI 联合制定，Apps SDK 即建于 MCP 之上）；Google 的 A2UI（v0.8，官方自述 early-stage）与 CopilotKit 的 AG-UI 是另两条路线。TuringOS 的姿态：

- 所有外来 UI 描述（MCP Apps 组件 / A2UI / AG-UI / 未来格式）先翻译为 **Turing View IR**，再由第一方渲染器投影——适配在边缘，渲染权在内核。MCP Apps 为优先适配目标；A2UI/AG-UI 只做 adapter，不深度锁定。
- View IR 投影与一切投影同律（§4.2）：声明 `derive_source`，可重建，可与 tape 对账。
- **第三方生成的 UI 是不可信内容**——它可以呈现信息，但有两条铁律：① **批准卡永远由第一方渲染器绘制，任何第三方 view 组件不得承载批准仪式**（否则"批准时所见"的哈希就建立在对手可控的像素上）；② 第三方 view 发起的动作请求与其它通道的动作请求同等过门——分类、谓词、签名一个不少。

### 6.7 Canvas Projection：无边界呈现的诚实路径

无边界画布是对的阅读形态，但路径必须诚实（来源见 FEASIBILITY Part IV）：**Apple Freeform 当前的全部公开自动化面只有一个 Shortcuts 动作（Add Files to Board）**——无创建看板 API、无 AppleScript 字典、无公开文件格式。所以：

1. **v1 自建 Canvas Projection**：Markdown AST → 布局图 → 第一方渲染（嵌入式画布候选 Excalidraw，MIT 可自由商用；tldraw 生产部署需商业 license，列为次选）。每个画布节点带 `derive_source`，派生自 Markdown / Spec / ChainTape / Receipt——画布不是第二事实源。可导出 PDF/PNG/HTML/Markdown。
2. **Freeform 只做导出/分享桥**（用户手动），若 Apple 日后开放官方 API 再建 bridge。**不逆向 Freeform 私有格式**——那违背可维护性与分发诚实。

---

## 7. Operating Flow v4：四回路 + 一条注意通道

v0.3 的单线流程图被审计判定存在结构性缺口（无终止态、无止损、无并发、无 Meta 回路、8 个签名节点只画了 3 个）。v0.4 把流程拆为四个回路：**Boot（每安装一次）→ 立法（每项目一次）→ 执行（内核主回路）→ Meta（架构演化）**，加一条横贯全部回路的**注意通道**。

### 7.0 总览

```mermaid
flowchart LR
    L0["回路 0 · Boot<br>每安装一次"] --> L1["回路 1 · 立法<br>每项目一次（可修订再入）"]
    L1 --> L2["回路 2 · 执行<br>内核主回路（每任务多次）"]
    L2 -->|"工具/谓词缺口提案"| L3["回路 3 · Meta<br>架构演化（事件驱动）"]
    L3 -->|"新工具/新谓词/全局规则"| L2
    L2 -->|"范围变更/预算扩展"| L1
    ATT["注意通道<br>批准队列 + Morning Ritual"]
    L2 -.->|"需要裁决"| ATT
    L3 -.->|"修宪需 sudo"| ATT
    ATT -.->|"签名 / 裁决"| L2 & L3
```

### 7.1 回路 0 · Boot（每安装一次）+ 崩溃恢复

```mermaid
flowchart TD
    A0["0 启动 TuringOS.app"] --> A1{"本地已有 tape？"}
    A1 -->|"是（重启/崩溃后）"| RES["从 tape 重建 Q_t<br>恢复挂起批准与止损计数"] --> GO(("回到中断处<br>进入回路 1/2"))
    A1 -->|"否（首次启动）"| B["1 能力检测"]
    B --> C{"2 Facilitator 运行时"}
    C -->|"本地 Apple FM 可用"| C1["2A 本地 Facilitator"]
    C -->|"用户提供 API key"| C2["2B 云端 Facilitator"]
    C -->|"两者皆不可用"| C3["2C 降级模式<br>确定性模板 + 手动 Init"]
    C1 --> D["3 配置 Meta AI"]
    C2 --> D
    C3 --> D
    D --> CONSENT["4 系统宪法知情同意<br>L0 层（含操守五条）"]
    CONSENT --> PORT(("进入项目组合<br>回路 1"))
```

Boot 即宪法 Art. IV：把人类规范编译为机器谓词并写入信任根的过程在产品层分两段——L0 随安装完成，L1 在每个项目的立法回路完成。Boot 之后系统不再需要被"提起来"第二次：**崩溃恢复不是重新 Boot，而是从 tape 重建 Q_t**（Art. 0.2 的直接收益）。

### 7.2 回路 1 · 立法（每项目一次，可修订再入）

```mermaid
flowchart TD
    SEL["5 项目组合：选择/切换项目<br>各项目独立 Q_t 与批准队列"] --> E{"6 项目入册"}
    E -->|"新项目"| E1["6A New Init"]
    E -->|"已有项目"| E2["6B Retro-Init：后补 Genesis<br>Backfilled Spec + 现状锚点 + 已知债务"]
    E1 --> F["7 Init Spec Package（项目小宪法）<br>目标/非目标/DoD/验收谓词/数据边界/工具权限/CI 规则/风险/外派策略"]
    E2 --> F
    F --> H1[["签名 #1 · 批准 Init Spec"]]
    H1 --> G["8 预算 + 自治契约<br>money/tokens/wall-clock/tool calls/CI cycles/审阅负担/外派开销/止损线"]
    G --> H2[["签名 #2 · 批准预算与自治边界"]]
    H2 --> CRED["9 凭证范围声明<br>凭证存 Keychain/SE，tape 只记 scope 哈希"]
    CRED --> H3[["签名 #3 · 批准敏感数据域 / 外部凭证"]]
    H3 --> I["10 配置 Worker AI / 执行面"]
    I --> READY(("Project Ready<br>进入回路 2"))
    AMEND["修订再入（来自回路 2）<br>范围变更 → 改 Spec 重签 #1<br>预算耗尽 → 扩展走签名 #6"] -.-> F
    AMEND -.-> G
```

要点：

- **没有 Init Spec 的项目不能执行普通任务，只能运行 readiness task。**
- 凭证从不入带、从不入 prompt：执行面派发时由 Keychain/SE 注入运行环境，tape 记录的是凭证范围哈希（用了哪个 scope），不是凭证本身。
- 立法不是一次性的：回路 2 的止损与范围检查会把项目送回这里**修订再入**——签的是法律，法律可以修，但修法本身要签名。

### 7.3 回路 2 · 执行（内核主回路）

```mermaid
flowchart TD
    J["11 Meta AI 读 Q_t，建/更新 WorkGraph<br>注入规则库中的全局修复规则"]
    J --> BGT{"12 预算/止损检查点"}
    BGT -->|"耗尽"| HALTB["HALT-预算：失败证书入 tape<br>→ 注意通道（扩展走签名 #6 → 回路 1）"]
    BGT -->|"可行"| SHIELD["13 屏蔽层<br>Worker 只见任务+工具，不见谓词内部"]
    SHIELD --> FORK{{"14 fan-out：N 个 worktree 并行<br>上下文相互隔离（Art. III.3）"}}
    FORK --> K{"15 执行面（每 worktree 独立走完下游）"}
    K -->|"15A 内部 Worker"| K1["provenance = full"]
    K -->|"15B 外部 prompt 派发"| K2["provenance = partial"]
    K -->|"15C Computer-Use 辅助会话"| K3["provenance = partial"]
    K1 --> ACT{"16 动作分类<br>声明式：工具签名即类别"}
    K2 --> OBS["15B' 再入观测：轮询 git remote /<br>用户粘贴回执 → 校验分支存在+范围+标 partial"]
    K3 --> OBS
    OBS --> ACT
    ACT -->|"零类 只读"| RD["按策略放行，全部入 tape"]
    ACT -->|"一类 可逆本地"| SHADOW["影子工作区先行<br>diff 暂存待批"]
    ACT -->|"二类 远端草稿"| DRAFT["以草稿形态创建<br>→ agent 收到 status=staged"]
    ACT -->|"三类 不可逆外部"| H4[["签名 #4 · 批准卡<br>所见内容哈希入签名负载"]]
    H4 -->|"批准"| EXE["执行 + 回执入 tape"]
    H4 -->|"拒绝/超时"| REJ["拒绝入 tape（verified=false）<br>→ agent 收到 status=rejected"]
    RD --> WORK["17 候选分支 / PR"]
    SHADOW --> WORK
    DRAFT --> WORK
    EXE --> WORK
    REJ --> WORK
    WORK --> M["18 GitHub CI（外部谓词）"]
    M -->|"CI 红"| N["19 Meta AI 解析日志<br>最近失败谓词 + 修复 prompt（精准注入本 worktree）"]
    N --> NRULE{"重复跌倒？"}
    NRULE -->|"是"| RULES["抽象为全局规则入规则库<br>原始日志屏蔽，不群发"]
    NRULE -->|"否"| GUARD
    RULES --> GUARD{"20 止损护栏<br>尝试次数 / CI 预算 / token 预算"}
    GUARD -->|"未触线"| J
    GUARD -->|"触线"| HALTS["HALT-止损：失败证书入 tape<br>→ 注意通道（人类裁决：修法/换路/关闭）"]
    M -->|"CI 绿"| O{"21 Turing Predicate Gate（∏p）<br>Spec 符合 / DoD / diff 在 worktree 范围内 /<br>预算合规 / 回执完整 / 数据边界 /<br>provenance 阈值（partial → 强制人工确认）/<br>PCP 疑罪从无；主观项走 RiskFinding 不冒充谓词 /<br>触及策略面 → Veto-AI {PASS,VETO}"}
    O -->|"∏p = 0"| P["22 失败节点入 tape：Q 不前进<br>reject_class + 最近失败谓词 + 修复建议"]
    P --> GUARD
    O -->|"∏p = 1"| Q["23 Merge Dossier<br>Spec delta / CI 摘要 / 证据 / 风险 / 回滚计划 /<br>预算消耗 / provenance / RiskFinding 清单"]
    Q --> RAT{"24 批准路由（按自治契约）"}
    RAT -->|"低风险且契约允许"| R["25 GitHub Merge"]
    RAT -->|"保护面 / 高爆炸半径 / partial provenance"| H5[["签名 #5 · 批准合并/发布"]]
    H5 -->|"批准"| R
    H5 -->|"用户不在"| WAITQ["挂起入批准队列<br>不阻塞其他 worktree"]
    WAITQ -.->|"用户回来裁决"| H5
    R --> S["26 Q_t+1：merge SHA 锚定 HEAD<br>回执入 tape，预算结算"]
    S --> GC["27 worktree GC<br>清理临时分支/影子副本；清扫入回执"]
    GC --> T["28 策略回路：Stumps / 组合搜索 / 市场观测"]
    T -->|"WorkGraph 未竟"| J
    T -->|"DoD 全满足"| DONE(("HALT-达成：里程碑回执<br>Morning Ritual 呈报"))
    T -->|"用户中止"| ABORT(("HALT-中止：部分 tape 封存<br>worktree 暂存"))
```

逐点说明（对应图中编号）：

- **12 预算检查点**：预算在三处被触碰——派发前检查（12）、CI 完成后扣减（18 之后计入止损护栏 20）、merge 后结算（26）。预算与止损线来自签名 #2 的自治契约，不是内核拍脑袋。
- **13 屏蔽层（Goodhart）**：Worker 收到"做什么、有什么工具"，不收到谓词阈值与评分内部。公开的 CI 按其本性公开；内核侧验收检查保持在 Worker 不可读区域。
- **14 并发与隔离**：每个 worktree 独立走 15→21 的全程，**谓词门逐 worktree 触发**；一个 worktree 的失败不中止其余（组合层面的中止由止损护栏与用户裁决）。隔离是宪法义务（Art. III.3）：独立上下文、独立会话，失败叙事不横向传染。
- **15B' 外部派发的再入**：复制给 Codex/Claude Code 的任务不会"自动出现"在流程里——内核以观测触发再入：轮询 git remote 发现新分支，或用户把产物粘回；校验分支存在、diff 范围、标注 `provenance=partial` 后才进入动作分类。**外部 Agent 若不经 TuringOS 通道执行，只能生成 repo 级 / PR 级回执，不得声称拥有动作级回执。**
- **16 动作分类**：声明式，工具签名即类别（§10 三类动作）。模型产出的摘要与标签仅用于呈现，永不进入分类与放行路径。来自 Capability Registry 的第三方能力以其 manifest 声明的类别入门；**未声明或无法核验类别的能力 fail-closed——按三类（不可逆外部）处置或直接拒绝**（§13.8）。
- **staged 诚实（操守 #4）**：DRAFT 与 REJ 节点的回边是流程的一部分——agent 同步收到 `status=staged/rejected`，据此绕开该动作继续规划，而不是重试同一动作。
- **20 止损护栏**：CI 修复回路（18→19→11）与谓词失败回路（22→20→11）共用同一护栏——尝试次数、CI 预算、token 预算任一触线即 HALT-止损，失败证书入 tape，人类在注意通道裁决：修法（回路 1）、换路（策略回路）、或关闭。**没有无界重试。**
- **21 谓词门**：CI 绿只是外部谓词之一。门内是 predicate product：任何一项 FAIL 则 ∏p=0，Q 不前进。partial provenance 的候选**不允许纯谓词放行**——强制升格为人工确认（24 路由至签名 #5）。
- **23 Merge Dossier**：由 Meta AI 生成、由 Kernel 约束结构。RiskFinding 清单（PCP 域的主观发现）附于其上供人类裁决——主观判断有通道，但不冒充谓词。
- **26–27 收尾**：merge SHA 锚定 HEAD_{t+1}；回执与预算结算入 tape；GC 清理并留痕。

### 7.4 回路 3 · Meta（架构演化，事件驱动）

```mermaid
flowchart TD
    TAPE["tape 统计信号<br>重复 reject_class / 工具缺口 / 谓词漏检"] --> ARCH["ArchitectAI 提案<br>新工具 / 新谓词 / 新 schema / 新投影模板"]
    ARCH --> VETO{"Veto-AI 违宪审查<br>输出域 {PASS, VETO}，fail-closed"}
    VETO -->|"VETO"| TV["否决 + 理由入 tape"] --> ARCH
    VETO -->|"PASS"| SCOPE{"触及面"}
    SCOPE -->|"不动宪法且契约允许"| COMMIT["ArchitectAI 落盘<br>manifest 更新 + 修订入 tape"]
    SCOPE -->|"契约要求人批的类别"| H7[["签名 #7 · 批准工具/谓词/策略升级"]]
    H7 --> COMMIT
    SCOPE -->|"触及系统宪法（L0）"| H8[["签名 #8 · sudo 修宪仪式<br>修订日志留痕（Art. V.3）"]]
    H8 --> COMMIT
    COMMIT --> BCAST["广播：更新后的全局规则/工具<br>注入后续 WorkGraph（回路 2）"]
    GARD["园丁职责（定期）<br>清扫过期规则/陈旧文档/死分支<br>清扫回执入 tape"] --> BCAST
```

这是 v0.3 流程图完全缺失的回路：系统的自我进化不混在任务流里，而是独立的三权分立回路——ArchitectAI 提案（突变）、Veto-AI 审查（选择）、宪法与签名（机制）。修复规则库由此回路维护，回路 2 只消费。**Live Software 3.0（§13.10）不是新回路，而是本回路的数据飞轮扩展**：tape 上的失败与使用数据经本地小模型聚类后，成为 ArchitectAI 提案的输入——入口不变、闸门不变。

### 7.5 注意通道与 Morning Ritual

- **挂起不阻塞**：任何签名请求（#4/#5/#6）在用户不在场时进入批准队列，所属 worktree 挂起，**其余 worktree 照常推进**。
- **打扰有门槛**：通道按三定律呈现——需裁决的置顶，进行中的呼吸，安静即成功。
- **Morning Ritual 是 tape 的 reduce**：每天早晨对昨夜 tape 做一次确定性归并——Done / Staged / Needs Approval / Blocked / Failed 五栏，每项可下钻到证据。失败项不是日志垃圾，是 Failure Certificate 和下一轮建议。
- 这对应宪法 Art. IV 的 map-reduce tick：呈现是周期性的派生计算，不是另一份账本。

### 7.6 终止态分类（HALT taxonomy）

| 终止态 | 触发 | 入 tape 的内容 | 下一步 |
|---|---|---|---|
| **HALT-达成** | DoD 全满足 | 里程碑回执 + HEAD 锚 | Morning Ritual 呈报；项目可关闭或开新 WorkGraph |
| **HALT-预算** | 预算耗尽 | 失败证书 + 已消耗明细 | 签名 #6 扩展 → 回路 1，或关闭 |
| **HALT-止损** | 重试触线 / 不可解谓词失败 | 失败证书 + reject_class 史 | 人类裁决：修法 / 换路 / 关闭 |
| **HALT-中止** | 用户主动中止 | 部分 tape 封存 + worktree 暂存清单 | 可恢复（tape 重建）或 GC |
| **崩溃** | 进程死亡 | （无新增——tape 本就逐事件落盘） | 重启 → 从 tape 重建 Q_t（§7.1） |

---

## 8. TuringOS Kernel

Kernel 是整个 operating flow 的中心，不是 UI 的后端附属物。

```text
Q_t = ⟨q_t, HEAD_t, tape_t⟩
        ↓ rtool
input = 当前状态 + 相关 tape 切片 + spec + git + PR + CI 证据（最小充分上下文）
        ↓
Middle Blackbox = Meta AI / Worker AI / 外部 agents
        ↓
output = 候选动作 / 分支 / PR / 工具提案 / 策略提案
        ↓
Top Whitebox = 谓词 ∏p + Veto-AI + 预算 + provenance 阈值 + 屏蔽
        ↓
if ∏p = 1: wtool 提交 Q_{t+1}（tape 追加 + HEAD 前移）
if ∏p = 0: Q_t 不变，失败以 verified=false 入 tape
```

> 与 v0.3 的一处显式修正：v0.3 此图把 market signal 列在 Top Whitebox 的放行行里。依宪法 Art. I.2 / II.2 与 v0.3 自己的 §10（"Market signal ≠ predicate truth"），市场信号是统计/广播信号，永不进入 ∏p——v0.4 将其移出放行行，替以 provenance 阈值。市场信号的位置在 §12。

### 8.1 Bottom Whitebox

读取与执行：Git、Tape、Spec、Policy、工具 manifest、GitHub 状态、CI 证据、外部 Agent 产物。rtool 按 Art. III.2 装配最小充分上下文。

### 8.2 Middle Blackbox

提议：Meta AI 规划、Worker AI 执行、外部 Agent 生成候选。黑盒内部推理不被信任，系统只信可观察、可验证、可重建的行为结果。**黑盒与其模型供应商之间的流量对 Kernel 不可见——这是形态边界，不是实现疏漏（§14.2 横切边界）。**

### 8.3 Top Whitebox

量化、广播、屏蔽（义务表见 §4.5）：量化 CI/tests/预算/范围/回执/provenance；广播典型错误抽象、策略树桩、价格信号、修复规则；屏蔽坏日志、Goodhart 细节、横向相关性污染、过期上下文。

### 8.4 Failure Node

失败不是垃圾。失败必须入 tape：`reject_class`、最近失败谓词、尝试摘要、预算消耗、修复建议、provenance。它是下一轮搜索的资产，也是回路 3 的统计输入。

---

## 9. 签名节点（Touch ID）

签名不是微操作确认器。它是法律边界、不可逆动作和保护写入的物理签名。八个节点在四回路中的位置：

| # | 节点 | 所在回路 / 流程位置 |
|---|---|---|
| 1 | 批准 Init Spec / Project Ready | 回路 1（图 7.2 H1）；范围变更重签亦在此 |
| 2 | 批准预算与自治契约 | 回路 1（H2） |
| 3 | 批准敏感数据域 / 外部凭证 | 回路 1（H3，凭证范围声明之后） |
| 4 | 批准不可逆外部动作 | 回路 2 三类动作支路（H4） |
| 5 | 批准保护写入 / merge / release / publish | 回路 2 批准路由（H5）；partial provenance 强制走此 |
| 6 | 批准超预算扩展 | HALT-预算 → 注意通道 → 回路 1 修订再入 |
| 7 | 批准工具 / 谓词 / 策略升级（契约要求时） | 回路 3（H7） |
| 8 | 修宪 / sudo 仪式 | 回路 3（H8），修订日志留痕 |

> 注：v0.3 流程图只画了 3 个签名节点，且把"批准 merge"标为 Touch ID #3——而 v0.3 自己的 §8 清单已把 #3 定为凭证域、#5 定为保护写入。v0.4 依清单统一编号（merge 归 #5），并把 #3/#4/#6/#7/#8 全部画进对应回路，消除图与清单的不一致。

密码学形态与诚实边界（细节与来源见 [FEASIBILITY.md](FEASIBILITY.md)）：

- Secure Enclave 驻留 P-256 签名私钥，访问控制 `.privateKeyUsage + .biometryCurrentSet`：每次签名要求一次新鲜 Touch ID 手势（重用时长 0），私钥永不离开 SE；指纹重录自动作废钥匙——换了手指，就该重新建立信任。
- **SE 签的是字节，不能证明你看到了什么。** 所以批准卡内容（agent 名、动作、目标、参数摘要、风险类别、可逆性）的规范化哈希由应用计算并**纳入被签名的负载**——签名绑定的是"这张卡"，回放时验的也是"这张卡"。
- 批准仪式发生在 GUI 应用里，不在后台 daemon 里——daemon 只验签、永不持有人类根私钥（ADR-005）。
- macOS 27 起 App Attest 登陆 Mac 并在 attestation 证书携带 SE 访问控制条件，为未来第三方审计方确认"这把钥匙确为生物识别门控"提供升级路径。
- **过渡说明**：v0.x 早期版本以应用内明确批准门控（非生物识别），draft-by-default 自第一版即生效；Touch ID + SE 签名按路线图（§18）升级——能力边界如实分版本陈述。

### 9.1 Hostile Host 安全模型：威胁阶梯与两层架构

签名仪式防什么，必须按威胁分级说清（先例与来源见 FEASIBILITY Part IV）：

| 威胁级 | 对手 | 防御 | 状态 |
|---|---|---|---|
| **T0** 善意故障 | bug、误操作 | 谓词门 + draft-by-default + 还原点 | v0.x 全覆盖 |
| **T1** 恶意能力 | 恶意 skill/工具/MCP server | Capability Registry fail-closed + 动作分类 + 签名#4/#5 | v0.x 覆盖（限通道内） |
| **T2** 被注入/被劫持的 agent | prompt injection、被攻陷的外部 agent | 有后果动作过门 + 批准卡第一方渲染 + provenance 阈值 | v0.x 覆盖（限通道内；注入本身不可根除，§14.2） |
| **T3** 敌意宿主 | 宿主 OS 被 AGI/恶意软件完全控制 | **本机任何 UI、哈希、验签都可被篡改**——需要宿主之外的锚 | v0.x **不防，且如实声明不防** |

**Hostile Host 公理（写进产品而不是藏起来）**：若批准的验证、审计的记录或最终的执行只发生在可能被攻破的宿主 OS 之内，TuringOS 不得宣称 AGI 级 sudo 安全。Secure Enclave 保护的是私钥，不能在宿主被完全攻破时保证"你真实看到的 UI"与"被签名的字节"一致（WYSIWYS）。

两层架构：

- **Tier 1 · Mac 本地批准签名器（v0.x，§9 正文）**：SE + Touch ID + 所见哈希入负载。覆盖 T0–T2，是消费级威胁下的正解。Apple Watch 的 `deviceOwnerAuthenticationWithWatch` 可作为在场因子叠加，但表上只能显示通用批准 UI、无法呈现自定义动作详情——它增强在场性，不构成独立可信显示，我们如实归入 Tier 1。
- **Tier 2 · 外部 Sudo-Anchor（路线图远期，T3 答案）**：独立显示 + 物理确认按键的宿主外设备；Audit Anchor（Merkle 包含证明的追加式日志，Sigstore Rekor 模式）；独立于宿主的 Execution Gate；批准 token 绑定 HEAD_t、audit_head_t、gate_id、nonce、计数器与时效；**无审计包含证明则不执行（no-audit-no-execution）**。

Tier 2 不是空想，是成熟模式在 agent 时代的重述：硬件钱包的安全屏（签名与显示同一安全域）、银行 chipTAN（独立设备显示交易内容，PC 被木马也改不了已确认的交易）已验证此路三十年；2026-05 面世的 Foundation Passport Prime 自称首个 "Human Authority Hardware"，证明品类正在成形。反面边界同样如实：FIDO2 的交易确认扩展已关闭未合并（现役硬件 key 无可信显示），学术界（OAP 等）自陈不防 compromised runtime——T3 仍是 open problem，TuringOS 把它列为路线图研究项，不列为已解承诺。

---

## 10. 三类动作：一张诚实的风险地图

所有经由通道、会产生副作用的动作分为三类（只读是零类）。**分类即策略**：类别由声明式工具签名决定（§7.3 节点 16），决定默认处置。

| 类别 | 例子 | 默认处置 | 撤销真相 |
|---|---|---|---|
| **零类：只读** | 读指定目录、查日程、读 PR 状态 | 按策略自动允许；全部入 tape | 无副作用 |
| **一类：可逆本地** | 移动/编辑文件、改代码、建分支 | 影子工作区先行；批准后应用；保留还原点 | 真撤销（应用前丢弃 / 应用后还原） |
| **二类：可暂存远端草稿** | 邮件草稿、暂定日程、文档草稿 | 直接以"草稿"形态创建在目标系统；最终发送仍属三类 | 草稿可删；不假装"发送可撤销" |
| **三类：不可逆外部** | 发邮件、付款、发帖、提交表单、删远端数据 | **永远不自动执行。** 批准卡 + 签名 #4；所见哈希入签名负载 | **无法撤销，前置同意是唯一保护** |

批准卡上永远写明动作属于哪一类、能否撤销。我们不用模糊的"安全/不安全"，而用"可逆/不可逆"这种可被检验的语言。撤销的实现诚实：还原点由影子工作区自身的版本化提供，不依赖、不承诺系统级快照还原（理由见 §13.3）。

---

## 11. Project Strategy Loop：项目树桩与 MCTS-lite（TBD）

复杂项目不是线性任务，而是策略树。Meta AI 应主动帮助用户生成 Project Stumps（项目拓展树桩）：一个可能的产品方向、一条可验证的技术路线、一个 worktree arm、一个实验假设、一个风险隔离分支、一个候选 PR、一个文档/架构/市场方向。

v0.4 维持 v0.3 的裁决：先采用 **portfolio search + 可见策略树**，不立即实现全自动的不透明 MCTS。MCTS-lite 的候选定义：

- Node = Project Stump / Worktree / PR candidate；
- Edge = WorkTx / agent attempt；
- Reward = predicate pass + CI signal + user approval + value claim − cost − risk；
- Exploration / Exploitation 平衡受 Art. II.2.1 约束：价格信号引导注意力但不得抹杀群体异质性；
- Market signal = 资源与注意力权重，不是真理。

**待决问题**（标注 TBD，留待专题裁决）：哪些 stump 可自动生成、哪些必须用户批准；reward 若成为优化目标如何防 Goodhart（宪法 Art. III.4 的答案方向：reward 细节对生成方屏蔽，只广播排序后的注意力信号）；CI cycles / API cost / 人类注意力 / merge risk 如何计价；Market 取 auction / credits / UCB / 混合中的哪种机制。

---

## 12. Market Module：信号，不是真理

宪法允许价格信号作为统计信号和广播信号（Art. I.2 / II.2），其经济学底座是基本法：**Information is Free（搜索与查看零成本）；Only Investment Costs Money（1 Coin = 1 YES + 1 NO 守恒，on_init 是唯一合法铸币点）**。产品层分阶段：

- **v0：observe-only。** 只记录：预算消耗、队列拥堵、重复失败、CI 成本、worker 可靠度、人类审阅负担、任务价值声明——全部是对 tape 的确定性统计（§4.5）。
- **v1：辅助排序。** 队列排序、worker 选择、review 排序、strategy stump 排名。
- 完整 token 经济（CTF 守恒的内部市场）是否进入产品，依实验证据另行裁决——宪法提供了语义，产品不提前承诺。

边界恒成立：**Market signal ≠ predicate truth。** 任何写入仍必须通过 Spec、CI、谓词、Veto-AI、预算和人类批准。

---

## 13. 技术底座：Apple-native × protocol-native

深度拥抱 Apple 生态（§13.1–13.5），但不伪装成系统级监控软件；同时以协议层（§13.6–13.10）接入整个 agentic 生态——最大化利用外部优秀产品与服务，不从零重造。以下 Apple 能力每项都只需标准开发者资格，**没有任何一项依赖 Apple 的特批**；逐条来源与核验状态见 [FEASIBILITY.md](FEASIBILITY.md)（Part III 待实证清单 + Part IV v0.5 调研附录）。

### 13.1 Foundation Models

Facilitator AI 默认优先使用 Apple Foundation Models：端侧、离线、推理免费，基础使用**不需要 entitlement、waitlist 或 Apple 审批**（仅自训 adapter 需要——我们不用）。定位：本地、轻量、隐私优先的操作协助、摘要、分类、解释和界面生成辅助。

- 它不替用户做最终决策，不进入核心策略执行链，不替代 Meta AI；**模型产出的摘要与标签仅用于呈现，永不进入策略引擎与动作分类路径**。
- 2025 代端侧模型按官方口径约 4,096 token 的上下文窗口（核验状态见 FEASIBILITY Part I）决定了喂给它的是逐段动作摘要，不是原始转录——这与"本地、轻量、辅助"的定位一致。WWDC 2026 的更大端侧模型与 `LanguageModel` 协议是后续选项。
- 新的免费 Private Cloud Compute 档**仅限 App Store 小企业计划成员**，对 Developer ID 分发不可用——无妨，纯端侧本就是唯一符合操守的选择。
- 模型可用性必须运行时检查：设备不支持或 Apple Intelligence 未开启时，优雅降级为确定性模板句（§6.3 / §7.1 节点 2C）。

### 13.2 Touch ID / Secure Enclave

见 §9。用于签名八个节点；密钥规格、`.biometryCurrentSet`、所见哈希入负载、App Attest 升级路径均已写明。

### 13.3 Shadow Workspace（影子工作区）

可逆本地动作先进入影子工作区。诚实的选项排序：

1. **用户态暂存工作区（v1 默认）**：副本目录 + 版本化暂存（git 语义）。零 entitlement、零特殊 OS 版本要求——唯一今天就对所有用户成立的方案。
2. **Apple Containerization（可选执行隔离档）**：Apple 官方 container 库 1.0（2026-06）可被第三方 Swift 应用内嵌；它隔离的是 **Linux 虚拟机**，适合 shell/构建类高危执行，不是 macOS 原生进程沙箱；其目录共享是实时读写，用于隔离时必须指向副本目录。
3. **不取的路径，如实说明**：App Sandbox 只能约束我们自己的进程；APFS 快照创建是受限 entitlement、回滚是私有 entitlement——**我们不承诺"系统级快照还原"**；`sandbox-exec` 已弃用，不做地基。

### 13.4 GitHub

GitHub 继续负责 PR、CI、branch protection、merge commit——TuringOS 不复制 GitHub 的执行功能。TuringOS 是 Meta Governor：观察 PR/SHA/diff、导入 CI 状态与日志摘要、失败时生成修复任务、通过时把 CI 作为外部谓词送入 Predicate Gate、生成 Merge Dossier、merge 后锚定 HEAD_{t+1}。GitHub 说"CI green"；TuringOS 判断"这个 green 是否足以让当前 Spec 下的世界状态前进"。

### 13.5 分发

Apple Developer Program → Developer ID 证书 → Hardened Runtime → notarytool 公证 → 装订。自 macOS Sequoia 起未公证软件已无右键绕行，正经公证是唯一体面的分发方式。Hardened Runtime 禁止注入其他进程——**不注入**正是本产品的设计原则，两者天然相容。后台项经 SMAppService 注册时系统会通知用户并要求批准——OS 级可见性与我们的同意哲学同向。

### 13.6 Agentic 协议层

外部协议是传输与能力面，不是事实源。分层与取舍（生态事实截至 2026-06，见 FEASIBILITY Part IV）：

| 协议位 | 选择 | 依据与姿态 |
|---|---|---|
| **工具协议** | **MCP（核心）** | LF/Agentic AI Foundation 治理，现行规范 2025-11-25（新版 2026-07-28 定稿在即）；TuringOS 既做 MCP client（吃进外部工具）也做 MCP server（把网关工具供给外部 agent） |
| **Agent 间协议** | **A2A（适配层）** | 2026-03 达 v1.0 生产级、LF 托管；**出站委托先行**（把工单交给外部 agent）；入站受托（别的 agent 把活派给 TuringOS）牵涉"谁是委托人"的同意问题，缓议 |
| **UI 扩展协议** | **MCP Apps（优先）** | 首个 official MCP extension（2026-01），与 OpenAI 联合制定（Apps SDK 即建于 MCP）；与本产品 Generative 投影同构 |
| **生成式 UI 格式** | A2UI / AG-UI（仅 adapter） | A2UI 官方自述 early-stage（v0.8）；AG-UI 属 CopilotKit（MIT）——一律经 View IR 翻译（§6.6），不深度锁定 |
| **技能格式** | SKILL.md 兼容（§13.9） | 已是开放标准，2026-03 已 32 个工具支持 |
| **模型协议** | 三面 Gateway（§13.7） | OpenAI Chat Completions / OpenAI Responses / Anthropic Messages |

**协议层铁律**：任何外部协议都不得绕过 ChainTape、Predicate Gate、动作分类、provenance 标注与人类签名路由。外部协议负责互操作；TuringOS 负责法律、谓词、签名、审计、状态迁移。

### 13.7 Model Gateway

两类接入面，严格区分（经济学事实见 FEASIBILITY Part IV-2）：

- **A 类 · 模型 API 供应方**：OpenAI / Anthropic / Gemini / xAI / 本地（Apple FM 与自托管）。按 provider 凭证计费。Gateway 内置三种 API 形态适配：OpenAI Chat Completions（普适事实标准）、OpenAI Responses（agent 向新形态）、Anthropic Messages（原生）；Gemini 官方提供 OpenAI 兼容端点（beta），xAI 一手确认 OpenAI SDK 兼容。
- **B 类 · 外部 app/agent 委托面**：Codex、Claude Code、OpenClaw、Hermes、MiMo Code 等——用户自己登录第三方产品，TuringOS 经 Git / MCP / CLI / hooks 治理边界（§14.4）。**订阅不是隐形模型供应方**：ChatGPT 订阅不含 API 用量（两套计费体系）；Codex 含于 ChatGPT 各计划属 B 类事实。订阅 OAuth 直连（OpenClaw 经 Codex 端点的先例）与 Anthropic 据报道自 2026-06-15 起实施的 Agent SDK credit 池，Gateway 按"出现即支持"设计、不写进承诺（待实证项 9/10）。

恒定规则：

- 凭证存 Keychain / SE 保护项；tape 只记 `credential_scope_hash`；prompt 不得含凭证。
- 每次模型调用写 ModelCall 节点入带：provider、model、cost、latency、policy，**默认含输入输出全文**（tape 在用户自己的机器上，全文才支撑可回放）；用户可启用脱敏档改记内容哈希——**脱敏即如实标注该段回放降级**，不假装仍可全量重建。
- 模型路由遵循 §5.6 判据清晰度律；Gateway 是**底层白盒**管道（工具层），不做任何放行裁决——放行裁决属顶层白盒。

### 13.8 Capability Registry：底层白盒能力注册表

不做传统插件市场——agentic 能力不是 UI 扩展，是**可行动作面**（OpenClaw 技能生态的供应链事故是已付学费，§15）。TuringOS 的市场体验之下是一张**底层白盒**注册表（注册的全部是反奥利奥架构的工具层对象，与顶层白盒的谓词/管理严格分层），对象包括：工具、技能、连接器、模型供应方、agent adapter、view renderer、执行 profile。

每个能力必须有 manifest，机器可校验：

```yaml
id: com.example.github.pr
kind: tool | skill | connector | model_provider | agent_adapter | view_renderer
version: 1.2.0
vendor: verified | community | local   # verified = 发布者签名身份经注册表核验，非品质背书
action_classes:            # 声明式：工具签名即类别（§10）
  default: class_1_reversible_local
  escalation:
    protected_branch_write: signature_5
permissions:               # 文件域 / 网络域 / 凭证 scope，最小授权
credentials: [github_oauth_repo_read]
provenance: { action_receipt: true, replay: true }
sandbox: { container_lane: optional }
evals: { install: tests/install.yaml, replay: tests/replay.yaml }
```

**Install ≠ trust** 的机械含义：

1. manifest 无效 → 不可启用；
2. 权限与动作类未向用户呈现 → 不可启用；
3. **未声明或无法核验动作类 → fail-closed，按三类处置或拒绝**（§7.3 节点 16）；
4. 凭证 scope 与 prompt 上下文隔离；
5. 安装、升级、移除全部入带（ToolInstall / ToolUpdate / ToolRemove 节点），可回放、可回滚；
6. 回执不可回放的能力必须显式标注 partial——谓词门按 provenance 阈值对待。

### 13.9 Skill Library

Skills 是一等**底层白盒**能力包，不是 prompt 模板。格式上**兼容 SKILL.md 开放标准**（Anthropic 2025-12-18 发布，渐进披露三级加载；2026-03 已 32 个工具支持——这正是 Art. III.2 封装细节的业界收敛），外加 Turing 法律外壳：

> **Turing Skill = SKILL.md（instructions + scripts + schemas）+ 权限 + 动作类 + 回执 schema + replay 规则 + evals + failure_modes**

- Skill 的权威只来自项目 Spec、Capability Registry、Predicate Gate 与 ChainTape 回执——不来自它自己的文字。
- Skill 可由用户创建，也可由 ArchitectAI 提案（§13.10）；**激活是状态迁移，必须入带**。
- 初始库 12 类（按日常工作场景预置）：Project Init/Retro-Init、GitHub PR/CI Repair、Merge Dossier、Markdown→文档/幻灯、表格/CSV 分析、调研引证、邮件草稿、日程草稿、浏览器调研、Xcode Build/Test、Canvas 投影、Failure Certificate/根因。

### 13.10 Live Software 3.0 回路

让系统在使用中变活——但**自我迭代的对象是白盒脚手架（底层白盒工具、顶层白盒谓词与投影模板），永远不是中间黑盒的任意自我变异**。这不是新机制，是回路 3（§7.4）的数据飞轮扩展：

```text
tape 产生原料：FailureNode / 拒绝记录 / 工具回执 / CI 修复史 / 用户纠正 / 重复 WorkGraph 模式
  → 本地小模型做聚类·摘要·检索（分类/路由/failure clustering/skill retrieval——判据清晰档）
  → ArchitectAI 产出候选白盒工件：候选 Skill / 候选谓词 / 候选投影模板 / 候选工具包装 / 候选路由规则 / 候选 adapter 训练集
  → Veto-AI {PASS, VETO} 违宪审查
  → eval 验证（候选 Skill 必须在留出案例上通过——只对历史失败过拟合的"修复"是 Goodhart，Art. III.4）
  → 契约要求时人类签名（#7）
  → 激活入带，版本化，可回滚
```

Apple 端侧底座的事实边界（FEASIBILITY Part IV-3）：adapter 训练官方即 LoRA（用户 v0.3 评审中的原始表述经查正确）；部署需专项 entitlement（训练与本地测试不需要）；**每个 adapter 绑定特定基模型版本，OS 升级即须重训——这是持续运营税，路线图按年度预算**；端侧约 3B，定位摘要/抽取/分类而非世界知识；WWDC26 的 LanguageModel + LanguageModelExecutor 双协议允许把任意本地或云端模型接入同一框架。adapter 产物与一切模型产物同律：**仅用于呈现与路由辅助，永不获得 Predicate Gate 权威**。

先例与师承：Hermes 的"经验→技能→使用中改进→持久化→检索"循环、小米 MiMo Code（2026-06-10，MIT）的 `/distill` 技能蒸馏与 SQLite FTS5 跨会话记忆、研究线的 SEAL / AlphaEvolve / SAGE——技能库式自进化正在工业化。TuringOS 的差异：**别人的 agent 自己学；TuringOS 让学习产物过宪法的门。**

---

## 14. 接入哲学与外部 Agent 边界

### 14.1 为什么是协作式接入，而不是 OS 级监控

| 路径 | 需要什么 | 取舍 |
|---|---|---|
| **MCP 网关**（agent 配置指向我们的工具） | 零 Apple 许可，纯用户态 | **采用**——接入即同意 |
| **CLI 包装**（受监督环境中启动 agent） | 零 Apple 许可 | **采用**为第二接入方式 |
| Endpoint Security 框架 | 受限 entitlement，个案申请，惯例发给安全厂商 | **不取**：对消费级不现实，且全局监控形态与操守第 1 条相悖 |
| Network Extension 内容过滤 | entitlement 自助 + 系统扩展批准 | **不取**（v1）：网络层看不懂动作语义，形态偏监控 |
| Accessibility / 屏幕观察 | TCC 授权 | **不取**：近乎暗中监视，原则排除 |

MCP 已是多厂商开放标准（LF Projects 治理）。最关键的一句话来自规范本身：MCP 规范原文：host"必须在调用任何工具前取得用户明确同意"，同时规范自陈**协议层无法强制执行**这一点。这个"应当如此但无人执行"的缝隙，就是本产品的接入面位置。Apple 自己也在向同一哲学收敛（App Intents 风险分级确认、Siri 逐项确认），但 Apple 管的是自家动作面——**跨 agent 的中立批准台账与可导出的本地审计历史仍是空位**。

### 14.2 两条横切边界（对所有集成一体适用，必须先说）

- **agent 与其模型供应商之间的流量对网关一概不可见**——包括经通道读到的内容被组装进提示送往模型。这不是某家 agent 的缺口，是网关形态本身的边界；对第一方 Worker 的模型流量同样成立（§8.2）。
- **网关不解决 prompt injection 本身。** 它做的是：即使 agent 被不可信内容注入，有后果的动作在执行前仍须经法律与签名——且仅限经由通道的动作。注入的根除不在任何网关的能力范围内。

总原则说死：**自愿接入的通道是同意与可见性层，不是围堵边界。** 拥有通用 shell / 代码执行能力的 agent 可以直接调用任何 API、驱动无头浏览器——完全绕过任何网关。"全覆盖"在这一产品形态下技术上不成立，任何此类宣称都经不起检验。

### 14.3 Provenance 分级与逐 agent 边界卡

- 凡经由 TuringOS 工具通道的动作 → **动作级回执（provenance=full）**。
- 发生在外部 App 内、未经通道的动作 → 只能生成 **repo 级 / PR 级回执（provenance=partial）**，谓词门对其强制人工确认（§7.3 节点 21）。

每个集成发布时附带一页**边界卡**：经由通道的动作面 / 通道之外的动作面 / 如何收窄 / 对应 agent 版本与核验日期。各 agent 周更级演进，边界卡随版本重核。截至 2026-06 的硬事实（来源见 [FEASIBILITY.md](FEASIBILITY.md)）：

- **OpenClaw**：接入面最厚——`before_tool_call` 插件 hook + 工具组关停 + MCP + 原生 exec 审批可叠加；但频道发信等内置动作不经任何 MCP，纯 MCP 模式边界须逐条展示。
- **Hermes**：MCP 原生，但其自带审批只盖危险 shell 命令；文件写、浏览器、发信、**computer_use（macOS 桌面控制）**都不在其审批面内，且容器后端下危险命令审批被显式跳过。
- **Claude Code**：hooks 强，但 **PreToolUse 的 deny 对 MCP 工具调用不强制执行**（官方 issue 关闭为 not-planned）；云会话跑在托管 VM 上，本机 hooks 不随行。
- **Codex**：hooks 新生且官方自述拦截不完整；**Codex Cloud 任务在本机网关之外**（OpenAI 托管环境，按云端 per-environment 设置管网络）。

### 14.4 External Agent Adapter Contract

外部 agent（OpenClaw / Hermes / Claude Code / Codex / MiMo Code / …）以统一契约接入，不逐家深度定制：

```text
ExternalAgentAdapter
  ├── input:      WorkOrderPackage（任务、范围 allowlist、验收谓词、预算、边界声明）
  ├── handoff:    Git branch / PR · MCP task · CLI 受监督会话 · prompt 包 ·（可用时）A2A
  ├── output:     观测到的 diff / PR / 回执 / 日志摘要（再入观测触发，§7.3 节点 15B'）
  ├── provenance: full | partial（partial 不得纯谓词放行）
  └── boundary_card: 通道内动作面 + 绕过面 + 收窄方法 + 版本与核验日期（§14.3）
```

**Git 是首选公共底座**——宪法本就要求 Q_t 是 version-controlled 状态：外部 agent 只要交付 branch / commit / diff / PR / CI result，就能进入谓词门，零定制成本。深度定制仅当四条件同时成立：真实用户规模、能给动作级回执、维护成本不损内核抽象、边界卡能保持最新。开放性原则不变：作为 OS 原则上支持运行各种优秀 agentic 程序，但统一抽象优先于逐家优化。

**如实声明一项未竟调研**：各 agent 社区的用户粘性、切换成本与用户群体规模评估（评审要求"社区调研而非主观感受"）本版**尚未进行**——已列入 FEASIBILITY Part III 增补第 13 项跟踪；上文"真实用户规模"作为深度定制门槛条件，其判定依据即该项调研的产出，做完之前不下结论。

---

## 15. 需求证据与竞品诚实

风险不是想象（均为厂商署名、可溯源的公开记录，详见 [FEASIBILITY.md](FEASIBILITY.md)）：lethal trifecta 框架（私有数据 × 不可信内容 × 对外通信）；GitHub MCP 注入泄私库；首个野生恶意 MCP server（postmark-mcp 静默密送邮件）；OpenClaw 生态的 ClawHavoc 恶意技能攻击波与 Snyk 扫描结果；OWASP Agentic Top 10。须如实说明：postmark-mcp 这类"agent 直连恶意工具"的攻击面恰属任何自愿网关的通道之外——我们引它们证明问题类别的真实性，不是宣称本产品对它们的覆盖。

竞品如实说：企业侧 MCP 网关已拥挤（控制面形态、YAML/CEL 策略）；消费侧最接近的只管凭证取用批准；各 agent 自带的安全层真实存在（Hermes 的危险命令审批、OpenClaw 的可选沙箱），我们如实承认并赞赏。Turing 的差异是**跨 agent 的统一动作分类、签名仪式、用户拥有的可回放 tape**——互补，不替代。这是空隙，不是空想（法源：§14.1 的 MCP 规范缝隙）。

---

## 16. 产品体验：从第一秒到闭环

1. **首次打开**：屏幕中央出现动态气泡。"帮我设置 TuringOS。" Facilitator AI 解释将检查能力、设置模型、读取项目、建立第一个 Spec。
2. **配置 Meta AI**：引导输入或选择 endpoint，设为主规划器。
3. **项目发现**：Meta AI 读取 Git 项目、活跃分支、GitHub PR、文档，生成项目选择卡。
4. **Init / Retro-Init**：Meta AI 与用户沟通生成 Spec；半途接手走 Retro-Init。签名 #1。
5. **预算与自治契约**：Meta AI 提出预算，签名 #2；凭证域签名 #3。
6. **WorkGraph**："今天并行开三个 worktree。"——生成 worktree map、内部分派与外派 prompt。
7. **执行**：内部 Worker 或外部 Agent 执行；TuringOS 记录通道内动作并观测 Git/PR。
8. **CI / Repair**：失败 → 修复 prompt 精准注入；重复失败 → 全局规则；触线 → 止损呈报。
9. **Merge Dossier**：可签名合并档案；批准或自治契约放行。
10. **离场与回归**：挂起批准不阻塞其余 worktree；回来时批准队列一次裁决。
11. **Morning Ritual**：Done / Staged / Needs Approval / Blocked / Failed，每项下钻到证据。

---

## 17. 对外定位

面向公众：

> **TuringOS is the Apple-native, protocol-native Agentic OS that lets AI work under your law.**

面向开发者：

> **TuringOS turns external models, tools, skills, and agents into Spec-bound, CI-aware, receipt-backed, human-signable state transitions.**

中文主张：

> **TuringOS 不是让 AI 更会说，而是让 AI 更敢做；不是把用户塞进软件，而是让软件围绕用户意图实时生成。**

---

## 18. 路线图

单梯递进；v0.5 的协议/能力/安全新层并入既有阶梯，不另起炉灶：

1. **alpha：Software 3.0 Shell** —— Dynamic Orb；Facilitator AI（本地 FM + API fallback + 降级模式）；Meta AI 配置；Generative 投影原型（View IR 雏形）；项目发现；Git 只读状态。
2. **beta：Project Ready** —— Init Spec；Retro-Init；预算与自治契约；凭证域声明；应用内批准（过渡形态）；WorkGraph 生成。
3. **M1：Execution Loop + Protocol Gateway** —— 内部 Worker；MCP client/server 网关；Model Gateway 三面适配（OpenAI-compatible / Responses / Anthropic Messages + Apple FM 本地）；Git-first 外部 agent 交接与再入观测；三类动作支路 + draft-by-default；GitHub PR/CI 观测；修复回路 + 止损护栏；Merge Dossier。
4. **M2：Kernel Receipt Loop + Capability Registry** —— ChainTape/回执 schema + 哈希链；provenance 分级；Predicate Gate；Failure Certificate；Morning Ritual；Touch ID + SE 签名升级；能力 manifest schema + 安装/升级/移除入带 + 初始 Skill 库（12 类）+ Skill eval harness。
5. **M3：Strategy Loop + Live Software 3.0** —— Project Stumps；portfolio search；Market observe-only；MCTS-lite 实验；FailureNode 聚类 → 候选 Skill/谓词提案流 → Veto + eval 激活；adapter 训练数据集导出（实训依 Part IV-3 运营税评估后再启动）。
6. **M4：首批外部集成 + Hostile Host 原型** —— 集成按接入面厚度排序：OpenClaw → Hermes → Claude Code → Codex（experimental 档），每个附边界卡（§14.3）；Canvas Projection（Excalidraw 底座）；外部 Sudo-Anchor PoC + Audit Anchor（Rekor 模式）+ no-audit-no-execution 不变量实验（§9.1 Tier 2）。

---

## 19. 不可谈判项

1. UI 不得退回传统菜单导航；界面必须是 tape 的派生投影（声明 derive_source、可重建）。
2. Facilitator AI 是长期角色，不是 setup helper。
3. Meta AI 必须尽早介入项目理解。
4. Init Spec 是所有项目的启动门槛；没有 Spec 的项目只能做 readiness task。
5. GitHub CI 是外部谓词，不是 TuringOS 要复制的功能。
6. Merge 需要 Merge Dossier，不接受"CI 绿了所以直接合"。
7. Veto-AI 只做违宪否决，输出域 {PASS, VETO}。
8. Market signal 不是真理。
9. 外部 Agent 产物必须标注 provenance level；partial provenance 不得纯谓词放行。
10. 不可逆动作 draft-by-default；批准卡写明类别与可逆性。
11. 所有关键状态必须可从 tape 重建；失败以 verified=false 入 tape。
12. 对 agent 诚实返回 staged / rejected 状态，不制造假事实。
13. tape、回执、批准历史本地优先，归用户所有，可导出可回放。
14. 修复回路必须有止损护栏；没有无界重试。
15. 并行 Worker 上下文相互隔离；原始失败日志不群发。
16. 谓词内部与评分细节对 Worker 屏蔽；主观判断走 RiskFinding，不冒充谓词。
17. 任何外部协议（MCP / A2A / UI 扩展 / 模型 API）不得绕过 ChainTape、Predicate Gate、动作分类、provenance 与签名路由。
18. 批准卡永远由第一方渲染器绘制；第三方 view 组件不得承载批准仪式。
19. 未声明或无法核验动作类的外部能力 fail-closed；Install ≠ trust，安装/升级/移除必须入带。
20. 模型与 adapter 的产物仅用于呈现与路由辅助，永不获得 Predicate Gate 权威；Live 回路的候选工件必须过 Veto + 留出 eval 才能激活。
21. 在 Tier 2 Sudo-Anchor 落地之前，不宣称任何 hostile-host（T3）级安全；威胁分级如实写在产品里。

---

## 20. 结语

TuringOS 的产品机会不是做一个更聪明的 Agent，而是做一个让 Agent 能被普通人真正托付的操作世界。

Software 1.0 让人点击功能。
Software 2.0 让人喂模型、筛输出。
**Software 3.0 让人立法，让 Agent 在法律下行动，让界面从状态中生成。**

> **从菜单到气泡；从页面到投影；从 prompt 到 Spec；从 auto mode 到 lawful auto mode；从 AI 输出到可签名状态变更。**
