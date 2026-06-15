---
atom: A1_44_predicate_gate
phase: "1"
intent: >
  回路2 ∏p 门：新增 PredicateGate —— 对一个 worktree 跑该项目【自有的可信谓词】
  （swift build / bash scripts/build_app.sh / scoped test，commands-as-data），
  归约到 {PASS,FAIL} + 证据哈希。verdict 域严格 {PASS,FAIL}（守 shipgate #4 +
  predicate_result.schema.json）；evidence_hash = sha256:<hex> 覆盖 tag/exit/stdout/
  stderr（CryptoKit，同 ApprovalCardContent 范式）；predicate_id ^prd_。
  **fail-closed**：无谓词配置 → 抛 noPredicateConfigured（绝不静默 PASS）。这只跑
  仓库自有的可信 gate，不在进程内执行不受信 agent 代码（agent 已在 worktree 外部跑完，
  WHITEPAPER §13.8）。PredicateResult Codable 且键名对齐 contract。
allowlist:
  - "app/Sources/TuringOS/PredicateGate.swift"
  - "app/Tests/TuringOSTests/PredicateGateTests.swift"
  - "scripts/build_app.sh"
  - "specs/atoms/A1_44_predicate_gate.md"
  - "specs/atoms/CURRENT"
max_new_files: 2
predicates:
  - "bash scripts/build_app.sh 全绿（executed >= MIN_TESTS）"
  - "真跑测：worktree 内谓词 exit 0 → verdict==PASS；exit 1 → verdict==FAIL（变异敏感，exit-code 驱动）"
  - "fail-closed 测：predicate==nil → 抛 noPredicateConfigured（非静默 PASS）"
  - "schema 一致测：PredicateResult 编码键 == predicate_result.schema.json required（predicate_id/schema_version/verdict/evidence_hash/target）；verdict ∈ {PASS,FAIL}；evidence_hash 匹配 ^sha256:[0-9a-f]{8,64}$；predicate_id 匹配 ^prd_[a-z0-9_]+$"
verified_external_facts: []
ux_touchpoints: >
  回路2：worktree 完工后跑 ∏p → 绿则进 Dossier（A1_45），红则失败证书（不进 Dossier）。
  失败/无谓词 fail-visible，绝不假绿。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
PredicateSpec(commands-as-data: tag/executable/arguments + 预设 swiftBuild/bashScript)；
CommandRunner 协议 + LiveCommandRunner（cwd=worktree，并发抽管道+超时，沿用 A1_38）+
MockCommandRunner（测试）；PredicateResult(Codable, snake_case keys, schema_version const)；
evaluate(worktree,branch,predicate?,runner)：nil→fail-closed 抛错；跑→exit0=PASS；
sha256 证据；predicate_id=prd_<slug>_<hash8>。
