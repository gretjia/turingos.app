# 03_OPERATING_FLOW_ACCEPTANCE_TESTS — 四回路运作验收测试

> 依据：WHITEPAPER.md v0.5 §4/§7/§8/§9/§13 · 执行裁决工程标准 1–8（2026-06-12）· contracts/*.schema.json · docs/RATIFICATION_POLICY.md · 宪法 Art. I.1.1/Art. 0.2/Art. III
>
> **术语纪律**：工具/能力 = 底层白盒；谓词/管理 = 顶层白盒；Agent = 中间黑盒。三层不得混称（§13.8 术语纪律）。

---

## 1. 测试哲学

### 1.1 输出域锁定

每条验收测试的裁决域严格为 `{PASS, FAIL}`，没有第三值。

凡不满足此要求的判断——文风优劣、架构美感、UX 流畅度、风险估计——均属主观项，**不得冒充谓词**。主观项走独立 `RiskFinding` 通道（`contracts/predicate_result.schema.json` `$defs.RiskFinding`），附于 Merge Dossier 供人类裁决，不阻塞 `∏p` 计算（宪法 Art. I.1.1 / 执行裁决红线补注）。

### 1.2 判据类型优先级

| 优先级 | 类型 | 示例 |
|---|---|---|
| 1（最高） | 命令退出码 / grep 匹配 | `scripts/shipgate.sh` 各门禁 |
| 2 | JSON schema 结构校验 | `scripts/validate_contracts.sh` |
| 3 | fixture 断言 | `fixtures/` 目录下的合法/非法用例 |
| 4 | 代码层 static grep | 路径名 / 字符串不出现断言 |
| 5（最低；仅用于文档级核查） | 人工逐字核对 | 字段名称核查 |

级别 5 仅限于当前 Sprint 的工程实现尚未落地、测试框架本身处于 Schema-first 阶段时临时使用；实现落地即升级为 1–4。

### 1.3 CI 绿不等于 ∏p=1

GitHub CI 通过是外部谓词之一，不是全部（白皮书 §7.3 节点 21 / 执行裁决工程标准 4）。Predicate Gate 在 CI 绿的基础上叠加：Spec 符合、DoD 满足、diff 在 worktree 范围内、预算合规、回执完整、数据边界、provenance 阈值——任一 FAIL 则 `∏p = 0`，Q 不前进。

### 1.4 失败入带义务

`∏p = 0` 时，当次失败节点必须以 `verified=false, reject_class=<class>` 写入 tape（`contracts/tape_node.schema.json` `failure` kind）。失败是下一轮搜索的资产，不是可丢弃的日志（宪法 Art. 0.2 / 白皮书 §8.4）。

---

## 2. Project Ready 验收（执行裁决工程标准 1）

项目进入执行回路（回路 2）的唯一前提是 Project Ready 状态已通过所有以下检查。缺任何一项 → FAIL，该项目不得派发普通工单，只能运行 readiness task（白皮书 §7.2 / 执行裁决标准 1）。

### 2.1 检查项列表

| # | 检查项 | 判定方法 | 通过条件 |
|---|---|---|---|
| PR-1 | `spec_hash` 存在 | `grep -r '"spec_hash"' <project_tape_dir>` | tape 中至少一条 `spec_ratified` kind 节点包含非空 `spec_hash` 字段 |
| PR-2 | `definition_of_done` 存在 | `grep -r '"definition_of_done"' <project_spec_file>` | Spec 文件包含非空 `definition_of_done` 字段 |
| PR-3 | `acceptance_predicates` 存在且非空 | `python3 scripts/validate_contracts.sh` + 内容断言 | Spec 中 `acceptance_predicates` 为非空数组（≥1 条目） |
| PR-4 | `budget_contract` 存在 | tape 中 `budget_ratified` kind 节点存在 | `jq '[.[] \| select(.kind=="budget_ratified")] \| length > 0'` 输出 `true` |
| PR-5 | `data_scope` 存在 | Spec 文件 `data_scope` 字段非空 | `jq '.data_scope != null and .data_scope != ""'` |
| PR-6 | `git_head_anchor` 存在 | tape 中 `head_anchor` kind 节点存在 | `jq '[.[] \| select(.kind=="head_anchor")] \| length > 0'` |
| PR-7 | `tape_genesis_node` 存在 | tape 第一条节点为 `genesis` kind，`prev_node_hash` = zero hash | `jq '.[0].kind == "genesis"'` + `prev_node_hash` 符合零哈希格式 |
| PR-8 | 批准 #1 已记录（Init Spec） | tape 中存在 `approval_envelope` kind 节点，`signature_node == 1` | `jq '[.[] \| select(.kind=="approval_envelope" and .payload.signature_node==1)] \| length > 0'` |
| PR-9 | 批准 #2 已记录（预算与自治契约） | tape 中存在 `approval_envelope` kind 节点，`signature_node == 2` | `jq '[.[] \| select(.kind=="approval_envelope" and .payload.signature_node==2)] \| length > 0'` |

### 2.2 Retro-Init 缺失处理

已有项目（Retro-Init 路径）若以上任一项缺失，判定为 `readiness_task_only = true`：系统只允许运行「Project Readiness 补录任务」，不允许普通工单派发（白皮书 §7.2 E2→Retro-Init 分支）。

**检查方法**：`grep '"readiness_task_only": true'` 出现在项目状态对象中，且普通 WorkOrderPackage 派发路径有对应 guard：

```
if project.readiness_task_only:
    raise WorkOrderRejected("Project not Ready: Retro-Init required")
```

该 guard 的存在通过 fixture 测试：`fixtures/retro_init_missing_blocks_dispatch.json` 应触发 `WorkOrderRejected`（PASS = 抛出错误；FAIL = 正常派发）。

### 2.3 Sprint 归属

| 检查项 | Sprint |
|---|---|
| PR-1 至 PR-7（Schema 与 tape 结构） | Sprint 0 |
| PR-8、PR-9（批准枚举） | Sprint 2 |
| Retro-Init guard fixture | Sprint 2 |

---

## 3. WorkOrderPackage 验收（执行裁决工程标准 2）

每次向内部 Worker 或外部 Agent 派发任务，必须打包为合法的 `WorkOrderPackage`（`contracts/work_order_package.schema.json`）。

### 3.1 Required 字段完整性检查

以下字段必须全部存在且非空，缺任何一项不得派发（schema `required` 数组）：

| 字段 | 语义 | 缺失后果 |
|---|---|---|
| `schema_version` | 版本锁 `tos.app.work_order_package.v0` | 结构非法 |
| `work_order_id` | 工单唯一标识 | 无法溯源 |
| `project_id` | 归属项目 | 无法关联 tape |
| `spec_ref` | Spec 哈希引用 | 谓词门无法验 Spec 符合性 |
| `worktree_scope` | 工作树范围声明 | diff 超范围无法检测 |
| `allowed_files` | 允许修改的路径 glob 列表 | 同上 |
| `forbidden_files` | 禁止修改的路径 glob 列表 | 同上 |
| `objective` | 任务目标描述 | Agent 无明确意图 |
| `expected_outputs` | 预期产物清单 | 谓词门无验收参照 |
| `acceptance_predicates` | 机器可验证的 PASS/FAIL 谓词列表 | 谓词门缺少判据（主观意见禁止入此字段） |
| `budget_slice` | 本工单预算切片 | 预算检查点无数据 |
| `provenance_requirement` | `full` 或 `partial_with_human_confirm` | provenance 阈值路由失效 |
| `prompt` | 实际派发的提示内容 | Agent 无法执行 |

**判定方法**：`python3 scripts/validate_contracts.sh contracts/work_order_package.schema.json <instance.json>`，返回码 0 = PASS，非 0 = FAIL。

**Fixture**：
- `fixtures/work_order_package_valid.json`：所有 required 字段齐全 → 校验 PASS
- `fixtures/work_order_package_missing_spec_ref.json`：缺 `spec_ref` → 校验 FAIL
- `fixtures/work_order_package_missing_allowed_files.json`：缺 `allowed_files` → 校验 FAIL（白皮书 §7.3 注：无范围声明 = 未作用域，必须拒绝）

### 3.2 缺包即拒发

执行面派发层必须有前置 guard：WorkOrderPackage 校验非 0 返回码则拒绝派发，不继续执行，失败原因写入 tape `failure` 节点。

**Fixture 断言**：`fixtures/dispatch_with_invalid_package.json` 触发 `DispatchRejected`（PASS = 抛出；FAIL = 正常派发）。

### 3.3 主观意见不入 acceptance_predicates

`acceptance_predicates` 数组中不允许出现非机器可验证的文字（如"代码风格良好"、"用户体验优秀"）。主观发现走 Merge Dossier 的 `risk_findings` 通道（`contracts/merge_dossier.schema.json`）。

**检查方法**：合规性 fixture `fixtures/work_order_package_subjective_predicates.json` 包含主观谓词，验收层 linter 检测后应拒绝（PASS = 拒绝；FAIL = 接受）。

### 3.4 Sprint 归属

| 验收项 | Sprint |
|---|---|
| Schema 结构校验（3.1） | Sprint 0 |
| 缺包拒发 guard（3.2） | Sprint 1 |
| 主观谓词 linter（3.3） | Sprint 2 |

---

## 4. 执行回路验收（白皮书 §7.3）

### 4.1 止损护栏有界性

CI 修复回路（§7.3 节点 18→19→11）与谓词失败回路（22→20→11）共用止损护栏（节点 20），三项计数任一触线即强制 HALT-止损，**不得无界重试**（白皮书 §7.3 注"没有无界重试"）。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| CI 修复回路有上限 | grep `max_ci_repair_attempts` 在止损配置中存在且为正整数 | 找到 |
| 谓词失败回路有上限 | grep `max_predicate_fail_retries` 在止损配置中存在且为正整数 | 找到 |
| 触线后不再派发新工单 | fixture：止损计数达上限后，`dispatch()` 调用应被拦截 | 抛出 `HaltStopLoss` |
| 触线写入 tape | tape 末尾节点 kind=`halt`，payload 含 `halt_class="stop_loss"` | jq 断言通过 |

### 4.2 HALT 五分类入带证据

白皮书 §7.6 定义五个终止态，每个必须在 tape 中有对应的 `halt` kind 节点，且包含规定字段（执行裁决裁定 / 白皮书 §7.6 表格）：

| HALT 类别 | tape 必含字段 | 判定方法 |
|---|---|---|
| **HALT-达成** | `halt_class="achieved"`, `milestone_receipt_ref`, `head_anchor_ref` | jq `.payload.halt_class == "achieved"` 且两个 ref 非空 |
| **HALT-预算** | `halt_class="budget_exhausted"`, `budget_consumed_detail` | jq 断言 + `budget_consumed_detail` 非空对象 |
| **HALT-止损** | `halt_class="stop_loss"`, `reject_class_history`, `latest_failed_predicate` | jq 断言 + 两字段非空 |
| **HALT-中止** | `halt_class="user_abort"`, `partial_tape_sealed=true`, `worktree_stash_list` | jq 断言 |
| **崩溃恢复** | 崩溃后重启，tape 中无新 halt 节点，Q_t 从 tape 重建 | 见 4.6 崩溃重建测试 |

**Fixture 集**：`fixtures/halt_achieved_valid.json`、`fixtures/halt_budget_valid.json`、`fixtures/halt_stoploss_valid.json`、`fixtures/halt_abort_valid.json`，各文件均须通过 `tape_node.schema.json` 校验。

### 4.3 异步批准不阻塞其他 worktree

签名请求 #4/#5/#6 在用户不在场时进入批准队列，所属 worktree 挂起，**其余 worktree 照常推进**（白皮书 §7.5 / §7.3 节点 `WAITQ`）。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| Worktree A 挂起不阻塞 Worktree B 调度 | 集成测试：同时建两个 worktree，A 触发签名 #5 进入队列，B 的工单派发不受阻 | B 成功派发 |
| 批准队列持久化入 tape | tape 中出现 `approval_envelope` kind 节点，`expiry_utc` 非空 | jq 断言 |
| 用户回来后裁决 | 仿真批准动作后，tape 中出现对应 `approval_signature` kind 节点 | jq 断言 |

### 4.4 staged 诚实回边

当动作进入暂存（影子工作区 / 草稿形态）或被拒绝时，agent 必须同步收到 `status=staged` 或 `status=rejected`，不允许返回"已完成"（白皮书 §3 操守第 4 条 / §7.3 DRAFT·REJ 节点）。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| 二类动作返回 staged | 对 class_2 工具调用模拟执行，检查返回值 `status` 字段 | `status == "staged"` |
| 三类动作拒绝返回 rejected | 拒绝批准卡后，检查返回给 agent 的消息 | `status == "rejected"` |
| tape 中有对应节点 | staged：tape 有 `action_receipt`（`verified=true`，`status=staged`）；rejected：tape 有 `rejection` kind | jq 断言各自通过 |
| agent 不重试同一动作 | 集成测试：agent 收到 `status=staged` 后应绕开该动作，不重发同一请求 | 无重复动作节点 |

### 4.5 崩溃重启后 Q_t 从 tape 重建

崩溃不是重新 Boot，而是从 tape 重建 Q_t（白皮书 §7.1 / §4.2 Tape Canonical / ADR-003）。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| 重建后 WorkGraph 进度一致 | 仿真崩溃（进程 kill），重启后读取 WorkGraph 状态与崩溃前一致 | 深度比对两份快照 diff = 空 |
| 挂起批准队列恢复 | 重启后批准队列条目与崩溃前相同 | 批准队列长度与内容 jq 断言 |
| 止损计数恢复 | 重启后止损计数与崩溃前一致，不从零重置 | 数值比对 |
| tape hash chain 连续 | 重启后调用 `scripts/verify_tape_chain.sh`，无断链 | 返回码 0 |

### 4.6 并行 worktree 上下文隔离

同时运行的多个 worktree 的 Worker 上下文相互隔离：独立 tape 切片、独立会话线程，一个 worktree 的失败叙事不污染另一个的规划上下文（宪法 Art. III.3 / 白皮书 §7.3 节点 14 注）。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| 各 worktree tape 切片独立 | `jq '.[] \| .work_order_id' worktree_A.tape.json` 不含 worktree_B 的 work_order_id | grep 无交叉 |
| 失败节点不跨 worktree 广播 | Worktree A 产生 `failure` 节点后，Worktree B 的下一次 Meta AI 提示上下文中不含 A 的失败叙事 | 提示内容 grep A 的 work_order_id = 空 |
| 谓词门逐 worktree 触发 | 两个 worktree 各自走完 15→21 全程，各自有独立 `predicate_verdict` 节点 | jq 各自节点存在 |

### 4.7 Sprint 归属

| 验收项 | Sprint |
|---|---|
| 止损护栏有界（4.1） | Sprint 0（schema）/ Sprint 3（集成） |
| HALT 五分类入带（4.2） | Sprint 0（schema）/ Sprint 3（集成） |
| 异步批准不阻塞（4.3） | Sprint 2（批准队列）/ Sprint 3（多 worktree 集成） |
| staged 诚实回边（4.4） | Sprint 1（协议层）/ Sprint 3（集成） |
| 崩溃重建（4.5） | Sprint 0（tape chain）/ Sprint 2（重建 Q_t） |
| 并行上下文隔离（4.6） | Sprint 3 |

---

## 5. Predicate Gate 验收（白皮书 §7.3 节点 21）

### 5.1 diff 超 worktree_scope → ∏p = 0

CI 通过但 diff 包含 worktree_scope 之外的文件时，Predicate Gate 必须拒绝（∏p = 0），Q 不前进。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| 超范围 diff 被拒 | fixture：`fixtures/diff_out_of_scope.json`（changed_files 含 allowed_files 之外路径），Predicate Gate 返回 FAIL | 返回 `{verdict: "FAIL", reject_class: "scope_violation"}` |
| 范围内 diff 通过 | fixture：`fixtures/diff_in_scope.json`，Predicate Gate 返回 PASS | 返回 `{verdict: "PASS"}` |
| 结果入 tape | tape 中有 `predicate_verdict` kind 节点，verdict 与 Predicate Gate 返回一致 | jq 断言 |

### 5.2 partial provenance → 强制 signature_5 路由（执行裁决工程标准 3）

`provenance_level = "PARTIAL"` 的候选不允许走 `approval_route = "autonomy_contract"`，必须强制路由到 `signature_5`（白皮书 §7.3 节点 21 / 执行裁决标准 3）。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| partial provenance 不走自治合同放行 | fixture：`fixtures/merge_dossier_partial_provenance.json`（`provenance_level="PARTIAL"`, `approval_route="autonomy_contract"`），校验应返回 FAIL | `scripts/validate_contracts.sh` 或合并路由 guard 返回错误 |
| partial provenance 必须走 signature_5 | 同上 fixture 改 `approval_route="signature_5"` → 校验 PASS | 返回码 0 |
| 合并路由 guard 代码层检查 | `grep -r "provenance_level.*PARTIAL.*signature_5" <source_dir>` | 找到对应 guard 代码 |

### 5.3 ci_evidence 全 required 字段缺一不可（执行裁决工程标准 4）

Merge Dossier 中的 `ci_evidence` 对象必须包含所有 8 个 required 字段，裸"CI green"字符串或缺少任一字段的 `ci_evidence` 应被拒绝（`contracts/merge_dossier.schema.json` ci_evidence.required）。

所有 8 个必填字段：

| 字段 | 语义 |
|---|---|
| `commit_sha` | 触发 CI 的精确 commit |
| `merge_base` | merge base commit |
| `check_run_ids` | GitHub check run ID 列表 |
| `workflow_file_hash` | workflow 文件 sha256（防 workflow 被篡改） |
| `branch_protection_snapshot` | 评估时的 branch protection 配置快照 |
| `required_checks_at_time` | 评估时 required check 列表 |
| `runner_type` | 运行环境类型 |
| `conclusion` | CI 结论 |

**判定方法**：

```sh
python3 scripts/validate_contracts.sh contracts/merge_dossier.schema.json fixtures/ci_evidence_incomplete.json
# 期望：非 0 返回码 → PASS（校验正确拒绝）
python3 scripts/validate_contracts.sh contracts/merge_dossier.schema.json fixtures/ci_evidence_complete.json
# 期望：返回码 0 → PASS（校验通过）
```

### 5.4 RiskFinding 不携带 verdict 字段

`predicate_result.schema.json` 中 `RiskFinding` 子对象不允许有 `verdict` 字段。主观发现只能以 advisory 形式附于 Merge Dossier `risk_findings` 数组，不产生 PASS/FAIL 裁决（宪法 Art. I.1.1）。

**检查方法**：`grep -r '"verdict"' contracts/predicate_result.schema.json` 在 `$defs.RiskFinding` 子节点下的出现次数 = 0（PASS）；> 0（FAIL）。

### 5.5 Sprint 归属

| 验收项 | Sprint |
|---|---|
| diff 超范围 ∏p=0（5.1） | Sprint 0（schema）/ Sprint 3（门禁集成） |
| partial provenance → signature_5（5.2） | Sprint 0（schema）/ Sprint 3（路由 guard） |
| ci_evidence 字段完整（5.3） | Sprint 0（schema）/ Sprint 3（证据采集） |
| RiskFinding 无 verdict（5.4） | Sprint 0 |

---

## 6. ModelCall 与凭证（执行裁决工程标准 5 / 6）

### 6.1 每次模型调用产生合法 model_call 节点（标准 5）

Model Gateway 是底层白盒管道，每次调用必须写 `model_call` kind 节点入带，不得有未记录的模型流量（白皮书 §13.7 / `contracts/model_call.schema.json`）。

所有 required 字段（共 14 个）：

| 字段 | 类型 |
|---|---|
| `schema_version` | `"tos.app.model_call.v0"` |
| `call_id` | string |
| `provider` | string |
| `model` | string |
| `role` | enum（facilitator/meta/worker/veto/architect/gardener） |
| `privacy_mode` | enum（full/redacted） |
| `input_record` | 含 mode + content_hash |
| `output_record` | 含 mode + content_hash |
| `latency_ms` | integer ≥ 0 |
| `cost` | object |
| `token_usage` | object |
| `policy` | object |
| `project_id` | string |
| `replay_degraded` | boolean |

**判定方法**：

```sh
# 每次调用后 tape 追加
python3 scripts/validate_contracts.sh contracts/model_call.schema.json <last_tape_entry.json>
# 返回码 0 → PASS
```

集成测试：执行一次 Meta AI 调用后，tape 末尾节点 `kind == "model_call"` 且 schema 校验通过。

**脱敏模式诚实降级**：`privacy_mode = "redacted"` 时 `replay_degraded` 必须为 `true`，不允许两者不一致（schema 约束 + fixture `fixtures/model_call_redacted_valid.json` / `fixtures/model_call_redacted_replay_inconsistent.json`）。

### 6.2 凭证明文在 tape 与 prompt 中 0 次出现（标准 6）

凭证（API key、OAuth token、密码）必须存 Keychain/SE，tape 中只记 `credential_scope_hash`，prompt 上下文中不得含凭证明文（白皮书 §7.2 节点 9 / §13.7 恒定规则 / 执行裁决标准 6）。

| 检查项 | 判定方法 | PASS |
|---|---|---|
| tape 无凭证明文 | `grep -iE "(api_key\|apikey\|access_token\|bearer\|secret\|password\|Authorization:\s*[Bb]earer)" <tape_file>` | 匹配行数 = 0 |
| prompt 无凭证明文 | tape 中所有 `model_call` 节点的 `input_record.content`（full mode 下）做同样 grep | 匹配行数 = 0 |
| tape 含 credential_scope_hash | 凭证域批准后，tape 中 `credential_scope_ratified` kind 节点存在，payload 含 `credential_scope_hash`（`sha256:` 前缀） | jq 断言 |

### 6.3 Sprint 归属

| 验收项 | Sprint |
|---|---|
| model_call schema（6.1） | Sprint 0 |
| model_call tape 集成（6.1 集成） | Sprint 1（Facilitator 调用）/ Sprint 2（Meta AI 调用） |
| 凭证明文 grep（6.2） | Sprint 1（onboarding API key 配置时）起持续 |

---

## 7. Live Software 3.0：suggestion-only（执行裁决工程标准 7）

Live Software 3.0 回路（白皮书 §13.10）在第一阶段必须严格限于「观测 → 聚类 → 建议」，候选工件只能以 suggestion 形态出现，**自动激活路径不存在**（执行裁决标准 7 / 白皮书 §13.10 "第一阶段必须是 observe → cluster → suggest，不能自动激活"）。

### 7.1 候选工件形态检查

| 检查项 | 判定方法 | PASS |
|---|---|---|
| 候选 Skill 只写入 suggestion 状态 | Live S3.0 产出的 Skill 草稿 tape 节点 `status = "suggestion"`，无 `status = "active"` | jq 断言 |
| 候选谓词只写入 suggestion 状态 | 同上，谓词草稿节点 `status = "suggestion"` | jq 断言 |
| 候选投影模板只写入 suggestion 状态 | 同上，投影模板草稿节点 `status = "suggestion"` | jq 断言 |

### 7.2 自动激活路径不存在（代码层断言）

```sh
# 代码库中不存在绕过 Veto-AI + eval + 人类签名直接激活 Skill 的路径
grep -rn "auto_activate\|autoActivate\|activate_without_approval\|direct_activate" \
    --include="*.swift" --include="*.rs" \
    <source_dir>
# 期望：匹配行数 = 0 → PASS
# 找到任何匹配 → FAIL，需要代码审查
```

### 7.3 激活路径完整性

合规的激活路径必须经过：Veto-AI PASS → eval 通过 → （契约要求时）签名 #7 → `skill_activation` kind 节点入带（白皮书 §13.10 / §7.4 回路 3）。

**Fixture**：`fixtures/skill_activation_without_veto_fail.json`（缺 Veto-AI PASS 直接激活）→ 激活 guard 拒绝，FAIL。`fixtures/skill_activation_complete_valid.json`（全路径合规）→ 激活成功，PASS。

### 7.4 Sprint 归属

| 验收项 | Sprint |
|---|---|
| suggestion 状态 schema（7.1） | Sprint 0 |
| 自动激活 grep 检查（7.2） | Sprint 2（Live S3.0 框架落地时） |
| 激活路径 fixture（7.3） | Sprint 3 |

---

## 8. Registry 先于深集成（执行裁决工程标准 8）

无合法 `capability_manifest.schema.json` 实例的外部工具调用必须被拒绝（fail-closed）。任何外部工具/技能/连接器在 Capability Registry 注册并通过 manifest 校验之前，不得深度集成（执行裁决标准 8 / 白皮书 §13.8）。

### 8.1 未注册工具 fail-closed

| 检查项 | 判定方法 | PASS |
|---|---|---|
| 无 manifest 调用被拒 | fixture：`fixtures/tool_call_no_manifest.json`，调用层返回 `ToolCallRejected` | 抛出错误，不执行 |
| 无效 manifest 调用被拒 | fixture：`fixtures/capability_manifest_invalid_action_class.json`（缺 `action_classes.default`），按 class_3 处置或拒绝 | 返回 class_3 处置或 `ManifestInvalid` |
| 合法 manifest 调用通过 | fixture：`fixtures/capability_manifest_valid.json`，调用层允许执行 | 正常分发 |

### 8.2 action_classes 缺失 → fail-closed 为 class_3

`capability_manifest.schema.json` 描述中明确：`action_classes` 缺失或无效时，系统必须将该能力视为 class_3（不可逆外部），或直接拒绝（白皮书 §13.8 第 3 条 / `contracts/capability_manifest.schema.json` description）。

**代码层断言**：

```sh
grep -rn "action_classes.*class_3\|fail.*closed.*manifest\|ManifestMissing.*class_3" \
    --include="*.swift" --include="*.rs" \
    <source_dir>
# 期望：找到对应 guard 实现 → PASS
# 未找到 → FAIL
```

### 8.3 安装/升级/移除入带

工具的 Install、Update、Remove 操作必须写 tape 节点（`tool_install` / `tool_update` / `tool_remove` kind），可回放、可回滚（白皮书 §13.8 第 5 条 / `contracts/tape_node.schema.json` kind 枚举）。

**判定方法**：集成测试执行一次工具安装后，`jq '[.[] | select(.kind=="tool_install")] | length > 0' tape.json` 输出 `true`（PASS）。

### 8.4 Sprint 归属

| 验收项 | Sprint |
|---|---|
| manifest schema 校验（8.1）  | Sprint 0 |
| fail-closed guard 代码（8.2） | Sprint 1（Registry 框架落地） |
| 安装入带 tape（8.3） | Sprint 2 |

---

## 附录 A：Sprint 验收全表

| Sprint | 必须全绿的验收项 | 上线门槛 |
|---|---|---|
| **Sprint 0**（Schema-first Kernel Spine） | PR-1~7、WO schema、HALT schema、ci_evidence schema、model_call schema、predicate_result schema、tape_node hash chain、diff scope fixture、partial provenance fixture、RiskFinding 无 verdict | `scripts/validate_contracts.sh` 全 0 + `fixtures/` 全通过 |
| **Sprint 1**（Orb + Facilitator + Meta AI Setup） | WO 缺包拒发 guard、model_call tape 集成（Facilitator）、凭证明文 grep 干净、fail-closed tool guard 存在 | Sprint 0 全绿 + 本 Sprint 新增验收项全 PASS |
| **Sprint 2**（Project Ready） | PR-8、PR-9、Retro-Init guard、WO 主观谓词 linter、Live S3.0 suggestion schema、工具安装入带、model_call tape 集成（Meta AI）、崩溃重建 Q_t | Sprint 1 全绿 + 本 Sprint 新增验收项全 PASS |
| **Sprint 3**（GitHub CI + Merge Dossier Loop） | 止损护栏有界集成、HALT 五分类集成、异步批准多 worktree 集成、staged 诚实回边集成、并行 worktree 隔离、partial→signature_5 路由 guard、ci_evidence 完整证据采集、Live S3.0 激活路径 fixture | Sprint 2 全绿 + 本 Sprint 新增验收项全 PASS + `scripts/shipgate.sh p0` 全绿 |

---

## 附录 B：核心 fixture 清单

| Fixture 文件 | 用途 | 期望结果 |
|---|---|---|
| `fixtures/retro_init_missing_blocks_dispatch.json` | 无 Retro-Init 项目触发工单派发 | `WorkOrderRejected` |
| `fixtures/work_order_package_valid.json` | 合法工单包 | 校验 PASS |
| `fixtures/work_order_package_missing_spec_ref.json` | 缺 spec_ref | 校验 FAIL |
| `fixtures/work_order_package_missing_allowed_files.json` | 缺 allowed_files | 校验 FAIL |
| `fixtures/work_order_package_subjective_predicates.json` | 含主观谓词 | linter 拒绝 |
| `fixtures/dispatch_with_invalid_package.json` | 非法包触发派发 | `DispatchRejected` |
| `fixtures/diff_out_of_scope.json` | diff 超 worktree_scope | ∏p=0，FAIL |
| `fixtures/diff_in_scope.json` | diff 在范围内 | ∏p 通过此项 |
| `fixtures/merge_dossier_partial_provenance.json` | partial + autonomy_contract | 路由 FAIL |
| `fixtures/ci_evidence_incomplete.json` | ci_evidence 缺字段 | schema FAIL |
| `fixtures/ci_evidence_complete.json` | ci_evidence 全字段 | schema PASS |
| `fixtures/halt_achieved_valid.json` | HALT-达成节点 | tape_node schema PASS |
| `fixtures/halt_budget_valid.json` | HALT-预算节点 | tape_node schema PASS |
| `fixtures/halt_stoploss_valid.json` | HALT-止损节点 | tape_node schema PASS |
| `fixtures/halt_abort_valid.json` | HALT-中止节点 | tape_node schema PASS |
| `fixtures/model_call_redacted_valid.json` | 脱敏模式 replay_degraded=true | model_call schema PASS |
| `fixtures/model_call_redacted_replay_inconsistent.json` | 脱敏但 replay_degraded=false | model_call schema FAIL |
| `fixtures/skill_activation_without_veto_fail.json` | 缺 Veto-AI 直接激活 | 激活 guard 拒绝 |
| `fixtures/skill_activation_complete_valid.json` | 完整激活路径 | 激活成功 |
| `fixtures/tool_call_no_manifest.json` | 无 manifest 工具调用 | `ToolCallRejected` |
| `fixtures/capability_manifest_invalid_action_class.json` | 无效 action_classes | class_3 处置或 `ManifestInvalid` |
| `fixtures/capability_manifest_valid.json` | 合法 manifest | 正常分发 |
