# TuringOS Software 3.0 UI 工程 PRD

**版本** v0.1 · **日期** 2026-06-12  
**溯源** 白皮书 v0.5（WHITEPAPER.md line 1 已核）·
执行裁决 2026-06-12（下称"执行裁决"）·
contracts/ schema 集 · docs/ 政策集

> **本文档的唯一主题**：UI 是 Tape / Spec / Budget / Policy / Receipt 的**生成式派生投影**，
> 而不是功能页面集合。所有工程规格均从这一命题出发，逐条可追溯到白皮书条款、
> 宪法条文、ADR 裁决或执行裁决原文。

---

## 目录

1. UI 宪法
2. Dynamic Orb 规格
3. View IR v0 规格（核心）
4. 可发现性逃生机制
5. 降级模式
6. 既有 P1 壳的去向
7. 安全 UX
8. 验收 predicates

---

## 1. UI 宪法

### 1.1 禁令六条（白皮书 §6.1）

以下六条是**宪法级禁令**，违反即设计评审 FAIL，无例外。

| # | 禁令原文 | 白皮书出处 | 实现含义 |
|---|---|---|---|
| P1 | 禁止把左侧菜单栏作为主导航 | §6.1 | 任何左侧持久 nav panel 都是 P1 违规 |
| P2 | 禁止把无限 canvas 当作主交互形态 | §6.1 | Canvas 是只读输出通道，不是第一工作面 |
| P3 | 禁止把功能分区、页面、Tab 当作产品的第一组织原则 | §6.1 | 无固定 Tab bar，无固定顶部 menu |
| P4 | 第一入口必须是动态智能气泡 | §6.1 | Orb 是唯一第一屏；没有任何替代首页 |
| P5 | 用户诉求首先进入 Facilitator AI 或 Meta AI，而不是静态按钮 | §6.1 | 所有入口动作均经语言或 Orb 意图，不经固定按钮队列 |
| P6 | 系统回应不是切换页面，而是生成与当前任务相关的临时界面 | §6.1 | 界面是生成物，不是导航目标 |

### 1.2 三定律（白皮书 §6.4）

三定律约束注意通道行为，而非 Orb 视觉。

| 定律 | 含义 | 工程义务 |
|---|---|---|
| **注意力优先** | 需裁决的事（批准队列、止损报告、失败证书）置顶 | 待签 ApprovalEnvelope 在 Orb state=`needs-ruling` 中强视觉提示；不得被其他信息淹没 |
| **语言优先** | 用户意图首先以自然语言或语音进入，不是点击序列 | Orb 文字/语音双入口；语音转录不绕过 Facilitator，必须过 Facilitator 接收 |
| **安静即成功** | 一切进行中时，界面低调呼吸；无任务时近乎空 | Orb 在 idle 状态下保持最小占位；不主动弹出信息 push |

### 1.3 界面 = Tape/Spec/Budget/Policy/Receipt 的生成式投影

**执行裁决原文**：
> TuringOS 的界面不是功能入口，而是 Tape / Spec / Budget / Policy / Receipt 的生成式投影。

**工程转译**（依白皮书 §4.2 Tape Canonical / ADR-003）：

- 每个界面组件必须声明 `derive_source`：其数据来自 `chaintape` / `git` / `fixture_event_stream`。
- 每个投影必须满足守恒测试：`view == derive_from_tape(tape)`（执行裁决红线 5）。
- 界面不是独立数据源，不得存在"界面上可见但 tape 上无法推导"的事实。
- 生成式投影的宪法约束（白皮书 §6.3 约束条）：
  - 模型可以生成呈现层，但**不能生成放行逻辑**；放行只来自谓词、契约与签名。
  - 生成失败或模型不可用时，必须降级为确定性模板投影（见第 5 节）；呈现降级，事实不丢。

### 1.4 术语纪律（白皮书 §0 / §13.8）

本文档严格遵守三层术语，禁止混称：

| 层 | 术语 | 含义 |
|---|---|---|
| 底层白盒 | 工具 / 能力 | MCP 工具、Skill、Connector、`view_renderer`；可审计、有 manifest |
| 中间黑盒 | Agent | Meta AI、Worker AI、外部 Agent；内部推理不被信任，只信可验证行为结果 |
| 顶层白盒 | 谓词 / 管理 | Predicate Gate、Veto-AI、预算核查、签名路由；放行的唯一来源 |

---

## 2. Dynamic Orb 规格

### 2.1 第一屏定义

打开 TuringOS，用户看到的**唯一**第一屏是 Dynamic Orb。没有菜单栏、没有 project list 首页、没有仪表盘。

Orb 占据屏幕中央，背后由 Facilitator AI（本地 Apple Foundation Models 优先，降级见第 5 节）驱动。

### 2.2 状态机

Orb 有 5 个状态，构成完整状态机。状态转换由内核事件驱动，不由 UI 自行管理。

```
┌─────────────────────────────────────────────────────────────┐
│                      Orb 状态机                              │
│                                                              │
│  ┌─────────┐   语音/文字输入    ┌────────────┐              │
│  │  idle   │ ─────────────────► │ listening  │              │
│  └────┬────┘                    └─────┬──────┘              │
│       │                               │ Facilitator接收     │
│       │ 无任务 / 任务完成              ▼                     │
│       │                        ┌────────────┐               │
│       └────────────────────────│  thinking  │               │
│                                └─────┬──────┘               │
│                          Meta深化 /  │  批准请求             │
│                         谓词运行中   ▼                       │
│                                ┌──────────────┐             │
│                                │needs-ruling  │             │
│                                └─────┬────────┘             │
│                                      │ 用户裁决              │
│                                      ▼                       │
│  ┌──────────┐  模型/内核不可用  ┌────────────┐              │
│  │ degraded │ ◄──────────────── │  thinking  │              │
│  └──────────┘                   └────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

| 状态 | 触发条件 | 视觉语义 | 注意通道行为 |
|---|---|---|---|
| `idle` | 无挂起任务、无等待输入 | 最小占位，低调呼吸 | 安静。仅通知徽章在有批准队列时显示 |
| `listening` | 用户激活语音或文字输入 | 输入聚焦状态 | 无打扰 |
| `thinking` | Facilitator/Meta AI 处理中；Worker 执行中 | 活跃脉动（蓝色语义） | 低调；进行中任务的摘要可选展开 |
| `needs-ruling` | 有挂起的 ApprovalEnvelope；止损报告；失败证书需裁决 | 置顶强提示（按 VISUAL_SEMANTICS.md 规则） | 不打断其他 worktree；用户回来时一次性裁决批准队列 |
| `degraded` | Facilitator AI 不可用；内核异常 | 降级标注（gray 语义），确定性模板投影 | 状态说明文字直接呈现，不依赖模型生成 |

**色彩规则**：所有 Orb 状态色彩严格引用 `docs/VISUAL_SEMANTICS.md` 语义六色，Orb 本身不造新色。项目辨识色（V6 星系美学）只出现在身份表面，不出现在 Orb 状态 chrome。

### 2.3 语音与文字双入口

- **文字入口**：Orb 激活后出现内联文字输入框；回车或提交按钮发送；支持多行意图。
- **语音入口**：麦克风按钮激活后 Orb 进入 `listening` 状态；语音转录在本地完成（Apple FM）；转录结果交 Facilitator 接收，**不跳过 Facilitator 直接执行**。
- 两个入口均经 Facilitator 接收，Facilitator 决定是独立回应还是升交 Meta AI。

### 2.4 Facilitator 接住 → Meta 深化的切换表现

白皮书 §6.2 原文：
> 切换对用户不表现为"换页面"，而是对话深度和生成界面的变化。

工程规格：

- Facilitator 处理浅层意图（解释状态、引导配置、摘要输出）时，Orb 正常脉动，投影区域呈现 Facilitator 返回的 View IR。
- 当 Facilitator 判定需要 Meta AI（涉及 Git/ChainTape/Spec/Init/任务分解/策略判断时，白皮书 §5.1），**不换页**，而是 Orb 转为更深的 `thinking` 动效，投影区域扩展为 Meta AI 返回的 View IR（如 `spec_draft`、`worktree_map`、`budget_card` 等 block）。
- 角色切换在 View IR 的 `derive_source` 字段中体现（`meta_ai_session:xxx` vs `facilitator_session:xxx`），用户可在 Receipt Timeline 中下钻查看。
- **无"现在进入 Meta AI 模式"的弹窗或页面切换**。

---

## 3. View IR v0 规格

> **本节是本 PRD 的核心规格。**

### 3.1 设计原则与执行裁决红线

执行裁决红线 1（原文）：
> **No arbitrary JS. No arbitrary approval UI. No model-owned renderer.**
> 模型不得直接生成可执行 HTML / JS。模型只能生成 View IR。

三条红线的工程含义：

| 红线 | 含义 | 违反形态举例 |
|---|---|---|
| No arbitrary JS | 模型输出中不得含任何 `<script>` 或可执行 JS 片段 | 模型返回带 onclick handler 的 HTML |
| No arbitrary approval UI | 批准卡不得由模型生成；模型只能提供 `approval_request` block 引用 envelope | 模型直接输出"点击批准"按钮的 HTML |
| No model-owned renderer | 所有投影由第一方 renderer 根据 View IR 声明式渲染 | 外部 MCP App 返回的 HTML 被直接嵌入主窗口 |

### 3.2 View IR 文档结构

模型（Facilitator 或 Meta AI）产出的 View IR 是一个 JSON 对象，结构如下：

```json
{
  "schema_version": "tos.app.view_ir.v0",
  "kind": "<投影类型>",
  "derive_source": [
    "tape:<tape_seq_range>",
    "git:<commit_sha>",
    "github_check:<run_id>"
  ],
  "blocks": [
    {
      "type": "<block_type>",
      "<block 专属字段>": "..."
    }
  ]
}
```

**字段规则**：

| 字段 | 类型 | 规则 |
|---|---|---|
| `schema_version` | string | 固定为 `tos.app.view_ir.v0`；版本升级须走 ADR |
| `kind` | string | 见下表 `kind` 枚举；不得自造 |
| `derive_source` | string[] | 非空数组；每项格式为 `<来源类型>:<标识符>`；可溯源至 tape/git/fixture |
| `blocks` | object[] | 非空数组；每个 block 的 `type` 字段见本文 §3.3（白皮书 §6.3） |

**`kind` 枚举**（对应白皮书 §6.3 场景描述）：

| kind | 触发场景 |
|---|---|
| `project_init` | Boot 回路：初始化引导与权限说明 |
| `spec_authoring` | 回路 1：Init Spec 起草 |
| `budget_authoring` | 回路 1：预算与自治契约 |
| `execution_status` | 回路 2：执行中状态 |
| `ci_repair` | 回路 2：CI 失败修复 |
| `merge_dossier` | 回路 2：Merge Dossier 呈现 |
| `morning_ritual` | 注意通道：Morning Ritual |
| `capability_review` | 能力安装 / 升级审核 |
| `failure_report` | 止损报告 / 失败证书 |
| `general` | Facilitator 一般性回应 |

### 3.3 v0 Block 类型枚举

以下是 v0 全部合法 block 类型，每种 block 只能由对应的第一方 renderer 渲染。

#### `summary_card`

| 字段 | 类型 | 说明 |
|---|---|---|
| `title` | string | 卡片标题 |
| `body` | string | Markdown 纯文本，无嵌入 HTML |
| `tape_ref` | string? | 可选 tape seq 引用，用于下钻 |

#### `risk_list`

| 字段 | 类型 | 说明 |
|---|---|---|
| `items` | RiskItem[] | 每项含 `level`（info/warn/critical）、`text`、`risk_class` |
| `tape_ref` | string? | 可选引用 |

`level` 映射到 VISUAL_SEMANTICS.md 语义色：`info` → blue，`warn` → yellow，`critical` → red。

#### `approval_request`

| 字段 | 类型 | 说明 |
|---|---|---|
| `envelope_ref` | string | ApprovalEnvelope `envelope_id`；renderer 从内核读取 envelope 对象 |

**渲染铁律**：`approval_request` block **只能**由第一方 `ApprovalCard` 组件渲染。渲染时：
1. renderer 以 `envelope_ref` 从内核获取 `ApprovalEnvelope` 对象。
2. 渲染后对 `human_readable_summary` + `consequence_statement` + `reversibility` 的可见内容计算 SHA-256。
3. 计算结果必须与 `ApprovalEnvelope.visible_card_hash` 匹配（执行裁决红线 2；approval_envelope.schema.json 强制字段）。
4. 哈希不匹配时，**禁止呈现批准按钮**，显示 red 错误状态。

任何第三方 view renderer（MCP Apps adapter / A2UI adapter / AG-UI adapter）产出的 View IR 中，`approval_request` block 按原样传入第一方 `ApprovalCard`，**适配层不得替换此 block 的渲染逻辑**。

#### `diff_view`

| 字段 | 类型 | 说明 |
|---|---|---|
| `diff_ref` | string | 引用 git diff 或 tape 中的 diff 哈希 |
| `worktree_id` | string | 所属 worktree |
| `provenance` | enum | `FULL` / `REPO_LEVEL` / `PARTIAL` / `OUTSIDE_GOVERNANCE` |

`provenance` 的视觉标记规则见第 7.2 节。

#### `evidence_list`

| 字段 | 类型 | 说明 |
|---|---|---|
| `items` | EvidenceItem[] | 每项含 `kind`（`ci_check` / `predicate_result` / `model_call_ref` / `tape_node_ref`）、`label`、`ref` |

#### `project_picker`

| 字段 | 类型 | 说明 |
|---|---|---|
| `projects` | ProjectEntry[] | 每项含 `project_id`、`name`、`readiness`（ready / retro_init_needed / not_init）、`trust_state` |

`trust_state` 颜色渲染引用 `docs/TRUST_STATES.md` 唯一枚举。

#### `spec_draft`

| 字段 | 类型 | 说明 |
|---|---|---|
| `spec_ref` | string | tape 中 Spec 草案节点 ref |
| `sections` | SpecSection[] | 可编辑部分的引用列表；实际内容从 tape 读取 |
| `signature_node` | int | 预期签名节点编号（1 = Init Spec；如需重签同为 1） |

#### `budget_card`

| 字段 | 类型 | 说明 |
|---|---|---|
| `budget_ref` | string | tape 中预算对象 ref |
| `consumed` | object | `tokens` / `cost_usd` / `ci_cycles` / `wall_clock_s` 的已消耗量 |
| `limit` | object | 对应上限 |
| `signature_node` | int | 2（预算批准）|

#### `worktree_map`

| 字段 | 类型 | 说明 |
|---|---|---|
| `worktrees` | WorktreeEntry[] | 每项含 `worktree_id`、`head_sha`、`status`（running / halted / pending_approval / done）、`trust_state`、`provenance` |

#### `repair_prompt`

| 字段 | 类型 | 说明 |
|---|---|---|
| `failure_node_ref` | string | tape 中 FailureNode 的 ref |
| `suggested_prompt` | string | Meta AI 生成的修复 prompt，纯文本 |
| `target_worktree` | string | 精准注入目标 worktree（广播屏蔽：不群发，白皮书 §4.5 广播 II.1） |

#### `dossier_view`

| 字段 | 类型 | 说明 |
|---|---|---|
| `dossier_ref` | string | tape 中 MergeDossier 节点 ref |
| `risk_findings` | string[] | RiskFinding 清单 ref 列表（主观判断走独立通道，不冒充谓词，白皮书 §4.5 量化 I.1.1） |
| `provenance` | enum | `FULL` / `REPO_LEVEL` / `PARTIAL` / `OUTSIDE_GOVERNANCE` |
| `signature_node` | int | 5（批准合并/发布） |

#### `morning_ritual`

| 字段 | 类型 | 说明 |
|---|---|---|
| `date` | string | ISO 8601 日期 |
| `tape_range` | string | 归并的 tape seq 范围 |
| `buckets` | MorningBucket[] | 五栏：`done` / `staged` / `needs_approval` / `blocked` / `failed`；每项含计数与 ref 列表 |

归并算法是对 tape 的确定性 reduce，不是模型生成（白皮书 §7.5）。`morning_ritual` kind 的 View IR 的 `derive_source` 必须指向 tape。

#### `intent_suggestions`

| 字段 | 类型 | 说明 |
|---|---|---|
| `suggestions` | IntentSuggestion[] | 每项含 `label`（用户可见文字）、`intent_text`（发送给 Facilitator 的文字）、`context_tag`（当前状态的描述标签） |

`intent_suggestions` 是由当前内核状态生成的 intent surface（见第 4 节），不是静态菜单。

#### `credential_field`

| 字段 | 类型 | 说明 |
|---|---|---|
| `field_id` | string | 凭证域唯一标识 |
| `label` | string | 用户可见标签（不含凭证提示词） |
| `credential_scope` | string | 对应 `credential_scope_hash` 的域标识符 |

**渲染铁律**：`credential_field` 只能由 macOS 原生 `SecureField` 渲染（`isSecure=true`，截图 API 不可捕获）；任何把此 block 渲染为普通文本框的实现都是渲染器错误。明文凭证不得出现在 IR 文档中。

### 3.4 第三方 View IR 适配规则

外部生成的 UI 描述（MCP Apps 组件 / A2UI / AG-UI）先经 adapter 翻译为 Turing View IR，再由第一方 renderer 投影（白皮书 §6.6）。

| 规则 | 含义 |
|---|---|
| 适配在边缘，渲染权在内核 | Adapter 只做格式翻译；不得持有渲染逻辑 |
| 第三方 View IR 是不可信内容 | Adapter 输出的 IR 进入 renderer 前不享有额外信任 |
| `approval_request` block 不得来自第三方 | 第三方 IR 中如含批准语义，必须先升交内核生成 ApprovalEnvelope，再由内核产生 `approval_request` block |
| 第三方 IR 中的动作请求同等过门 | 动作分类、谓词、签名路由一个不少（白皮书 §6.6 铁律②） |

---

## 4. 可发现性逃生机制

**来源**：执行裁决工程标准 9（原文）：
> 解决方案不是左侧菜单，而是由当前状态生成的 intent surface。

### 4.1 五种逃生面

| 机制 | 触发方式 | 实现形态 |
|---|---|---|
| **Orb command suggestions** | Orb 激活时；idle 状态下的 hover | 以 `intent_suggestions` View IR block 渲染；每条 suggestion 点击后等同于用户在 Orb 文字框输入对应文字 |
| **Intent examples** | 首次启动；Orb 空闲时 | 3–5 条当前状态相关的示例意图，派生自内核状态（项目数量、挂起任务、Boot 进度） |
| **State cards** | 有挂起批准 / 活跃 worktree 时 | Orb 下方浮现状态摘要卡（View IR `execution_status` kind 的简化投影） |
| **Inspectable receipt timeline** | 用户明确请求"查看历史" | 触发 Replay 投影（`derive_source: chaintape`）；不是持久 sidebar |
| **Generated command palette overlay** | 用户快捷键触发（如 Cmd+K 或 Cmd+Space） | overlay 内容由 Facilitator 根据当前内核状态实时生成；不是预定义命令列表；结果以 `intent_suggestions` block 渲染 |

### 4.2 可发现性的三项约束

1. 以上五种逃生面都是 View IR 投影，声明 `derive_source`，不是独立 UI 状态。
2. 无任何一种逃生面等同于"传统菜单"：它们由当前状态生成，内容随状态变化，没有固定条目。
3. command palette overlay 的内容**不得**包含 `approval_request` block（批准不在 overlay 中触发）。

---

## 5. 降级模式

**来源**：白皮书 §6.3 约束条 / §7.1 节点 2C / §13.1 最后一条。

### 5.1 触发条件

| 条件 | 触发的降级级别 |
|---|---|
| Facilitator AI（Apple FM）不可用；设备不支持 Apple Intelligence | L1 降级：确定性模板 Facilitator |
| Facilitator AI 不可用且无 API key 配置 | L2 降级：纯确定性模板 + 手动 Init |
| View IR 生成失败（模型超时/解析错误） | L3 降级：该 block 替换为确定性模板 block |
| 内核/tape 读取异常 | L4 降级：`degraded` Orb 状态，呈现错误描述文本 |

### 5.2 降级规则

- **事实不丢**：降级只影响呈现层（View IR 的 `blocks`），不影响 tape 的完整性。tape 持续追加，不因 UI 降级而暂停。
- **降级明示**：所有降级状态下，Orb 处于 `degraded` 状态，视觉上以 gray（unknown/inferred 语义）标注，并呈现降级原因文本（确定性字符串，不由模型生成）。
- **确定性模板**：每个 `kind` 对应一个确定性模板 View IR，只含 `summary_card` block，内容来自 tape 的固定字段查询。模板不含 AI 生成内容。
- **批准仪式不降级**：降级模式下，挂起的 ApprovalEnvelope 仍完整呈现（由 `ApprovalCard` 组件渲染）；签名节点不因降级而跳过。

### 5.3 降级路径的验收要求

降级路径是验收 predicate 的一部分（见第 8 节 P2）：必须存在从 `degraded` 状态到确定性模板投影的完整代码路径，并有 fixture 测试覆盖。

---

## 6. 既有 P1 壳的去向

**来源**：白皮书 §6.4 / NAVIGATION_MODEL.md Global Ops 行 / 执行裁决批准的 UI 宪法。

### 6.1 菜单栏 glance

- **保留**，作为注意通道载体候选（白皮书 §6.4 原文："其具体物理载体（orb 脉动、系统通知、常驻微标）属 UI 设计轨"）。
- 定位：菜单栏图标 → Global Ops 投影（只读 Glance，NAVIGATION_MODEL.md 第一行）；零模态、零阻塞。
- 菜单栏**不是主导航**，不分发一般操作意图，不提供菜单项列表；它是批准队列/止损通知的快捷入口。
- Global Ops 投影的具体内容（一眼健康度：活跃会话/待审提案/待签仪式/异常）按 NAVIGATION_MODEL.md 定义，全部是 tape 派生。

### 6.2 galaxy radar（P1 内核调试面）

- **保留为内核调试面**，不作主导航。
- 可选展示 worktree 拓扑、tape 统计、provenance 分布，用于开发者与高级用户。
- 对普通用户默认不可见；V6 星系美学可作视觉参考，但 galaxy radar 的**具体视觉细节属用户设计稿域，最终视觉待用户 D5 审**。
- VISUAL_SEMANTICS.md 第 5–7 条（项目辨识色立法）对 galaxy radar 同样适用：辨识色只出现在身份表面，不出现在信任状态 chrome。

### 6.3 主导航的权威来源

NAVIGATION_MODEL.md 的十大主导航（Global Ops / Projects / Missions / Worktrees / Proposals / Identity / Ratification / Replay / Market Signals / Settings）是**内核调试面与高级视图**的入口，不是 Software 3.0 体验的第一路径。它们通过 Orb 意图或 command palette 访问，不通过持久 sidebar。

---

## 7. 安全 UX

### 7.1 Facilitator 不得接触密钥明文（执行裁决工程标准 6）

执行裁决原文：
> Facilitator AI 可以引导用户配置 API key，但输入框必须是 native secure field，密钥进 Keychain / Secure Enclave 保护域。Facilitator 不应该把 key 读进上下文。

**工程规格**：

- 凡涉及 API key / OAuth token / 其他凭证输入的 View IR block（`spec_draft` 中的凭证域、onboarding 阶段），必须以 `credential_field` 类型呈现，由 macOS native `SecureField` 组件渲染。
- `credential_field` block 不得含明文默认值；不得被截图 API 捕获（`isSecure = true`）。
- Facilitator AI 的上下文（model call prompt）**不得**包含凭证明文；凭证由 Keychain / SE 保护项注入运行环境，tape 记录 `credential_scope_hash`（白皮书 §9 / §13.7）。
- Onboarding View IR 的 `derive_source` 可包含 `facilitator_session:xxx`，但绝不包含凭证节点。

### 7.2 Partial Provenance 四级强视觉标记（执行裁决工程标准 3）

执行裁决原文：
> Merge Dossier 必须用强视觉标记：FULL provenance / REPO-LEVEL provenance / PARTIAL provenance / OUTSIDE GOVERNANCE

**四级枚举**（映射白皮书 §14.3 / §7.3 节点 21 注释）：

| 枚举值 | 含义 | 视觉形态 | 谓词门行为 |
|---|---|---|---|
| `FULL` | 动作经 TuringOS 通道，有动作级回执 | green badge "FULL" | 可纯谓词放行（需满足其余谓词） |
| `REPO_LEVEL` | 外部 Agent 经 git/PR 接入，有 repo 级 / PR 级回执 | blue badge "REPO-LEVEL" | 可纯谓词放行（需满足其余谓词） |
| `PARTIAL` | 外部 Agent 部分经通道；回执不完整 | yellow badge "PARTIAL" | **强制人工确认**（白皮书 §7.3 节点 21；不得纯谓词放行） |
| `OUTSIDE_GOVERNANCE` | 动作完全不经 TuringOS 通道 | red badge "OUTSIDE GOVERNANCE" | 强制人工确认；并显示边界卡提示 |

**强视觉标记要求**：
- `diff_view`、`dossier_view` block 必须在顶部显式渲染 provenance badge。
- badge 色彩引用 VISUAL_SEMANTICS.md 语义六色（green/blue/yellow/red），不得使用项目辨识色。
- badge 同时含图标 + 文本（VISUAL_SEMANTICS.md 规则 3：可达性 0/1 谓词覆盖）。
- `PARTIAL` / `OUTSIDE_GOVERNANCE` 时，badge 下方追加一行提示文字（确定性字符串）：
  - PARTIAL：「此变更来自通道外部，谓词门将要求人工确认。」
  - OUTSIDE_GOVERNANCE：「此变更不在 TuringOS 治理范围内。」

### 7.3 批准仪式安全

- 批准仪式只发生在 GUI 应用进程，**永不在后台 daemon 中**（白皮书 §9 / ADR-005）。
- `ApprovalCard` 组件必须渲染：动作类别（零/一/二/三类）、可逆性声明（`reversibility` 字段）、`human_readable_summary`、`consequence_statement`、签名级别（`required_signature_level`）。
- `visible_card_hash` 校验失败时，批准按钮置灰并显示 red 错误（「批准内容完整性校验失败」）。
- L4 动作触发 Full Ratification Ceremony（全注意力仪式屏），依 RATIFICATION_POLICY.md 规定，不在 View IR 的普通 block 流中进行。

---

## 8. 验收 Predicates（机械可判）

以下 8 项 predicate 全部输出域 {PASS, FAIL}，可由 CI 或脚本机械判定。

| # | Predicate | 判定方法 | FAIL 条件 |
|---|---|---|---|
| P1 | **每个 View IR 投影必须携带 `derive_source`** | grep `derive_source` in all rendered View IR JSON；assert non-empty array | 任何 View IR 对象缺少 `derive_source` 或值为空数组 |
| P2 | **Orb `degraded` 路径存在且可达** | fixture test：构造 Facilitator 不可用场景；assert Orb state == `degraded` && 确定性模板 block 渲染 | degraded 路径不存在或在 degraded 时仍调用模型 |
| P3 | **无传统菜单作为主入口** | UI test：assert 无持久 sidebar nav panel；assert 无固定 Tab bar；assert 首屏 = Orb | 有持久 sidebar 或 Tab bar 在 Orb 之外可见 |
| P4 | **`approval_request` block 渲染路径唯一** | static analysis：grep all `approval_request` render paths；assert count == 1（仅 `ApprovalCard`） | 存在 `approval_request` 的第二渲染路径（包括 MCP App adapter 直接渲染） |
| P5 | **`visible_card_hash` 校验逻辑存在** | unit test：构造 hash 不匹配的 envelope；assert 批准按钮不可点击 && red 错误显示 | 哈希不匹配时批准按钮仍可点击 |
| P6 | **Orb `needs-ruling` 状态在有挂起 ApprovalEnvelope 时触发** | integration test：创建 class 3 动作触发 envelope；assert Orb.state == `needs-ruling` | envelope 存在但 Orb 未进入 `needs-ruling` |
| P7 | **`PARTIAL` / `OUTSIDE_GOVERNANCE` provenance 触发人工确认路由** | integration test：提交 provenance=PARTIAL 的 WorkResult；assert approval prompt 出现（不允许纯谓词放行） | PARTIAL provenance 被纯谓词门放行，未出现人工确认 |
| P8 | **View IR 中不含可执行 JS** | static analysis + runtime test：assert all View IR payloads pass `no_script_tag` lint；assert renderer sandbox 阻止 script 执行 | View IR 中存在 `<script>` tag 或 `javascript:` URI |

---

## 附录 A：View IR Block 类型速查

| block type | 最小必需字段 | 典型 kind |
|---|---|---|
| `summary_card` | `title`, `body` | 所有 |
| `risk_list` | `items` | `merge_dossier`, `failure_report` |
| `approval_request` | `envelope_ref` | `merge_dossier`, `execution_status` |
| `diff_view` | `diff_ref`, `worktree_id`, `provenance` | `merge_dossier`, `ci_repair` |
| `evidence_list` | `items` | `merge_dossier`, `failure_report` |
| `project_picker` | `projects` | `project_init` |
| `spec_draft` | `spec_ref`, `signature_node` | `spec_authoring` |
| `budget_card` | `budget_ref`, `consumed`, `limit`, `signature_node` | `budget_authoring` |
| `worktree_map` | `worktrees` | `execution_status` |
| `repair_prompt` | `failure_node_ref`, `suggested_prompt`, `target_worktree` | `ci_repair` |
| `dossier_view` | `dossier_ref`, `provenance`, `signature_node` | `merge_dossier` |
| `morning_ritual` | `date`, `tape_range`, `buckets` | `morning_ritual` |
| `intent_suggestions` | `suggestions` | `general`, `execution_status` |
| `credential_field` | `field_id`, `label`, `credential_scope` | `spec_authoring`, `general` |

## 附录 B：本文档规范溯源索引

| 规则编号 | 溯源 |
|---|---|
| 禁令 P1–P6 | 白皮书 §6.1 |
| 三定律 | 白皮书 §6.4 |
| 界面 = 派生投影 | 白皮书 §4.2 Tape Canonical；ADR-003；执行裁决二§2 |
| View IR 红线 1（No arbitrary JS） | 执行裁决三§红线 1 |
| `visible_card_hash` 入签名负载 | 白皮书 §9；approval_envelope.schema.json；执行裁决三§红线 2 |
| Partial provenance 强视觉标记 | 执行裁决四§3；白皮书 §7.3 节点 21 |
| 可发现性逃生机制 | 执行裁决四§9 |
| 降级为确定性模板 | 白皮书 §6.3 约束条；§7.1 节点 2C；§13.1 |
| Facilitator 不接触密钥 | 执行裁决四§6；白皮书 §9；§13.7 |
| ApprovalCard 唯一渲染路径 | 白皮书 §6.6 铁律①；执行裁决三§红线 1 |
| 注意通道三定律 | 白皮书 §6.4 |
| 语义六色唯一 | docs/VISUAL_SEMANTICS.md |
| Trust state 唯一枚举 | docs/TRUST_STATES.md |
| Provenance 分级 | 白皮书 §14.3；§7.3 节点 21 |
| L4 仪式屏 | docs/RATIFICATION_POLICY.md |
| 菜单栏 glance 定义 | docs/NAVIGATION_MODEL.md Global Ops 行 |
| V6 星系美学参考 | docs/VISUAL_SEMANTICS.md §项目辨识色通道；用户记忆 feedback_turingos_ui_aesthetic.md |
