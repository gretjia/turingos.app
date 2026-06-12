# 01_KERNEL_CONTRACTS — 内核契约脊梁

> **repo law 第一支柱的工程视图 · Sprint 0 核心交付物**
>
> 本文档是 `contracts/` 目录的工程解释层。Schema 文件本身是机器法律，本文件是人读注释与不变量台账。两者冲突时以 schema 为准（`contracts/README.md` 演进规则 5）。

---

## 1. 目的与地位

### 1.1 为什么先做契约

2026-06-12 执行裁决（以下简称"执行裁决"）的一句话定论：

> **批准 v0.5 进入执行；先做能从 tape 重建的最小 Agentic OS 心跳，不做大而全生态。**

裁决把 Sprint 0 定名为 **Schema-first Kernel Spine**，验收目标是：

```
fixtures pass / hash chain pass / derive_from_tape(view) pass / invalid capability fail-closed
```

这 13 个 schema 文件，就是 Sprint 0 交付的"可从 tape 重建的不可让渡主权"的全部形式表达。在写第一行 Swift 或 Rust 之前，所有事件形态、动作类、签名节点、投影规则、能力声明一律由本目录钉死。

### 1.2 在 repo law 体系中的位置

TuringOS repo 有三条法律支柱：

| 支柱 | 载体 | 优先级 |
|---|---|---|
| **第一支柱 · 机器契约** | `contracts/*.schema.json` + 本文档 | 最高（schema 胜出） |
| **第二支柱 · 宪法** | `constitution/constitution.md`（只读，hook 拒绝写入） | 与第一支柱同源，条款级别高于实现 |
| **第三支柱 · 执行门禁** | `scripts/shipgate.sh` + CI | 自动机械执行第一/第二支柱的谓词 |

`contracts/` 是第一支柱的物理形态。`docs/RATIFICATION_POLICY.md`、`docs/UPSTREAM_CONTRACT.md`、`ADR.md` 等是它的解释层，但在任何冲突中以 schema 为准。

### 1.3 Sprint 0 的工程视图

执行裁决明确 Sprint 0 只交付 **8 个核心 schema**（当时列表），本仓实际落地 **13 个 schema**，覆盖 Sprint 0 全部需求并为后续 Sprint 预留了合并门禁与失败状态的机器约束。本文档对 13 个 schema 一一索引、阐释不变量、详解 ApprovalEnvelope、并以机械命令形式给出 Sprint 0 验收 predicate。

---

## 2. Schema 索引

`contracts/` 目录当前包含 **13 个 schema**。每个 schema 对应一类在内核中流动的事实对象。下表"版本 ID"与 schema 文件中 `$id` 字段精确对应；"消费方"指在运行时直接读取或校验该 schema 实例的组件。

| # | 文件 | 版本 ID | 一句话锚定 | 消费方 |
|---|---|---|---|---|
| 1 | `event_stream.schema.json` | `tos.app.event.v0` | 一切进入 tape→投影管道的事件信封；每行一条 JSONL | daemon（写）/ app（读投影） |
| 2 | `typed_actions.schema.json` | `tos.app.action.v0` | 全部合法用户动作及其 L0–L4 级别；action_kind↔level 配对是法律 | app / gateway（动作路由） |
| 3 | `projection.schema.json` | `tos.app.projection.v0` | 投影三件套强制（derive_source / schema_version / rebuild_command）；无此三件不得存在任何派生视图 | app / daemon（投影读写） |
| 4 | `signature_receipt.schema.json` | `tos.app.receipt.v0` | 验签回执；verified=false 也是合法回执——失败即状态，不得隐藏 | daemon（验签）/ app（展示） |
| 5 | `ratification_payload.schema.json` | `tos.app.ratification.v0` | L4 宪法动作 canonical payload；无此结构的批准不叫 ratification | app（L4 仪式屏）/ shipgate #8 |
| 6 | `predicate_result.schema.json` | `tos.app.predicate.v0` | verdict 锁死 {PASS,FAIL}；RiskFinding 独立通道，永不携带 verdict | daemon（谓词门）/ CI |
| 7 | `tape_node.schema.json` | `tos.app.tape_node.v0` | Shell 侧 tape 条目信封；canonical ChainTape 语义在 runtime 上游（UPSTREAM_CONTRACT.md rule 2），本文件 **不重实现** | daemon / app（读 tape 切片） |
| 8 | `approval_envelope.schema.json` | `tos.app.approval_envelope.v0` | 泛化 ratification_payload.v0 至签名节点 #1–#8；visible_card_hash 绑定"用户所见"入签名负载；Tier-2 字段保留（v0.x 写 null/T0-T2） | app（签名仪式）/ daemon（验签） |
| 9 | `capability_manifest.schema.json` | `tos.app.capability_manifest.v0` | 工具/技能/连接器/模型/adapter 能力声明；fail-closed：缺失 action_classes 按 class_3 处理；vendor_tier verified = 身份证明非质量背书 | app（Registry）/ daemon（gate） |
| 10 | `work_order_package.schema.json` | `tos.app.work_order_package.v0` | 发往执行 agent 的完整调度包：规格引用、范围 allowlist、验收谓词、预算切片、prompt；无 allowed_files/forbidden_files 则 harness 必须拒绝 | daemon / 外部 agent 接口 |
| 11 | `model_call.schema.json` | `tos.app.model_call.v0` | Model Gateway 底层白盒管道记录；每次调用入 tape；脱敏即如实标注 replay_degraded=true | daemon（Gateway 日志）/ app（成本追踪） |
| 12 | `failure_node.schema.json` | `tos.app.failure_node.v0` | 失败即状态（Art. 0.2）；verified 固定为 false；nearest_failed_predicate 命名触发的 PASS/FAIL 门 | daemon（HALT 路径）/ app（失败证书） |
| 13 | `merge_dossier.schema.json` | `tos.app.merge_dossier.v0` | 合并门禁证据包；CI 绿是外部谓词之一非全部；risk_findings 为主观 RiskFinding 通道，不携带 verdict | daemon（合并路由）/ shipgate #4 |

> **校验机制**：`scripts/validate_contracts.sh`（python3 stdlib 结构校验：type / required / enum / const / pattern）在 shipgate #2–#4/#8 触发。校验器是 JSON-Schema Draft 2020-12 的严格子集（不解析 `$ref`/`allOf`），schema 编写保持在该子集内；Rust serde+schemars 的完整校验在 daemon 落地时接管。输出注明 `structural-subset`，不冒充完整 Draft 2020-12。

---

## 3. 内核不变量

以下九条不变量是 TuringOS Kernel 的物理骨架。每条都必须在 fixtures / CI / shipgate 中有对应的机械判据；主观合规评估不构成不变量验证。

### I1 — Append-Only Tape + Hash Chain

**规则**：ChainTape 只追加，不删改。每个 TapeNode 携带 `prev_node_hash`（前序节点哈希）与 `node_hash`（当前节点内容哈希），形成可验证哈希链。Genesis 节点的 `prev_node_hash` 为约定的零哈希。启动时验链，篡改可检测。

**来源**：WHITEPAPER.md §4.2 / 宪法 Art. 0.2 / Art. 0.3

**机械判据**：`tape_node.schema.json` 的 `prev_node_hash` 与 `node_hash` 两字段 required，格式 `^sha256:[0-9a-f]{8,64}$`；验链脚本 exit-0 = PASS，exit-nonzero = FAIL。

### I2 — ∏p=1 是唯一状态前进路径；Meta/Worker 输出只是候选

**规则**：

```
Meta AI output  = proposal   （规划建议，不触发写入）
Worker output   = candidate  （执行产物，不触发写入）
Kernel decision = 唯一状态迁移来源（∏p=1 时 wtool 提交 Q_{t+1}，否则 Q_t 不变）
```

任何直接绕过 Predicate Gate（谓词积）的写入均非法。谓词积中任意一项 FAIL 则 ∏p=0，Q 不前进，失败以 `verified=false` 入 tape。

**来源**：执行裁决"红线 4"；WHITEPAPER.md §8 Kernel 图；宪法 Art. 0.4

**机械判据**：`predicate_result.schema.json` verdict 枚举锁死 `["PASS","FAIL"]`；shipgate #4 校验所有 predicate_result fixture 的 verdict 合规性。

### I3 — 投影守恒：view == derive_from_tape(tape)；三件套强制

**规则**：所有派生视图（UI 状态、缓存、索引、生成式界面投影）均须满足：

```
view == derive_from_tape(tape)
```

每个 `Projection` 实例必须包含三个强制字段：
- `derive_source`：声明推导来源（`chaintape` / `git` / `fixture_event_stream`）
- `schema_version`：版本可溯
- `rebuild_command`：给定 tape 可机械重建

没有三件套的投影不得存在。Software 3.0 的生成式界面是 tape 的派生投影，受同一纪律约束。

**来源**：ADR-003；WHITEPAPER.md §4.2；执行裁决"红线 5"；`projection.schema.json` required 字段

**机械判据**：`scripts/validate_contracts.sh` 校验所有 projection fixtures 的三件套出现；守恒测试 `derive_from_tape(fixture_tape) == fixture_projection` exit-0 = PASS。

### I4 — 未声明动作类 Fail-Closed

**规则**：凡 `capability_manifest` 中 `action_classes.default` 缺失、无效或无法核验，系统必须将该能力按 `class_3_irreversible_external`（不可逆外部）处置或直接拒绝安装启用。不允许静默降至更低权限默认值。

**来源**：执行裁决"不批准立刻做完整 Skill Library"；WHITEPAPER.md §13.8；`capability_manifest.schema.json` description

**机械判据**：fixtures 中包含 `action_classes` 缺失的能力清单，校验脚本对其返回 `deny` 决定（exit-0 = PASS）；schema required 字段校验 exit-0 = PASS。

### I5 — Partial Provenance 不得纯谓词放行

**规则**：标注 `provenance_requirement: partial_with_human_confirm` 的候选不允许仅经谓词积自动放行合并。`merge_dossier.provenance_level` 为 `PARTIAL` 或 `OUTSIDE_GOVERNANCE` 时，合并路由必须升格至签名 #5（`approval_route: signature_5`）；使用 `approval_route: autonomy_contract` 则 `provenance_level` 必须为 `FULL` 或 `REPO_LEVEL`。

**来源**：WHITEPAPER.md §7.3 节点 21（"partial provenance → 强制人工确认"）；§19 不可谈判项第 9 条；`merge_dossier.schema.json` `provenance_level` × `approval_route` 交叉约束

**机械判据**：fixtures 中包含 partial provenance + autonomy_contract 的合并包，校验脚本返回 FAIL（exit-nonzero）；FULL + autonomy_contract 的合并包返回 PASS（exit-0）。

### I6 — 批准卡第一方渲染；visible_card_hash 入签名负载

**规则**：任何批准仪式（签名节点 #1–#8）的批准卡必须由 TuringOS 第一方渲染器绘制。第三方 view 组件不得承载批准仪式。`ApprovalEnvelope.visible_card_hash` 是"用户实际所见内容"的规范化哈希，是 required 字段，进入被签名的负载。一张从未向用户展示过的卡无法产生合法的 `visible_card_hash`。

**来源**：执行裁决"红线 2"；WHITEPAPER.md §6.6（"批准卡永远由第一方渲染器绘制"）；§9（"批准卡内容哈希入签名负载"）；`approval_envelope.schema.json` required 字段

**机械判据**：`approval_envelope.schema.json` 的 `visible_card_hash` 出现在 required 列表中，格式 `^sha256:[0-9a-f]{8,64}$`；fixture 缺失该字段则 schema 校验 FAIL。

### I7 — Veto-AI v0 = Rule Engine First；输出域 {PASS,VETO}

**规则**：Veto-AI 的职责是违宪否决，输出域仅有 `{PASS, VETO}`。v0 实现必须以确定性规则引擎（ConstitutionRuleSet / PolicyRuleSet / CapabilityRuleSet / ActionClassRuleSet / ProjectionRuleSet）先行；LLM 仅作"模糊案件解释器"，不得成为唯一裁决器。Veto-AI 不做代码质量、性能、可读性、测试覆盖率等主观评判——那些属于 RiskFinding 通道。

**来源**：执行裁决"红线 3"；WHITEPAPER.md §5.4；`predicate_result.schema.json` verdict 枚举；宪法 Art. V.1.3

**机械判据**：`predicate_result.schema.json` verdict 枚举值仅 `["PASS","FAIL"]`（VETO 在外层流程层面不是 predicate 字段）；Veto 路径对应 FAIL verdict + reject_class；无 "MAYBE"/"ADVISORY"/"WARN" 等中间值。

### I8 — ModelCall 全部入带；脱敏即标注 replay_degraded

**规则**：Model Gateway 是底层白盒管道，不存在未记录的模型流量。每次模型调用产生一个 `ModelCall` 节点入 tape，记录 provider / model / role / cost / latency / token_usage / policy / project_id。用户启用隐私脱敏时，内容替换为哈希（`privacy_mode: redacted`），此时 `replay_degraded` 必须为 `true`——如实声明该段无法全量回放，不假装仍可重建完整上下文。

**来源**：执行裁决接受标准 5（"ModelCall 必须入 tape"）；WHITEPAPER.md §13.7；`model_call.schema.json` description 及 required 字段

**机械判据**：`model_call.schema.json` 的 `replay_degraded` 出现在 required 列表；fixture 中 `privacy_mode=redacted` 且 `replay_degraded=false` 的实例校验 FAIL（由 CI 或 P0 校验器强制）。

### I9 — 凭证永不入带/入 Prompt；tape 只记 scope hash

**规则**：API key、OAuth token 等凭证存储于 Keychain / Secure Enclave 保护域，由运行时在执行面注入，不得出现在：(a) tape 任何节点的 payload 内，(b) 传入模型的 prompt 中，(c) `WorkOrderPackage.prompt` 字段中。tape 记录的是 `credential_scope_hash`（凭证范围哈希），而不是凭证本身。

**来源**：执行裁决接受标准 6（"Facilitator AI 不能接触密钥明文"）；WHITEPAPER.md §7.2（"凭证从不入带、从不入 prompt"）；§13.7（"凭证存 Keychain/SE 保护项；tape 只记 credential_scope_hash"）；TapeNode `kind=credential_scope_ratified` 语义

**机械判据**：tape fixture 扫描脚本检测 payload 中是否出现已知凭证格式模式（bearer token / API key 正则）；命中则 FAIL；工具：`scripts/check_tape_no_secrets.sh`（Sprint 0 待实现，属验收 predicate 之一）。

---

## 4. ApprovalEnvelope 详解

`approval_envelope.schema.json`（版本 ID：`tos.app.approval_envelope.v0`）是签名节点的核心数据结构，将签名 #1–#8 的所有批准仪式统一到同一 schema 下。

### 4.1 字段语义表

| 字段 | 类型 | 语义 |
|---|---|---|
| `schema_version` | const | 锁定为 `tos.app.approval_envelope.v0`；版本升级必须 bump ID |
| `envelope_id` | string | 批准包唯一标识符 |
| `signature_node` | enum 1–8 | 对应白皮书 §9 的八个签名节点（1=Init Spec / 2=预算 / 3=凭证域 / 4=不可逆动作 / 5=保护写入 / 6=超预算扩展 / 7=工具策略升级 / 8=修宪） |
| `action_class` | enum 0–4 | 动作分类，与 L0–L4 动作级别对应 |
| `actor` | string | 发起批准的主体（agent ID 或 human root） |
| `project_id` | string | 所属项目标识 |
| `spec_hash` | sha256 string | 批准时生效的 Spec 内容哈希；绑定"基于哪份法律批准的" |
| `budget_hash` | sha256 string | 批准时生效的预算合约哈希 |
| `policy_hash` | sha256 string | 批准时生效的策略哈希 |
| `payload_hash` | sha256 string | 被批准的动作载体（如 WorkOrderPackage、Spec 文本）的哈希 |
| `visible_card_hash` | sha256 string | **用户实际所见批准卡内容的规范化哈希**（I6 关键字段；SE 签字节不证明所见，此字段补全"所见"绑定） |
| `human_readable_summary` | string | 仪式屏的人读摘要，宪法义务（L4 的 `ratification_payload` 同要求）；非 UI 装饰 |
| `consequence_statement` | string | 后果声明：本次批准将产生什么不可逆效果 |
| `reversibility` | enum | `reversible` / `draft` / `irreversible`；批准卡上必须可见 |
| `target_resource_hash` | sha256 string | 被操作目标资源的哈希（文件、PR、外部系统记录等） |
| `expiry_utc` | ISO 8601 | 批准有效期（过期不得执行） |
| `nonce` | string | 随机数，提供重放抵抗（THREAT_MODEL T4） |
| `prev_tape_head` | sha256 string | 批准时的 tape 头哈希，绑定签名到链上特定时刻 |
| `required_signature_level` | enum | `app_approval` / `touch_id_se` / `external_anchor`；声明本次需要什么级别的认证 |
| `host_threat_level` | enum T0–T3 | 批准时评估的宿主威胁级别（见 I6 / Hostile Host 模型） |
| `external_anchor_id` | string（可选） | T3 级别时必填；外部 Sudo-Anchor 的锚点标识 |
| `audit_root` | string（可选） | 外部审计链（Tier-2 路线图字段）的根哈希 |

### 4.2 Tier-2 预留槽语义（v0.x 处理方式）

`host_threat_level`、`external_anchor_id`、`audit_root` 三字段是 Hostile Host 安全模型（WHITEPAPER.md §9.1）的 **Tier-2** 预留槽。执行裁决明确：

> v0.x 只需要预留这三个字段，不要现在做硬件、外部审计链、Rekor-style anchor 的完整实现。

**v0.x 写法规范**：

| 字段 | v0.x 写法 | 何时触发非空 |
|---|---|---|
| `host_threat_level` | 必须出现，值写 `"T0"` 到 `"T2"`（取决于场景评估） | T3 为路线图远期，v0.x 不触发 |
| `external_anchor_id` | 留空（不出现或写 null）| 仅当 `host_threat_level: "T3"` 且 Tier-2 实现完成后非空 |
| `audit_root` | 留空（不出现或写 null） | 同上 |

schema 允许 `external_anchor_id` 和 `audit_root` 为可选字段，且在 `host_threat_level: "T3"` 时 `external_anchor_id` 语义上 required（"T3 requires external_anchor_id to be present before any irreversible action class proceeds"，见 schema description）。v0.x 实现不暴露 T3 路径，任何 T3 场景在 v0.x 阶段应触发 HALT 并通知用户。

---

## 5. 演进规则

本节直接引用 `contracts/README.md`，不复述。完整规则见该文件的"演进规则"小节（5 条），摘要如下：

1. 每个实例必须带 `schema_version`（如 `tos.app.event.v0`）。
2. 加字段 = 向后兼容，可在同版本内进行。
3. 删字段 / 改语义 / 改枚举值 = breaking，必须 bump 版本并保留旧 schema 供 replay 旧链（ADR-007：不改判历史）。
4. 枚举扩值 = minor，但 fixtures 必须同 PR 补覆盖。
5. schema 与人读文档冲突时，以 schema 为准并立即修文档。

> 完整权威文本：`contracts/README.md`。

---

## 6. Sprint 0 验收 Predicate 清单

以下四条是 Sprint 0 的机械验收判据，对应执行裁决"Sprint 0 验收"。每条给出判定命令与 PASS/FAIL 条件。均为 **A 级判据**（可程序验证，ground truth 唯一）。

### P1 — Fixtures PASS（schema 合规性）

**目标**：`fixtures/` 下所有合法实例文件通过 structural-subset 校验。

**命令**：

```bash
bash scripts/validate_contracts.sh
```

**判定**：exit-0 且输出 `[PASS]` = **PASS**；exit-nonzero 或任意 `[FAIL]` = **FAIL**。

**补充**：校验器注明 `structural-subset`；不冒充完整 Draft 2020-12 校验结果。

### P2 — Hash Chain PASS（tape 哈希链完整性）

**目标**：给定 fixture tape 文件，逐节点验证 `prev_node_hash` 指向前序节点 `node_hash`，链不断裂。

**命令**（待实现脚本，Sprint 0 交付）：

```bash
python3 scripts/verify_tape_chain.py fixtures/sample_tape.jsonl
```

**判定**：exit-0 = **PASS**；链断裂或哈希不符 exit-nonzero = **FAIL**。

**说明**：Genesis 节点的 `prev_node_hash` 约定为全零哈希（`sha256:0000...`），视为链头合法。

### P3 — derive_from_tape PASS（投影守恒）

**目标**：给定 fixture tape 与对应 projection fixture，验证投影可从 tape 重建且与 fixture 一致。

**命令**（待实现脚本，Sprint 0 交付）：

```bash
python3 scripts/check_projection_invariant.py \
  --tape fixtures/sample_tape.jsonl \
  --projection fixtures/sample_projection.json
```

**判定**：exit-0 表示 `derive_from_tape(tape) == projection` = **PASS**；不一致或三件套缺失 exit-nonzero = **FAIL**。

### P4 — Invalid Capability Fail-Closed（缺失动作类拒绝）

**目标**：`action_classes` 缺失或 `action_classes.default` 无效的能力清单实例，系统返回 `deny` 决定而非降权通过。

**命令**：

```bash
python3 scripts/validate_contracts.py \
  fixtures/invalid_capability_no_action_class.json \
  contracts/capability_manifest.schema.json
```

**判定**：校验器返回结构错误（exit-nonzero）= **PASS**（即该实例无法通过校验，fail-closed 生效）；exit-0 表示校验通过 = **FAIL**（不可接受）。

---

*文档版本：2026-06-12 · Sprint 0 · 作者：TuringOS Execution Agent*
*对应 WHITEPAPER.md v0.5 · 执行裁决 2026-06-12*
