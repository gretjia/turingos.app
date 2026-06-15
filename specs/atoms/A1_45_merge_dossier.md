---
atom: A1_45_merge_dossier
phase: "1"
intent: >
  回路2 切片终点：新增 MergeDossierBuilder —— ∏p==PASS 时，从 PredicateResult + git
  事实构建 schema 一致的 MergeDossier（spec_delta / ci_evidence / changed_files /
  risk_findings / rollback_plan / budget_used / provenance_level / receipts /
  known_limitations / approval_route），并给出"可 merge"判定句。
  **R1 宪法律**：provenance=PARTIAL（外部派发 worker）→ approval_route MUST = signature_5
  （绝不 autonomy_contract；白皮书 §7.3 partial-provenance 不许纯谓词放行，强制升人审）。
  ci_evidence 复用 ∏p 结果（workflow_file_hash=predicate.evidence_hash、check_run_ids=
  [predicate_id]、conclusion=verdict、runner_type=local_predicate_gate）。
  **FAIL → 不出 Dossier**（抛 predicateNotPassing；失败走失败证书，不是 Dossier）。
  切片到此为止：不执行真 merge、不做签名仪式（那是后续卡）。
allowlist:
  - "app/Sources/TuringOS/MergeDossierBuilder.swift"
  - "app/Tests/TuringOSTests/MergeDossierBuilderTests.swift"
  - "scripts/build_app.sh"
  - "specs/atoms/A1_45_merge_dossier.md"
  - "specs/atoms/CURRENT"
max_new_files: 2
predicates:
  - "bash scripts/build_app.sh 全绿（executed >= MIN_TESTS）"
  - "schema 一致测：编码 MergeDossier 的键 == merge_dossier.schema.json required（13 顶层 + 8 ci_evidence 嵌套），单一法源读 schema 文件"
  - "R1 律测：provenance==PARTIAL → approval_route==signature_5（partial 绝不 autonomy_contract）"
  - "FAIL 不出 Dossier 测：FAIL 的 PredicateResult → build 抛 predicateNotPassing"
  - "ci_evidence 复用 ∏p 测：workflow_file_hash==predicate.evidence_hash 且匹配 ^sha256:；conclusion==verdict；check_run_ids 含 predicate_id"
verified_external_facts: []
ux_touchpoints: >
  回路2：∏p 绿 → 出 Dossier + "可 merge，路由签名#5" 判定卡；红 → 失败证书不出 Dossier。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
MergeDossier(Codable, snake_case keys, schema_version const) + 嵌套 CiEvidence/RiskFinding；
ProvenanceLevel/ApprovalRoute 枚举；build(predicate,projectId,branch,commitSha,mergeBase,
changedFiles,provenance,...)：PASS 守卫；R1 路由派生；dossier_id=dossier_<hash>；
verdictSentence() 给 UI 句子。
