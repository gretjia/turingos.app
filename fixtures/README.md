# fixtures/ — 确定性事件流（repo law 第二支柱）

每条 `.jsonl` 是一段可重放的事件流：一行一个 `contracts/event_stream.schema.json` 信封；`seq` 严格递增、`event_id` 全局唯一、时间戳固定（确定性）。校验：`bash scripts/validate_contracts.sh`；确定性：shipgate #9（双读 sha256 一致）。

**纪律：没有 fixture 的功能不许开工**（PLAN P1 起强制）。fixture 先于实现存在——它是"输入事件长什么样、输出界面状态长什么样"的活契约，执行 agent 与渲染器都以它为锚。

| 文件 | 覆盖 |
|---|---|
| `event_streams/p1_worktree_radar.jsonl` | Radar 主链：注册项目 → 发现 worktree → 文件变化 → diff 快照 → 提案候选 → 对账 |
| `event_streams/p2_identity_states.jsonl` | **ActorTrustState 全 11 态**逐一出现（validate_contracts 断言覆盖完整性） |
| `event_streams/p3_ratification_flow.jsonl` | L4 全仪式链：提案 → 开仪式 → 签名（canonical payload + receipt）→ signed tag |
| `event_streams/p6_rejected_proposal.jsonl` | 拒绝路径：提案 → 谓词 FAIL → VETO → 拒绝上 tape（verified=false 节点）——失败即状态 |

负载内嵌子对象的校验映射（validate_contracts.sh 内置）：`PredicateResult→payload.result`、`Signature*→payload.receipt`、`Ratification{Proposed,Signed}→payload.ratification`、`ProposalSubmitted→payload.receipt`。
