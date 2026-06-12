# 04_ALPHA_EXECUTION_PLAN — TuringOS Alpha 落地计划

**版本** v0.1 · **起草日期** 2026-06-12 · **授权依据** 用户执行裁决 2026-06-12（以下简称"裁决文"）  
**方向冻结件** WHITEPAPER.md v0.5（第 1 行确认版本号）  
**机器契约** `contracts/*.schema.json` · **政策** `docs/RATIFICATION_POLICY.md`

> 本文件是裁决文明确要求的四份工程文件之一（01_KERNEL_CONTRACTS / 02_SOFTWARE_3_UI_PRD / 03_OPERATING_FLOW_ACCEPTANCE_TESTS / **04_ALPHA_EXECUTION_PLAN**）。所有规范性陈述可溯源至白皮书章节、宪法条款（Art.）或裁决文节（裁决文 §）。

---

## 1. 裁决范围

### 1.1 批准项

用户 2026-06-12 裁决批准 **v0.5 作为方向冻结件**，进入以下模式执行：

> **批准 v0.5 进入执行；先做能从 tape 重建的最小 Agentic OS 心跳，不做大而全生态。**

具体批准内容（引自裁决文 §一）：

| 批准项 | 依据 |
|---|---|
| v0.5 产品定位：Apple-native × protocol-native personal Agentic OS | 裁决文 §1；白皮书 §0 |
| Software 3.0 作为 UI 宪法（禁止退回菜单导航，第一入口=动态气泡） | 裁决文 §2；白皮书 §6 |
| Operating Flow v4 四回路：Boot → 立法 → 执行 → Meta + 注意通道 | 裁决文 §3；白皮书 §7 |
| GitHub 继续作执行场，TuringOS 作治理场（PR/CI/merge 在 GitHub） | 裁决文 §4；白皮书 §4.3 |
| 外部 Agent 诚实边界：只治理经由 Turing 通道的动作 | 裁决文 §5；白皮书 §3.1 / §14 |

### 1.2 缓行项

以下模块**暂缓执行**，违反即视为 scope creep（门禁红）：

| 缓行项 | 当前允许范围 | 依据 |
|---|---|---|
| **完整 Market**（Token 经济/拍卖/队列排序） | observe-only 统计记录（tape 确定性聚合） | 裁决文 §二-1；白皮书 §12 |
| **完整自动 MCTS** | 手动策略分支 + Portfolio Radar（observe） | 裁决文 §二-1；白皮书 §11 |
| **完整 Skill Library**（>2-3 个内置 official skills） | Capability Manifest schema 先行；2-3 官方内置 skill | 裁决文 §二-2；白皮书 §13.8-13.9 |
| **Tier-2 Sudo-Anchor 硬件**（外部批准设备/Audit Anchor） | `approval_envelope` 中保留槽位 `external_anchor_id / host_threat_level`，v0.x 写 null/T0-T2 | 裁决文 §二-3；白皮书 §9.1 |
| **外部 Agent 深度定制集成**（逐家深适配） | Capability Manifest schema 完备后再开放 | 裁决文 §三-8；白皮书 §13.6 |

### 1.3 五条红线（原文收录）

以下五条为执行铁律，任何实现不得绕行：

**红线 1：View IR 优先，禁止任意 Generative HTML/JS**

> 模型不得直接生成可执行 HTML / JS。模型只能生成 View IR。

```json
{
  "kind": "merge_dossier",
  "derive_source": ["tape:...", "github_check:..."],
  "blocks": [
    {"type": "summary_card", "content_ref": "..."},
    {"type": "risk_list", "items_ref": "..."},
    {"type": "approval_request", "envelope_ref": "..."}
  ]
}
```

然后由 TuringOS 第一方 renderer 渲染。**No arbitrary JS. No arbitrary approval UI. No model-owned renderer.**
（依据：裁决文 §三-红线1；白皮书 §6.6）

**红线 2：ApprovalEnvelope 先于 Touch ID UI**

> 先定义签名负载，再做批准动效。

字段清单以 `contracts/approval_envelope.schema.json` 的 required 数组为准（当前 20 个必填字段）：`schema_version / envelope_id / signature_node / action_class / actor / project_id / spec_hash / budget_hash / policy_hash / payload_hash / visible_card_hash / human_readable_summary / consequence_statement / reversibility / target_resource_hash / expiry_utc / nonce / prev_tape_head / required_signature_level / host_threat_level`。
（依据：裁决文 §三-红线2；白皮书 §9；RATIFICATION_POLICY.md）

**红线 3：Veto-AI v0 必须先是 rule engine**

> v0 正确实现 = `ConstitutionRuleSet + PolicyRuleSet + CapabilityRuleSet + ActionClassRuleSet + ProjectionRuleSet`。

LLM 只能作为"模糊案件解释器"，不能成为唯一裁决器。Veto-AI 的外部逻辑输出域为 {PASS, VETO}；在 predicate 管道中，VETO 映射为 verdict='FAIL' + reject_class（见 docs/01_KERNEL_CONTRACTS.md I7；contracts/predicate_result.schema.json 的 verdict 枚举为 {PASS,FAIL}，不含 VETO）。（依据：裁决文 §三-红线3；白皮书 §5.4）

**红线 4：Meta AI 无写权限**

> Meta AI output = proposal；Worker output = candidate；Kernel decision = 唯一状态迁移源。

Meta AI 只能规划/解释/生成 WorkGraph/生成 Merge Dossier，不能直接推进 Q。只有 `∏p=1` 时 wtool 才提交 Q_{t+1}。
（依据：裁决文 §三-红线4；白皮书 §8；宪法 Art. IV）

**红线 5：所有投影必须能重建**

> `view == derive_from_tape(tape)` 必须有守恒测试覆盖。

每个投影声明 `derive_source / schema_version / rebuild_command`（`contracts/projection.schema.json` 强制）。
（依据：裁决文 §三-红线5；白皮书 §4.2；ADR-003）

---

## 2. Sprint → Atom 分解表

### 总览时间线

```
Sprint 0 (当前) → Sprint 1 → Sprint 2 → Sprint 3
A1_14           → A1_15~17 → A1_18~19 → A1_20~22
Schemas + Docs    Orb+Meta    Project    CI 闭环
                  Setup       Ready
```

---

### Sprint 0 · Schema-first Kernel Spine（当前卡）

**目标**：无漂亮 UI，先把不可让渡主权的机器契约固化。

| Atom | A1_14 |
|---|---|
| **Intent** | 交付全套 kernel schema + 文档工程骨架，为后续所有 Sprint 锁死契约 |
| **Allowlist** | `contracts/*.schema.json` / `contracts/README.md` / `docs/RATIFICATION_POLICY.md` / `docs/UPSTREAM_CONTRACT.md` / `docs/PROJECTION_POLICY.md` / `docs/TRUST_STATES.md` / `docs/VISUAL_SEMANTICS.md` / `docs/NAVIGATION_MODEL.md` / `docs/04_ALPHA_EXECUTION_PLAN.md` / `fixtures/**` / `scripts/validate_contracts.sh` / `scripts/shipgate.sh` |
| **验收 predicate** | `scripts/shipgate.sh p0` 全绿（structural-subset 校验 pass）；`fixtures/` 每个 schema 至少一条合法 fixture 通过；`derive_from_tape` 守恒测试 pass（或明确桩点存在）；04_ALPHA_EXECUTION_PLAN.md 存在且包含五条红线原文 |
| **依赖** | 无（本卡是起点） |

---

### Sprint 1 · Orb + Facilitator + Meta 配置

**目标**：第一个 Software 3.0 入口；用户能用自然语言启动系统；所有投影可重建。

---

#### A1_15 — View IR Renderer + 确定性模板投影

| 字段 | 内容 |
|---|---|
| **Intent** | 实现 Turing View IR 结构 + 第一方 renderer；确定性模板降级路径就位 |
| **Allowlist** | `Sources/TuringOS/UI/ViewIR/` 下全部新文件；`Sources/TuringOS/UI/Renderer/` 下全部新文件；`contracts/projection.schema.json`（只读引用）；`fixtures/view_ir/` |
| **验收 predicate** | 给定合法 View IR JSON → renderer 输出正确 SwiftUI 视图（快照测试 PASS）；给定非法/空 View IR → 降级为确定性模板（不崩溃，PASS）；`view_ir.derive_source` 字段不存在时 → 渲染失败并返回错误（FAIL 分支 PASS）；任意生成 JS/HTML 路径不存在（grep 断言 PASS） |
| **依赖** | A1_14（`projection.schema.json` 已固化） |

---

#### A1_16 — Orb Shell + Facilitator Runtime 检测 + Secure Key 入库 + Meta 配置

| 字段 | 内容 |
|---|---|
| **Intent** | Dynamic Orb UI 骨架就位；Facilitator AI 本地/API runtime 检测与切换；API key 经 native secure field 进 Keychain（Facilitator 上下文不接触 key 明文）；Meta AI 连接与配置 |
| **Allowlist** | `Sources/TuringOS/UI/Orb/` 下全部新文件；`Sources/TuringOS/Runtime/Facilitator/` 下全部新文件；`Sources/TuringOS/Runtime/Meta/` 下全部新文件；`Sources/TuringOS/Security/KeychainManager.swift`；`docs/CLI_ABI.md`（只读） |
| **验收 predicate** | 启动应用 → 第一屏为 Orb 而非菜单（UI snapshot PASS）；Facilitator runtime = 本地 Apple Foundation Models（若可用）或 API 密钥路径（可配置，PASS）；API key 输入框为 `SecureField`，key 写入 Keychain 后进程内存不可 dump 到明文（audit log PASS）；Meta AI 配置完成后 `meta_ai_configured=true` 写入 tape（tape fixture PASS）；传统菜单导航不存在（grep 断言 PASS） |
| **依赖** | A1_15（renderer 就位） |

---

#### A1_17 — 项目发现 + Git 只读状态投影

| 字段 | 内容 |
|---|---|
| **Intent** | 从本地 Git 仓库发现项目；读取只读 Git 状态（HEAD/branch/dirty/CI 链接）；生成 Project Ready draft 投影（View IR 形态，derive_source 指向 tape） |
| **Allowlist** | `Sources/TuringOS/Runtime/GitObserver/` 下全部新文件；`Sources/TuringOS/Projection/ProjectDraftProjection.swift`；`fixtures/projections/` |
| **验收 predicate** | 给定一个本地 Git 仓库路径 → 返回 `{head_sha, branch, is_dirty, remote_url}` 结构（unit test PASS）；Project Ready draft 投影 JSON 通过 `projection.schema.json` 校验（PASS）；`projection.derive_source` 包含 tape node ref（PASS）；`derive_from_tape(projection) == projection`（守恒测试 PASS）；不执行任何写入 Git 操作（audit PASS） |
| **依赖** | A1_16（tape 已激活） |

---

**Sprint 1 GPT 验收标准**（见 §3）：
- 用户能用自然语言完成 Meta AI 配置（Facilitator 对话流，无传统表单必填序列）
- 能选择一个 Git repo（项目发现正常）
- 投影可重建（`derive_from_tape` 测试全绿）
- 无传统菜单作为主入口（第一屏是 Orb）

---

### Sprint 2 · Project Ready

**目标**：真正启动一个项目；建立 Spec-first 立法回路；预算与批准契约就位。

---

#### A1_18 — Init/Retro-Init Spec Package + 验收谓词

| 字段 | 内容 |
|---|---|
| **Intent** | New Init 流程（新项目立法）与 Retro-Init 流程（已有项目补 Genesis）；Spec Package = 目标/非目标/DoD/验收谓词/数据边界/工具权限/风险；签名 #1 触发 |
| **Allowlist** | `Sources/TuringOS/Runtime/Init/` 下全部新文件；`Sources/TuringOS/Runtime/Spec/` 下全部新文件；`contracts/approval_envelope.schema.json`（只读引用）；`contracts/ratification_payload.schema.json`（只读引用）；`fixtures/init/` |
| **验收 predicate** | 新项目走 New Init → Spec Package JSON 完整（含 `spec_hash`/`definition_of_done`/`acceptance_predicates`/`data_scope`/`git_head_anchor`）（schema 校验 PASS）；已有项目走 Retro-Init → 生成 `tape_genesis_node`（tape fixture PASS）；签名 #1 → `ApprovalEnvelope.signature_node=1` 写入 tape（PASS）；无 Spec Package 则拒绝分派普通任务（unit test PASS，返回错误码） |
| **依赖** | A1_17（Git 观测就位）；A1_16（tape 已激活） |

---

#### A1_19 — 预算契约 + Approval #1/#2 应用内批准 + Tape Genesis

| 字段 | 内容 |
|---|---|
| **Intent** | 预算 + 自治契约（money/tokens/wall-clock/tool calls/CI cycles/审阅负担/外派/止损线）；签名 #2 触发；`tape_genesis_node` 确认写入；项目状态从 Not Ready → Ready |
| **Allowlist** | `Sources/TuringOS/Runtime/Budget/` 下全部新文件；`Sources/TuringOS/Runtime/Tape/GenesisWriter.swift`；`fixtures/budget/`；`fixtures/tape/` |
| **验收 predicate** | 预算契约 JSON 通过 `approval_envelope.schema.json` 校验（`signature_node=2`）（PASS）；`tape_genesis_node.schema_version` 合法且哈希链 prev 指向初始锚（PASS）；项目状态字段 `project_ready=true` 可从 tape 派生（PASS）；Spec 修订 → 自动要求重签 #1（unit test PASS）；预算修订 → 自动要求重签 #2（unit test PASS） |
| **依赖** | A1_18（Spec Package 就位） |

---

**Sprint 2 GPT 验收标准**（见 §3）：
- 项目能从 Not Ready → Ready（完整立法回路）
- 无 Spec Package 不允许分派普通任务
- Spec 修订会重签 #1，预算修订会重签 #2

---

### Sprint 3 · CI 闭环

**目标**：第一条完整执行-谓词闭环；CI 失败不产出 slop；CI 绿不直接合并；Merge Dossier 可追溯。

---

#### A1_20 — WorkOrderPackage 派发 + Branch/PR 检测

| 字段 | 内容 |
|---|---|
| **Intent** | 生成并派发 `WorkOrderPackage`（spec_ref/worktree_scope/allowed_files/forbidden_files/objective/expected_outputs/acceptance_predicates/budget_slice/provenance_requirement/prompt）；轮询 git remote 发现新分支/PR；标注 provenance 等级 |
| **Allowlist** | `Sources/TuringOS/Runtime/Dispatch/` 下全部新文件；`contracts/work_order_package.schema.json`（只读引用）；`Sources/TuringOS/Runtime/GitObserver/PRDetector.swift`；`fixtures/work_orders/` |
| **验收 predicate** | `WorkOrderPackage` JSON 通过 schema 校验（PASS）；外部 agent 产物 via git remote → 标注 `provenance=partial`（unit test PASS）；内部 Worker 产物 → 标注 `provenance=full`（unit test PASS）；派发不含凭证明文（grep 断言 PASS） |
| **依赖** | A1_19（Project Ready 就位） |

---

#### A1_21 — CI Import + Repair Prompt + 止损

| 字段 | 内容 |
|---|---|
| **Intent** | 导入 GitHub CI check result（含 `workflow_file_hash/check_run_ids/commit_sha`）；CI 失败 → Meta AI 生成精准修复 prompt（注入本 worktree，不群发）；止损护栏（重试计数/CI 预算/token 预算）；HALT-止损进注意通道 |
| **Allowlist** | `Sources/TuringOS/Runtime/CI/` 下全部新文件；`contracts/failure_node.schema.json`（只读引用）；`Sources/TuringOS/Runtime/AttentionChannel/` 下全部新文件；`fixtures/ci/` |
| **验收 predicate** | CI 失败 → `FailureNode` JSON 写入 tape（schema 校验 PASS）；修复 prompt 包含 `worktree_scope` 限定（unit test PASS）；重复失败 ≥ N 次 → 触发 HALT-止损（N 由预算契约定义，unit test PASS）；CI Merge Dossier 包含 `workflow_file_hash`（PASS）；原始日志不群发到其他 worktree（audit PASS） |
| **依赖** | A1_20（WorkOrderPackage 就位）；A1_19（预算契约提供止损线） |

---

#### A1_22 — Predicate Gate + Merge Dossier + Morning Ritual

| 字段 | 内容 |
|---|---|
| **Intent** | Turing Predicate Gate（∏p：Spec 符合/DoD/diff 范围/预算合规/回执完整/数据边界/provenance 阈值/Veto-AI PASS）；CI 绿后生成 Merge Dossier；partial provenance 强制进注意通道（签名 #5）；Morning Ritual（tape reduce：Done/Staged/NeedsApproval/Blocked/Failed） |
| **Allowlist** | `Sources/TuringOS/Runtime/PredicateGate/` 下全部新文件；`Sources/TuringOS/Runtime/MergeDossier/` 下全部新文件；`contracts/merge_dossier.schema.json`（只读引用）；`contracts/predicate_result.schema.json`（只读引用）；`Sources/TuringOS/Runtime/MorningRitual/` 下全部新文件；`fixtures/predicate/`；`fixtures/dossier/` |
| **验收 predicate** | `∏p=0` 时 Q 不前进，`FailureNode` 入 tape（PASS）；`∏p=1` 且 provenance=full → 生成 Merge Dossier（schema 校验 PASS）；provenance=partial → 路由至签名 #5（unit test PASS，不允许纯谓词放行）；Veto-AI rule engine：ConstitutionRuleSet 给定违宪输入输出 VETO（unit test PASS）；Morning Ritual 输出 5 栏结构（Done/Staged/NeedsApproval/Blocked/Failed）且可从 tape 派生（守恒测试 PASS）；CI green 不直接触发合并，必须过 Predicate Gate（integration test PASS） |
| **依赖** | A1_21（CI Import 就位）；A1_19（预算契约）；A1_15（View IR Renderer，用于 Dossier 投影） |

---

**Sprint 3 GPT 验收标准**（见 §3）：
- CI fail 不交付 slop（修复 prompt 精准注入，不直接重跑）
- CI green 不直接合并（必须过 Predicate Gate）
- Merge Dossier 可追溯（含 `workflow_file_hash/derive_source`）
- partial provenance 强制人工确认（签名 #5 不可绕过）
- `Q_{t+1}` 仅在谓词全 PASS 后前进

---

## 3. 每 Sprint GPT 验收标准对照

> GPT 验收标准是补充性用户体验级检查，**不替代机械 predicate**。主观感受走 RiskFinding 通道，不冒充谓词（白皮书 §4.5 量化 I.1.1；`contracts/predicate_result.schema.json`）。

### Sprint 0 验收标准（A1_14）

| 检查项 | 判断方式 |
|---|---|
| 所有 schema 通过 `validate_contracts.sh` | exit code 0 |
| 每个 schema 有对应 fixture | `fixtures/` 目录结构断言 |
| `shipgate.sh p0` 全绿 | exit code 0 |
| 04_ALPHA_EXECUTION_PLAN.md 包含五条红线原文 | grep 断言 |

### Sprint 1 验收标准（A1_15~17）

| 检查项 | 判断方式 |
|---|---|
| 用户用自然语言完成 Meta AI 配置，无传统表单强制序列 | 可观察交互流（Facilitator 对话） |
| 能选择一个 Git repo，显示 head/branch/状态 | UI snapshot |
| 生成 Project Ready draft 投影，`derive_from_tape` 守恒测试绿 | 自动化测试 exit 0 |
| 第一屏是 Orb，无传统左侧导航菜单 | UI snapshot + grep |
| API key 不出现在 app 进程可读内存（除 Keychain 注入路径） | audit log 断言 |

### Sprint 2 验收标准（A1_18~19）

| 检查项 | 判断方式 |
|---|---|
| 新项目 New Init → 项目状态 = Ready | tape 字段断言 |
| 已有项目 Retro-Init → `tape_genesis_node` 写入 | tape 字段断言 |
| 无 Spec Package → 分派普通任务返回错误 | unit test exit 0 |
| Spec 修订 → 系统要求重签 #1 | unit test exit 0 |
| 预算修订 → 系统要求重签 #2 | unit test exit 0 |

### Sprint 3 验收标准（A1_20~22）

| 检查项 | 判断方式 |
|---|---|
| CI fail → 不产出 slop（生成修复 prompt，不直接重提交） | integration test |
| CI green → 不直接合并（必须过 Predicate Gate） | integration test |
| Merge Dossier 含 `workflow_file_hash / derive_source` | schema 校验 |
| partial provenance → 强制路由至签名 #5（人工确认） | unit test |
| `Q_{t+1}` 仅 `∏p=1` 后前进 | tape 状态断言 |
| Morning Ritual 5 栏可从 tape 派生 | 守恒测试 exit 0 |

---

## 4. 待用户裁决项

以下 4 项尚无裁决，**在用户给出裁决前，对应 atom 不得开工**。

### 4.1 Tier-2 锚形态

**问题**：Tier-2 外部 Sudo-Anchor（独立显示设备/Audit Anchor/Rekor 模式）何时从 envelope 预留槽进入实际实现？

**影响 atom**：A1_22（Predicate Gate 的 `host_threat_level=T3` 分支）；后续签名 #4/#5 的 T3 路径；任何依赖 `external_anchor_id` 字段的实现。

**当前状态**：`approval_envelope.schema.json` 已预留 `external_anchor_id / host_threat_level`，v0.x 写 null/T0-T2。硬件实现不在 Alpha 范围内（裁决文 §二-3）。

### 4.2 A2A 入站

**问题**：外部 Agent 通过 A2A 协议主动发起任务请求时（入站方向），TuringOS 如何处理身份验证、预算切片授权与 provenance 标注？

**影响 atom**：A1_20（WorkOrderPackage 派发）的入站变体；Capability Registry 的 A2A adapter；任何 `provenance=a2a_inbound` 处理路径。

**当前状态**：A1_20 只实现出站（TuringOS 派发给外部），入站路径留桩（返回 `NOT_IMPLEMENTED`）。

### 4.3 Registry 托管

**问题**：Capability Registry 是纯本地（用户自管 manifest）还是引入云端托管索引（类 npm registry），以支持社区 skill 发现？

**影响 atom**：Skill Library 的后续 atom（在缓行列表中）；`capability_manifest.schema.json` 的 `vendor_tier` 字段语义；Install/Update/Remove 入 tape 的实现细节。

**当前状态**：仅本地 manifest 路径。云端托管是缓行项（裁决文 §二-2）。

### 4.4 Adapter 实训时机

**问题**：Live Software 3.0 的 `observe → cluster → suggest` 流程何时从 suggestion-only 升级为可自动激活（需要 eval harness + 回滚机制就绪）？

**影响 atom**：回路 3 Meta 架构演化（白皮书 §7.4）的自动激活路径；ArchitectAI 提案的自动落盘条件；Skill Library 的 eval harness。

**当前状态**：第一阶段锁死 suggestion-only，不得自动激活（裁决文 §三-7）。升级条件由用户另行裁决。

---

## 5. 风险与止损

### 5.1 Token 预算窗口

- 预算重置周期：**每周日 15:00**。
- 每颗 atom 开工前评估 token 消耗预估，不超过单次会话上限。
- 超预算触发：停止当前 atom，记录 `HALT-预算` 状态到 tape，下次会话续做（`--resume` 从最近 checkpoint 恢复）。

### 5.2 Atom 推进纪律

- **每颗 atom shipgate 全绿才进下一颗**。shipgate FAIL 的原文上报，不粉饰、不合并到下一颗继续做。
- Atom 范围不得扩张（allowlist 即边界）。需扩范围时修改 Atom 卡并留痕，不绕过 allowlist。
- 每颗 atom 完成后执行：`scripts/shipgate.sh p0` → 全绿 → 回执落盘（`/atom-ship`）。

### 5.3 失败上报

- 门禁 FAIL → 原文上报（reject_class + 最近失败谓词 + 修复建议）写入 tape。
- 不做"这次 FAIL 无所谓，下颗补上"的粉饰。宪法义务：**报忧不报喜**（AGENTS.md 铁律 #6）。
- 触线止损时人类在注意通道裁决：修法（回路 1）/ 换路 / 关闭。

### 5.4 外部事实核验

- 任何涉及 Apple API/框架/GitHub API 的外部事实：先 WebFetch 实证，结论 + verified_on 日期写入 Atom 卡 `verified_external_facts`，再开工。
- 禁止基于记忆猜测 API 行为（AGENTS.md 铁律 #5 / MEMORY 反教训）。

---

## 6. 不做清单（明确防 scope creep）

以下内容在 Alpha 全程**不做**，任何实现迹象视为 scope creep，门禁拦截：

| 不做项 | 原因 |
|---|---|
| **技能市场 UI**（浏览/评分/发现界面） | 供应链攻击面；先做 Capability Manifest schema（裁决文 §二-2） |
| **市场经济结算**（Token 发行/拍卖/队列自动排序） | M3 前不实现真正市场经济（裁决文 §二-1；白皮书 §12） |
| **MCTS 自动化**（reward 驱动的自动策略分支） | 先做手动策略树 + observe-only（裁决文 §二-1；白皮书 §11） |
| **Tier-2 硬件锚**（独立批准设备/Rekor Audit Anchor） | 仅保留 envelope 预留槽（裁决文 §二-3；白皮书 §9.1） |
| **逐家 Agent 深度适配**（Codex/Claude Code/Kimi/Grok 专属深集成） | 先做 Capability Manifest；没有 Registry 任何工具都是黑盒泥浆（裁决文 §三-8） |
| **任意 Generative HTML/JS 渲染** | 红线 1；只允许 View IR + 第一方 renderer（裁决文 §三-红线1） |
| **传统左侧导航菜单** | Software 3.0 宪法；第一入口必须是 Orb（白皮书 §6.1；裁决文 §2） |
| **Skill Library > 2-3 个内置 official skills** | 先走 Capability Manifest + 完整 eval harness（裁决文 §二-2） |

---

## 附录 A：Atom 依赖关系图

```
A1_14 (Sprint 0)
  └─ A1_15 (View IR Renderer)
       └─ A1_16 (Orb + Facilitator + Meta)
            └─ A1_17 (Git 观测 + 项目投影)
                 └─ A1_18 (Init/Retro-Init Spec)
                      └─ A1_19 (预算契约 + Project Ready)
                           └─ A1_20 (WorkOrderPackage 派发)
                                └─ A1_21 (CI Import + 止损)
                                     └─ A1_22 (Predicate Gate + Merge Dossier)
```

所有依赖为强依赖（前置 atom 未 shipgate 全绿则后续 atom 不得开工）。

---

## 附录 B：术语纪律（防混称）

依白皮书 §4.2 术语纪律（v0.5 新增），本文件严格遵守三层语义：

| 术语 | 定义 | 禁止混称 |
|---|---|---|
| **底层白盒（工具/能力）** | Capability Registry 中带 manifest 的工具/连接器/技能——可审计对象 | 不得称为"agent"；不得混入顶层白盒 |
| **中间黑盒（agent）** | Meta AI / Worker AI / 外部 Agent——提议候选，系统只信可验证行为结果 | 不得称为"工具"；不得称为"白盒" |
| **顶层白盒（谓词/管理）** | Predicate Gate / Veto-AI / 预算检查 / provenance 阈值——状态迁移的唯一授权者 | 不得称为"agent"；不得降格为配置项 |

---

*本文件由执行 agent (claude-sonnet-4-6) 起草，依据 WHITEPAPER.md v0.5（第 1 行确认版本号）、用户裁决文 2026-06-12、contracts/*.schema.json、docs/RATIFICATION_POLICY.md 综合撰写。所有规范性陈述均已标注依据来源。外部事实（Apple API / GitHub API）未在本文件内引入新断言，凡有外部事实引用处已指向 FEASIBILITY.md。*
