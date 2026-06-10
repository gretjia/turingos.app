# PLAN — Phase → Module → Atom 与 R→D→S 运行协议

这是大型软件工程，不是一次定 spec 写到验收的小项目。**只对当前 Phase 做 Atom 级切分**；后续 Phase 只锁闭环目标与门禁方向，细目由各自 R-stage 产出——杜绝瀑布式 spec 腐烂。

## R→D→S 运行协议（每个 Phase 强制三段，Harness 机械执行）

1. **R-stage 调研门禁**：独立调研（外部 API/框架必须 WebFetch 实证）→ 思辨（**内核问**：做什么/怎么实现 × **体验问**：入口长什么样/用户看到什么/参与什么）→ **停机点：设计简报与关键裁决呈交用户确认（ADR-012 唯一强制停机环节）**。产出 `research/R<N>_memo.md`（verified facts 带溯源与日期）+ 设计简报（UX-heavy Phase 必含界面草案）+ ADR 增量 + Atom 卡集（用户确认后方可产出）。**门禁**：memo 未提交，`guard_spec_alignment` 拒绝把该 Phase 的任何 Atom 设为 CURRENT。
2. **D-stage 原子开发**：逐 Atom 实现。Atom = 一次会话可完成的最小单元，卡片含 intent / allowlist / predicates / `verified_external_facts`（带日期）/ `ux_touchpoints` / gate（模板：`specs/ATOM_TEMPLATE.md`）。
3. **S-stage 过闸**：`scripts/shipgate.sh <phase>` 全绿 + Veto-AI 清洁上下文审计（输出域 {PASS,VETO}）+ UX-heavy Phase 加快照/可达性谓词。FAIL 原文上报。

**UX→内核反向塑形登记簿**（双轨法的核心产出，R-stage 持续追加）：

| UX 需求 | 被反向塑形的内核 | 落点 |
|---|---|---|
| 签名仪式屏要给人读的摘要 | ratification payload 必含 `human_readable_summary` | `contracts/ratification_payload.schema.json`（required） |
| Radar 实时流 | GUI↔daemon IPC 必须事件订阅式而非纯请求响应 | ADR-005 |
| Replay 时间轴拖动 | tape 必须支持范围查询 API | P6 R-stage 设计约束 |
| 活动脉冲要"呼吸感"而非闪烁噪音 | FSEvents 去抖窗口成为协议参数（事件 payload 携带 debounce 元数据，minor 扩展） | R1 简报；A1_04 落地 |
| 菜单栏三计数恒时可信 | daemon 维护常驻聚合投影（非查询时现算），投影守恒测试覆盖 | R1 简报；A1_03 落地 |
| 全景面板 = 多 repo 同屏（V6/四次裁决） | daemon 注册表驱动 N×Reconciler，事件按 project_id 隔离 | design/V6_RECONCILIATION.md；A1_06 |
| 压缩卡每 repo 一眼健康度（四次裁决） | 聚合投影按 project 分桶 + 全局 rollup，双层守恒测试 | design/V6_RECONCILIATION.md；A1_06 |

## Phase 总表

| Phase | 闭环目标 | 状态 |
|---|---|---|
| **P0 护栏与契约** | 文档 + 双层 Harness + contracts schemas + fixtures，shipgate 十检全绿 | **本期** |
| **P0.5 Thin Vertical Slice** | fixtures → event stream → projection → 人类可读视图的极薄闭环（无 App 代码）：`scripts/simulate_event_stream.sh`（泵）+ `scripts/render_snapshot_placeholder.sh`（确定性渲染）；门禁 = shipgate #11 双渲染 sha256 一致 + #12 golden 比对（`fixtures/snapshots/`） | **已交付**（R0.5 memo + 2 Atom 带回执） |
| **P1 Worktree Radar V0**（只读） | 添加项目 → worktree 列表 → 脏 diff 流 → 渲染。R1 必须覆盖六边界：①symlink/路径穿越（canonicalize；worktree 不得逃逸 registry）②submodule ③git-lfs/binary ④untracked 与 .gitignore ⑤branch identity（detached HEAD/foreign badge；禁止两个 writer worktree 检出同一 mutable branch）⑥FSEvents 只是提示非日志。**没有 fixture 的功能不许开工**。Stable lane 部署目标在 R1 实证后定 | 待 R1 |
| **P1.9 Runtime Port**（用户 2026-06-10 裁定"完全移植"后插入） | turingosv4 内核 + tested CLI **完整移植入本仓**，App 只是其上外壳。**R-stage = 质量抽查审计**（`research/R1.9_audit_runbook.md`：机器扫描 + 变异抽样 + 双 critic 评审 → 预注册规则把每模块映射到 S1 原样/S2 绞杀整修/S3 重写；审计报告即 `research/R1.9_memo.md`）。**基线保护原则**：永远先 S1 原样导入跑绿——全部测试 + 164 道门禁成为本仓 CI 与 shipgate 检查项（门禁数==上游原数，少一即红），任何整修只在基线之后以小 PR 落地。D-stage 三参数（历史保留方式 / v4 原仓命运 / 执行路径）待用户终裁；ADR-015 届时成文取代 ADR-009 双仓姿态（保留其边界纪律：壳代码 import 内核 internals = grep 谓词红线） | R-stage 审计中（本地 session 执行） |
| **P2 Identity & Wallet** | manifest 注册/验签/SE 钱包/GitSigner。**建立在 P1.9 移植后的仓内内核之上**。ActorTrustState 已在 P0 锁定（`docs/TRUST_STATES.md`），P2 只实现不发明；key_kind 显式建模。门禁含 fail-closed 四态金标（accept-valid / reject-forged / reject-impostor / reject-no-manifest） | 待 P1.9 + R2 |
| **P3 Ratification Center** | Class-4 签名流水线：canonical payload → §8 token → signed tag → merge guard → receipt。仪式只给 L4（`docs/RATIFICATION_POLICY.md`）。门禁：payload hash 跨机确定性；squash 篡改负向测试必拒 | 待 R3 |
| **P4 Task → WorktreeSlot** | Mission DAG / lease 状态机。门禁：property test；并发抢占双 agent 必一败；崩溃后 lease 从 tape 重建 | 待 R4 |
| **P5 Agent Adapters** | Claude Code：WorktreeCreate/Remove hooks 主动接管 + PreToolUse/PostToolUse/SessionStart/Stop/FileChanged 等 31 事件按需；Codex：**app-server 双向 JSON-RPC 首选**（非 CLI 包装）；全员永久兜底 = FSEvents + `git worktree list` 周期对账（ADR-010）。门禁：真实会话产出签名 session receipt；绕过 App 手工建 worktree 的混沌注入必收敛 | 待 R5 |
| **P6 Proposal Gate** | diff → 签名提案 → Predicate {PASS,FAIL} + Veto {PASS,VETO} 双闸 → refs/tos/{accepted,rejected,ratified}。**拒绝也是状态**：以 verified=false 上 tape。门禁：全链 receipt replay 一致 | 待 R6 |
| **P7 Market Signals**（observe-only） | 市场投影看板 + 常驻横幅 "Price is a signal, not predicate truth"。门禁：投影守恒；自动路由代码路径 grep=0；market claim 语言门禁（P0 已备） | 待 R7 |
| **P8 Market Experiments** | 稀缺预算 / 异质 specialist 分配实验 + 公平 foil（shuffled_price/flatbid/no_price/parallel/central/random）。门禁：跑不赢 foil 则结论生成器机械拒绝输出任何 price 优势表述 | 待 R8 |

## P0 Atom 表（本期全量，16 颗）

| Atom | 交付 | 验收 |
|---|---|---|
| A0_01 constitution-pin | `constitution/{constitution.md,PINS.toml}` | sha256 == PINS 记录（shipgate #1） |
| A0_02 manifesto | `MANIFESTO.md` | M1-M8 全部带执行点；四问齐 |
| A0_03 plan | `PLAN.md` | 本文档；R→D→S + 反向塑形登记簿 |
| A0_04 adr | `ADR.md` | ADR-001~011；含双层 Harness、双轨平台、双仓契约、worktree 真相层级、三级 API |
| A0_05 harness-doc | `HARNESS.md` | repo law / developer UX 分层声明 + 五 hook 协议 |
| A0_06 design-charter | `DESIGN.md` | Software 3.0 UX 范式 + 五时刻 + 美学门禁化 |
| A0_07 e2e-blueprint | `E2E_BLUEPRINT.md` | 三级对抗 + 盲点登记簿 |
| A0_08 entry-docs | `README.md` + `CLAUDE.md` | 第一原则置顶；CLAUDE.md 为目录非百科 |
| A0_09 contract-docs | `docs/{UPSTREAM_CONTRACT,CLI_ABI}.md` | 三铁律 / 七铁律成文 |
| A0_10 security-docs | `docs/{THREAT_MODEL,PROJECTION_POLICY}.md` | 12 威胁场景 + UDS 五件套；三级 API 字段分级 |
| A0_11 ux-docs | `docs/{NAVIGATION_MODEL,VISUAL_SEMANTICS,RATIFICATION_POLICY,TRUST_STATES,ADAPTER_CAPABILITY_MATRIX}.md` | 十导航×每页五问；唯一色语义；L0-L4；11 态枚举；三适配器矩阵 |
| A0_12 contracts | `contracts/*.schema.json` + `contracts/README.md` | shipgate #2/#3/#4/#8 全绿 |
| A0_13 fixtures | `fixtures/event_streams/*.jsonl` ×4 | 全部过 validate_contracts；p2 覆盖 11 信任态；seq 严格递增 |
| A0_14 repo-law | `scripts/{shipgate.sh,validate_contracts.sh}` + `scripts/predicates/*.grep` | 十检实现；无 Claude 依赖（shipgate #7 自检） |
| A0_15 claude-layer | `.claude/{settings.json,hooks×5,skills×2,agents×2}` | 五 hook 干跑断言（shipgate #10） |
| A0_16 specs+memo | `specs/{ATOM_TEMPLATE.md,atoms/CURRENT}` + `research/R0_memo.md` | R-stage 自举：P0 自己的证据链归档（含 hooks 纠错） |

## P0 Ship-Gate 十检（`bash scripts/shipgate.sh p0`）

1. 宪法快照 sha256 == PINS；2. contracts/fixtures 结构校验全绿（没有无 schema 的 event）；3. projection 强制 derive_source/rebuild_command（没有无 owner 的投影）；4. predicate verdict 枚举锁死 {PASS,FAIL}（没有 advisory 冒充 predicate）；5. market claim 语言门禁（没有把 price 写成 truth）；6. 禁忌断言 grep=0（没有第二套 source of truth、没有 beta-only API 进 contracts）；7. repo law 无 Claude 依赖自检（没有把 Claude harness 写成 canonical CI）；8. ratification payload 结构强制 canonical 字段+人读摘要（没有无 payload 的 ratification）；9. fixture 确定性（seq 严格递增、event_id 唯一、双读 sha256 一致）；10. 五 hook 干跑断言 + 文档死链=0 + R-memo 门禁自测。
