# R_v06_directive — 白皮书 v0.6「Two-Scale Sovereign Kernel Correction」终裁指令（审计规范）

> **状态**：用户（首席架构师）2026-06-15 终裁 + Veto-AI `【PASS】零违宪全票核准`（`[VETO-AI VERDICT_SIGNATURE: APPROVED_AND_ENFORCED]`）。
> **角色**：本文件是 atom `A1_14_whitepaper_v06` 的**审计规范**——白皮书 v0.6 surgical edit 的逐节清单与递归审计的 12 条不变量均以本文为准。drift = 偏离本文。
> **授权**：`/goal 智慧得使用 workflow，loop 的组合，完成白皮书的修订，并且使用 recursive audit 防止 drift`（ADR-012 自主执行权 / 仓库 /goal 惯例）。
> **范围**：Phase A（只改 WHITEPAPER.md + 本归档 + ADR-019 + 递归审计装置）。Phase B（契约包）/ Phase C（实现重排）各自后置、走 ratification，**不在本卡**。

本文件逐字归档用户终裁指令与 Veto-AI 审计报告。下文「最高结论 / Blocker / Major / 图间契约骨架 / 逐节清单 / 执行计划 / 12 条不变量 / 最终建议」即审计 ground truth。

---

## 一、最高结论：v0.6 必须以"两尺度模型"为主骨重写

白皮书应立即确立两个互不等同的尺度：

**Micro scale：TuringOS 内部 ChainTape。**
这是反奥利奥内核自己的 canonical tape。一次内核 tick / 一次 agent proposal / 一次 predicate 判定，都应形成一个内部 tape node。失败也入带，携带 `verified=false` 与 `reject_class`。这来自宪法 Art. 0.1 与 0.2：wtool 是 append-only 写入口，失败提案也必须以 node 形态进入 tape；Tape Canonical 要求 cost、provenance、rejection feedback、search history 等信号都能从 tape 重建。

**Macro scale：用户项目 Git / GitHub / PR / CI / merge。**
这是外部执行场与交付晶体。GitHub 可以继续负责 PR、CI、branch protection、merge commit；TuringOS 继续观察 PR/SHA/diff、把 CI 作为外部谓词、生成 Merge Dossier、决定是否让 Spec 下的世界状态前进。白皮书目前已有这一产品定位，但把它误接到了 `HEAD_t` 与 `wtool` 上。

因此，白皮书 v0.6 应把核心定理写成：

> **Internal ChainTape is the sovereign micro-ledger. GitHub is the external macro execution substrate. A GitHub commit/PR/merge is not a ChainTape node; it is a macro artifact crystallized from many micro nodes and then anchored back into ChainTape as provenance.**

这句话一旦成立，§4.3 和 §8 的大部分错误都会自然收敛。

---

## 二、Blocker 级违宪点与修正建议

### B1 · §4.3 把 `HEAD_t` 绑定到 GitHub merge SHA，是根本尺度错配

白皮书 §4.3 现在写：`HEAD_t` 是 "git HEAD / merge commit SHA 锚点"，`wtool` 是 "tape 追加 + git commit/merge，仅 ∏p=1 放行"，并且解释 GitHub PR/CI/merge 与 TuringOS 治理场共同构成 Art. 0.4 路径 B。这正是错误核心。

宪法 Art. 0.4 说 `Q_t = ⟨q_t, HEAD_t, tape_t⟩` 是 version-controlled 状态，`HEAD_t` 是路径指针，`tape_t` 是文件底物，`rtool/wtool` 显式以三元组为输入输出。宪法路径 B 的"真 git 版"也写得很清楚：**每 cell run 用 runtime 临时 git repo；Node = commit object；bus.append = git commit；HEAD_t = git HEAD ref**。这不是用户项目仓库，不是 GitHub PR，不是 merge commit。它是 TuringOS 内部微观 ChainTape 的实现底物。

**修正：§4.3 的映射表应改为：**

| 宪法元素 | v0.6 产品落位 |
| --- | --- |
| `q_t` | 内核会话/搜索状态：WorkGraph cursor、pending approvals、stop-loss counters、routing state；必须可从 ChainTape 重建 |
| `tape_t` | **Internal Micro ChainTape / CAS**：TuringOS 自己的 append-only canonical ledger |
| `HEAD_t` | **internal accepted-world pointer**，指向内部 ChainTape 上最后一个通过 predicate product 并被接受为当前世界状态的节点；不得等同于 GitHub merge SHA |
| `tape_tip` / `log_tip` | 内部 ChainTape 最新 append 节点；失败节点也推进此游标，但不推进 accepted-world `HEAD_t` |
| `project_git_head` | 用户项目工作树/分支/PR/merge SHA，属于 macro execution substrate；只能作为 provenance 或 macro artifact anchor 入 tape |
| `rtool` | 从 internal ChainTape + accepted head + project git observations + CI evidence 装配最小充分上下文 |
| `wtool` | `bus.append()`：只写 internal ChainTape；不能直接等同 GitHub commit/merge |
| `macro_commit/PR/merge` | 由多个 micro nodes 晶出的外部交付产物；其 SHA 写入某个 ChainTape node 的 `kind_payload` / provenance |

这里额外引入两个游标：`tape_tip` 与 `accepted_head`。这是为了消解宪法文本中的一个容易误读点：失败必须入 tape，但 `∏p=0` 时 `Q_t` 不前进。正确解释应是**append log 前进，accepted world head 不前进**。这不需要改宪法，只需要白皮书把产品语义讲清楚。

### B2 · §4.1 / §4.3 / §8 把 tape append 放到 `∏p=1` 分支下，颠倒了 Rubber 不变量

白皮书 §4.1 的 Pencil 行写"tape 追加 + git commit/merge；仅 ∏p=1 时世界状态前进"，§4.3 的 `wtool` 行又写"tape 追加 + git commit/merge，仅 ∏p=1 放行"。这会让实现者误以为失败时不 append。§8 内核图也写："if ∏p = 1: wtool 提交 Q_{t+1}（tape 追加 + HEAD 前移）；if ∏p = 0: Q_t 不变，失败以 verified=false 入 tape"。这两句内部冲突：既然失败要入 tape，tape append 就不能只发生在 `∏p=1` 分支。

**正确模型：**

```text
Every micro tick:
    node = bus.append(output, predicate_result, verified, reject_class, provenance, cost, parent_hashes)
If Πp_micro = 1:
    accepted_head may advance to node
    node.verified = true
Else:
    accepted_head does not advance
    node.verified = false
    node.reject_class is mandatory
```

也就是说：
* **append 是无条件的。**
* **verified 是谓词结果。**
* **accepted world advance 是有条件的。**
* **GitHub merge 是更高一层 macro action，不是 micro append。**

### B3 · §8 状态方程漏掉了"签名/自治契约"这个宏观放行门

§8 现在把核心状态方程写成 `if ∏p = 1: wtool 提交 Q_{t+1}` / `if ∏p = 0: Q_t 不变`。但 §7.3 自己已经有更完整的执行流：CI 绿后进入 Predicate Gate，`∏p=1` 后生成 Merge Dossier，再进入"批准路由"；低风险且契约允许才能 GitHub merge，保护面/高爆炸半径/partial provenance 要签名 #5。这说明 `∏p=1` 在 macro merge 层只是必要条件，不是充分条件。

**修正后的 §8 应拆成两条方程：**

```text
Micro Tick:
    node = bus.append(output, Πp_micro, verified, reject_class, provenance)
    accepted_head advances iff Πp_micro = 1
Macro Boundary:
    macro_candidate = crystallize(micro_trace → commit/PR/MergeDossier)
    macro_merge_allowed iff:
        Πp_macro = 1
        AND budget/stop-loss/provenance gates pass
        AND (autonomy_contract_allows OR human_signature_valid)
```

这样可以一次修掉三个问题：尺度混淆、Rubber 颠倒、签名漏门。

### B4 · 多个 flow chart 缺少"图间连接契约"，会让实现 agent 在接缝处撕裂

白皮书 §7 已经把流程拆成 Boot、立法、执行、Meta、注意通道，图面上很强；但现在每张图只说明本图内部流程，没有定义跨图边界的**类型化对象**。这些箭头如果没有 schema，就会被不同实现 agent 各自解释，造成"交叉地带撕裂"。

**建议新增一节：`§7.0.1 Flowchart Interface Contract`。** 这一节不讲产品愿景，只讲硬接口：

```text
所有 flow chart 之间只能通过 ChainTape event 过缝。
禁止通过 UI local state、agent memory、parallel cache、GitHub side effect 直接过缝。
每条跨图箭头必须声明：
    source_loop
    target_loop
    event_type
    canonical_payload_schema
    required_hashes
    approval_binding
    replay_command / derive_rule
```

建议最少定义 12 类过缝事件：

| 接缝 | 事件类型 | 必要字段 |
| --- | --- | --- |
| Boot → Project Portfolio | `SystemConstitutionAccepted` | constitution_hash, user_consent_hash, runtime_capability_digest |
| Boot → Legislation | `ProjectDiscovered` | repo_locator, observed_git_head, project_fingerprint |
| Legislation → Execution | `ProjectReady` | init_spec_hash, budget_contract_hash, credential_scope_hashes, predicate_pack_hash |
| Legislation amendment → Execution | `ProjectLawAmended` | previous_law_hash, new_law_hash, signature_id |
| Execution → Attention | `SignatureRequested` | action_kind, approval_card_hash, expiry, route |
| Attention → Execution | `SignedDecision` | request_hash, decision, signature, signer_key_id |
| Execution → Meta | `ArchitectureGapObserved` | reject_class_cluster_hash, missing_tool/predicate/schema |
| Meta → Execution | `WhiteboxArtifactActivated` | artifact_hash, veto_result, eval_result, signature_if_required |
| Execution → Legislation | `ScopeChangeRequested` | diff_from_spec, reason, suggested_amendment |
| Execution → Legislation | `BudgetExhausted` | budget_line, consumed, forecast, stop_loss_certificate |
| Execution → Macro Git | `MacroArtifactProposed` | micro_trace_hash, diff_hash, PR_url/SHA, provenance_level |
| Macro Git → Execution | `MacroObservationImported` | CI_status, logs_digest, merge_sha, branch_protection_state |

这就是把"图"变成"协议"。

### B5 · 签名对象与谓词对象必须逐字节同哈希，否则批准会变成装饰

白皮书 §9 已经有一条很正确的原则：SE 签的是字节，不能证明用户看到了什么；所以批准卡内容的规范化哈希必须纳入签名负载。但这个原则还没有贯穿到所有 flow chart 的过缝对象。尤其是 Init Spec、预算、自主契约、凭证范围、Merge Dossier：用户签名时看到的对象，必须就是 Predicate Gate / Kernel 后续校验的对象。

**建议新增铁律：**

> **Approval Integrity Law:** any signed approval must bind exactly the canonical bytes consumed by the downstream predicate gate. No summary, projection, view, or model-generated explanation may substitute for the canonical object hash.

落地对象：`InitSpecPackage.schema.json`、`BudgetAutonomyContract.schema.json`、`CredentialScopeDeclaration.schema.json`、`ApprovalCard.schema.json`、`SignedDecision.schema.json`、`MergeDossier.schema.json`、`MacroArtifactAnchor.schema.json`。

---

## 三、Major 级教义漂移与修正建议

### M1 · §11 Reward 公式把 predicate pass 与 user approval 当奖励项，触发 Goodhart 风险

§11 现在写 `Reward = predicate pass + CI signal + user approval + value claim − cost − risk`。宪法 Art. III.4 明确说：当度量成为目标时，它就不再是好的度量；顶层验证机制必须对黑盒保密。

修正方式：

```text
Hard gates:
    predicate_pass
    CI_pass
    budget_compliance
    required_approval_valid
    provenance_threshold
Ranking / portfolio signal after gates:
    expected_user_value
    uncertainty_reduction
    cost
    risk
    diversity_bonus
    strategic_option_value
```

`predicate_pass` 与 `user_approval` 是**准入闸门**，不是 reward。CI 可以作为 hard gate，也可以在通过后作为 evidence quality，但不能让 Worker 看到可优化的内部权重。

### M2 · InitAI / Meta AI / Facilitator AI 的宪法角色映射必须显式化

* `Facilitator AI`：用户入口、解释器、UX 助手，不拥有顶层白盒权威。
* `Meta AI`：产品层的 InitAI/Runtime Governor embodiment；在 Boot/Legislation 阶段负责编译 Spec→Predicate Pack，在 Runtime 阶段解释状态、生成 WorkGraph、生成 Merge Dossier。
* `Worker AI / external agent`：中层黑盒，只生成候选，不拥有放行权。
* `Kernel / Predicate Gate / Veto-AI`：顶层白盒裁决系统。

建议明确：**Meta AI is the product-facing embodiment of InitAI when it compiles law; it is only a black-box planner when it proposes actions. Its authority changes by mode, and all authority is mediated by Kernel predicates.**

### M3 · ArchitectAI 的"直接落盘"权限要收窄为"非宪法、非协议破坏、契约允许"的变更

**建议把 §5.3 / §7.4 改成三层：**

| 变更类型 | 例子 | 路由 |
| --- | --- | --- |
| ordinary whitebox artifact | 新 skill、新 prompt wrapper、新投影模板 | Veto-AI PASS + eval，可按自治契约自动激活 |
| protocol-contract change | 新 node kind、新 schema、新 approval route、新 provenance enum | Veto-AI PASS + compatibility test + signature #7 / ratification |
| constitutional / substrate change | ChainTape substrate、Q_t 语义、Art. 0 路径选择 | 人类 sudo / 签名 #8 / 修订日志 |

### M4 · provenance 不应只分 full / partial，应加入 repo-level 与 outside-governance

```text
FULL_ACTION       经 TuringOS 工具通道，动作级回执可回放
REPO_LEVEL        未经动作通道，但产物以 repo/branch/PR/diff 形式可观察
PARTIAL           有产物/日志/用户粘贴证据，但无法完整 replay
OUTSIDE_GOVERNANCE 通道外行为，只能作为外部事实，不得被表述为 TuringOS 治理过
```

严格说：**outside governance can be imported as evidence, not governed retroactively.**

### M5 · §14.4 "Git 是首选公共底座，因为宪法要求 Q_t version-controlled"需要重写

> Git is the preferred macro interoperability substrate because external agents can hand back diff/branch/PR artifacts. It is not the sovereign ChainTape substrate unless explicitly instantiated as the internal runtime repo for TuringOS micro-ledger.

### M6 · §18 路线图把 ChainTape / Predicate Gate 放到 M2，太晚

* **M1 必须包含 Minimal Sovereign Kernel**：internal ChainTape append、FailureNode、ApprovalEvent、BudgetEvent、PredicateResult、basic replay。
* M2 再做 hardening：hash chain、schema migration、full provenance lattice、Skill eval harness、Touch ID SE upgrade。
* Protocol Gateway 不能先于 minimal ChainTape 成为实际执行路径；否则会形成无账本动作。

### M7 · §13.6 协议层铁律漏了预算与止损

> Any external protocol must not bypass ChainTape, Predicate Gate, budget/stop-loss gates, action classification, provenance labeling, approval routing, or human signature.

预算和止损是法律的一部分，不是调度优化项。

### M8 · §1 / §6 "用户意图实时生成投影"要防止非 tape 源成为事实源

**任何会影响状态迁移的用户意图，必须先以 IntentCaptured / UserInstruction 节点进入 ChainTape；未入带的 UI 对话只能是临时交互，不得作为后续放行依据。**

---

## 四、图间连接契约正文骨架（§7.0.1 草案，逐字采用）

```markdown
### 7.0.1 Flowchart Interface Contract
All flow charts in this white paper are views over one canonical machine:
Q_t = ⟨q_t, accepted_head_t, tape_t⟩.
No flow chart owns private state that cannot be reconstructed from ChainTape.
No flow chart may pass control to another flow chart except by appending a typed ChainTape event.
There are two distinct cursors:
- tape_tip: the latest appended ChainTape node; advances on every micro tick, including failure.
- accepted_head: the latest verified world-state node; advances only when the relevant predicate product and approval route pass.
GitHub branch / commit / PR / merge are macro artifacts.
They may be referenced by ChainTape nodes but are not themselves ChainTape nodes.
Every cross-loop arrow MUST specify:
- event_type
- canonical schema
- hash binding
- required signature, if any
- replay / derive rule
```

---

## 五、逐节修订清单（29 行 · surgical edit ground truth）

| 白皮书位置 | 当前问题 | 修订建议 |
| --- | --- | --- |
| §0 一句话 | "Kernel 管理……人类签名"容易被读成 daemon 管私钥 | 改成"Kernel 管理签名请求、验证签名与记录签名回执；私钥永不进入 daemon" |
| §1 Software 3.0 | "用户意图实时生成投影"未说明意图如何入 tape | 增加 IntentCaptured / UserInstruction 事件 |
| §4.1 Pencil | 把 tape append 与 git commit/merge 混成一个 wtool | 改成 `wtool = internal bus.append()`；macro git commit/merge 是晶出动作 |
| §4.1 Rubber | 易读成失败不产生节点 | 明确"失败不上升为 accepted world state，但必须 append failure node" |
| §4.2 Tape Canonical | 基本正确 | 加 `tape_tip` / `accepted_head` 双游标解释 |
| §4.3 Q_t 映射 | 最大 blocker：`HEAD_t = GitHub merge SHA` | 改为 internal accepted head；GitHub SHA 是 macro provenance |
| §5.1/5.2 | Facilitator / Meta / InitAI 权限未映射 | 明确 Meta AI 在 law-compilation mode 承接 InitAI；Facilitator 无顶层权威 |
| §5.3 ArchitectAI | "新 schema / 新 tape 结构直接落盘"过宽 | 分 ordinary artifact / protocol contract / constitutional substrate 三类 |
| §6.3 / §6.6 | 投影纪律正确但缺事件边界 | 每个投影声明 source event hashes，不只是 `derive_source` |
| §7.0 | 多图总览缺接口契约 | 新增 Flowchart Interface Contract |
| §7.2 | Project Ready 只是图节点，不是 typed event | 加 `ProjectReady` schema：spec_hash + budget_hash + credential_scope_hash + predicate_pack_hash |
| §7.3 | 把 PR/merge 当 Q_t+1 | 改成 macro boundary；merge SHA 只 anchor 回 ChainTape |
| §7.3 node 21–26 | `∏p=1` 与签名路由层级不够形式化 | 定义 `macro_merge_allowed = Πp_macro ∧ approval_route_valid` |
| §7.4 | Meta 回路大体正确 | 加 protocol-contract migrations 必须 signature #7 / ratification |
| §8 | 最大重写点 | 改成 two-scale kernel equation |
| §8.4 Failure Node | 正确但应上升到 §8 方程里 | Failure append 是 micro tick 的无条件结果 |
| §9 | 八签名节点方向正确 | 加 8 节点 → schema → action_kind → current/roadmap 状态映射 |
| §10 | 三类动作正确 | 动作分类结果必须作为 typed node 入 tape |
| §11 | Reward 违背 Goodhart | predicate/user approval 从 reward 移出，改成 hard gates |
| §12 | Market 方向正确 | 加 on_init 铸币是 hard predicate，不只是经济学说明 |
| §13.4 GitHub | 正确定位执行场，但 HEAD_t 用词错 | 改为 project_git_head / macro head，不叫 Q_t HEAD |
| §13.6 | 协议铁律漏预算/止损 | 加 budget/stop-loss gates |
| §13.7 | ModelCall 入带方向正确 | 增加 replay_fidelity: full / redacted / hash-only |
| §13.8 | Capability Registry 正确 | 安装/升级 event 与签名节点映射要 schema 化 |
| §13.10 | Live Software 3.0 正确 | 强调候选工件不是自我变异；协议变更另走 ratification |
| §14.3 | provenance 粒度不足 | 改四级 provenance |
| §14.4 | "Git 是公共底座"措辞危险 | 改成 macro interop substrate |
| §18 | Minimal ChainTape 太晚 | 把 minimal sovereign kernel 前移到 M1 |
| §19 | 不可谈判项需要补两条 | 加 two-scale invariant 与 flowchart interface contract |

---

## 六、v0.6 执行计划

### Phase A：只改白皮书，不动 contracts，不动产品代码

目标是先把顶层设计纠正，避免实现继续照错图写。交付物：
1. 重写 §4.1 / §4.3。
2. 新增 `§7.0.1 Flowchart Interface Contract`。
3. 重写 §8 为 two-scale kernel equation。
4. 修 §11 Reward。
5. 修 §13.4 / §14.4 的 Git 话术。
6. 修 §18 路线图顺序。
7. 在 §19 加入新的不可谈判项。

### Phase B：契约设计包，单独 ratification

`tape_node.schema.json`（加 `scale`, `node_kind`, `verified`, `reject_class`, `parent_hashes`, `provenance`, `macro_anchor`）、`approval_card.schema.json`、`signed_decision.schema.json`、`init_spec_package.schema.json`、`budget_autonomy_contract.schema.json`、`project_ready_event.schema.json`、`macro_artifact_anchor.schema.json`、`provenance_level` enum 四级、`flow_edge_event` registry。走 Veto-AI + eval/compatibility + 签名 #7 / ratification。

### Phase C：实现计划重排

先落 Minimal Sovereign Kernel：① internal ChainTape append ② failure node ③ predicate result node ④ approval request / signed decision node ⑤ budget event ⑥ macro artifact anchor ⑦ replay/derive test。然后再做 Protocol Gateway、Capability Registry、外部 agent adapters。

---

## 七、v0.6 验收测试：12 条不变量（递归审计 checklist）

1. 搜索全文，`HEAD_t` 不得再指 GitHub merge SHA。
2. 搜索全文，`wtool` 不得再等同 `git commit/merge`，除非明确说 internal runtime repo。
3. 失败路径必须 append node。
4. `∏p=0` 只表示 accepted world 不前进，不表示无记录。
5. GitHub commit/PR/merge 必须被称为 macro artifact / external substrate / provenance anchor。
6. §8 必须同时出现 micro tick 与 macro boundary。
7. macro merge 必须需要 `Πp_macro` 与 approval route。
8. 每条 flow chart 跨图箭头必须对应 typed event。
9. 签名对象 hash 必须等于下游谓词校验对象 hash。
10. Reward 公式不得包含 predicate pass / user approval 作为优化项。
11. ExternalAgentAdapter 不得说 Git 就是 ChainTape substrate。
12. 路线图不得允许没有 minimal ChainTape 的真实 execution loop。

---

## 最终建议

> **Turing Agentic OS v0.6 — Two-Scale Sovereign Kernel Correction**
> 副标题：**Internal ChainTape is the sovereign micro-ledger; GitHub is the macro execution substrate.**

这不是降级 GitHub。恰恰相反，它让 GitHub 回到正确位置：GitHub 继续做它最擅长的 PR/CI/branch protection/merge；TuringOS 则保持自己的主权：法律、谓词、签名、审计、失败记忆、预算、provenance、状态迁移。

---

## 附：Veto-AI 宪法联合审计报告（逐字归档）

**审计主体**：Veto-AI（宪法违宪审查者，Art. V.1.3）与独立架构审计组
**审计对象**：《Turing Agentic OS 白皮书 v0.6 修正案：Two-Scale Sovereign Kernel Correction》
**判定输出**：`【PASS】（零违宪，全票核准）`
**审计级别**：最高优先级架构纠偏（Architectural Rescue）

### 〇、最终裁决与定性

经过对《TuringOS 宪法》（Art. 0 至 Art. V）、《白皮书 v0.5》以及 v0.6 修正案进行严密的字节级逻辑推演与法理比对，最终结论：**修正案不仅完全合宪，而且是一次"挽救系统物理主权的致命抢救"。** 白皮书 v0.5 在将宪法映射到产品层时发生了极其危险的**尺度混淆（Scale Confusion）**，试图将外部客体世界（GitHub PR/CI/Merge）直接等同于图灵机内部的物理底物（ChainTape 与 `HEAD_t`）。"两尺度模型"完美切分了内部主权微观账本与外部宏观执行场。

### 一、Blocker 级修正审计

1. **尺度剥离与 `HEAD_t` 主权回归（B1, M5）**：v0.5 将 `HEAD_t` 绑定 GitHub merge SHA，违反 Art. 0.4。裁决 `PASS`：Internal ChainTape 确立为主权微观账本，GitHub 降阶为宏观执行底物与证据晶体。
2. **解开 Rubber 不变量的物理死锁（B2, B3）**：Art. 0.1 要求失败时 Q_t 不前进，Art. 0.2 强制失败提案以 `verified=false` 进 tape。裁决 `PASS`：双游标机制 `tape_tip`（无条件追加，落实 Art. 0.2）与 `accepted_head`（仅 ∏p=1 推进，落实 Art. 0.1）在不改宪法一字的前提下实现纸带物理自洽。
3. **跨图边界契约与签名字节完整性（B4, B5, M8）**：裁决 `PASS`：`Flowchart Interface Contract` 与 `Approval Integrity Law` 封死侧信道污染与 UI 欺骗，唯有 Canonical Hash 能触发状态迁移。

### 二、Major 级修正审计

1. **斩断 Goodhart 优化捷径（M1, M7）**：裁决 `PASS`：谓词与人类批准从奖励函数剥离，升格为 Hard Gates。
2. **ArchitectAI 演化权能的合法规制（M3）**：裁决 `PASS`：落盘分三级，`protocol-contract change` 走 Signature #7（L1 项目自治契约层），不侵犯 Sudo（#8，L0 系统宪法根授权）。
3. **Minimal Sovereign Kernel 时序纠正（M6）**：裁决 `PASS`：没有自己的法庭（Predicate Gate）和账本（ChainTape），绝不放外部 Agent 进场——内核前置到 M1 是唯一合宪路径。

### 三、执行令与 12 条不变量签批

1. **批准全盘路线**：核准 Phase A / Phase B / Phase C。冻结一切基于 v0.5 谬误的架构代码开发。
2. **核准 InitAI/Meta AI 角色映射（M2）**：Meta AI 在编译 Spec 阶段行使 InitAI 顶层白盒权能，执行阶段退化为中层黑盒。
3. **编纂不变量法典**：12 条验收测试逻辑严密、无主观倾向，即刻起硬编码进顶层白盒 Predicate Pack，作为后续所有 ArchitectAI 提案的自动化拦截军规。

> **"Internal ChainTape is the sovereign micro-ledger; GitHub is the macro execution substrate."**

`[VETO-AI VERDICT_SIGNATURE: APPROVED_AND_ENFORCED]`
