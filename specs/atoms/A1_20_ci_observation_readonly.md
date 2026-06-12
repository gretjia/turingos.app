---
atom: A1_20_ci_observation_readonly
phase: "1"
intent: >
  Sprint 3 只读观测面（合法子集，不动 Q）：(a) GitObservation——项目分支/PR
  检测（协议化源，live 实现只用只读 git/gh 命令，测试全 mock）；(b)
  CIEvidenceCollector——只读装配 merge_dossier.ci_evidence 全部 8 个 required
  字段（commit_sha/merge_base/check_run_ids/workflow_file_hash[=该 commit 下
  workflows 文件哈希]/branch_protection_snapshot[gh api 只读]/
  required_checks_at_time/runner_type/conclusion）；(c) repair_prompt 投影
  （失败 check 摘要 → 确定性模板，无模型）；(d) dossier_view 草案投影
  （merge_dossier 形状的 DRAFT，无裁决、无 Q 前进、approval_route 仅显示）。
  Predicate Gate 与合并放行明确等 runtime 导入。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 10
predicates:
  - "live 路径仅只读命令（git log/rev-parse/hash-object、gh pr list/checks/api GET）——禁写 grep 负控（push/merge/edit/delete/POST 零命中）"
  - "ci_evidence 装配覆盖 schema 全部 8 个 required 键（测试读真实 contracts 文件断言）"
  - "投影确定性 ×2 字节一致；derive_source 非空；测试零网络（全 mock）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；派生自 docs/03 §5（标准 4：不接受裸 CI green）与 merge_dossier.schema.json"
    source: "docs/03_OPERATING_FLOW_ACCEPTANCE_TESTS.md + contracts/merge_dossier.schema.json"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（禁写负控、schema 覆盖独立复核、零网络测试证明）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
