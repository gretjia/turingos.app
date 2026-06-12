---
atom: A1_14_sprint0_kernel_spine
phase: "1"
intent: >
  Sprint 0「Schema-first Kernel Spine」：把 v0.5 的不可让渡主权先做成机器契约。
  (a) 新增 7 个 schema（tape_node / approval_envelope / capability_manifest /
  work_order_package / model_call / failure_node / merge_dossier）+ fixtures
  （每 schema 至少 1 valid + 1 invalid 负控）+ contracts/README 索引更新；
  approval_envelope 含 GPT 红线 2 全字段 + Tier-2 预留槽（audit_root /
  external_anchor_id / host_threat_level）；merge_dossier 含 CI 证据加固字段；
  capability_manifest 写明 fail-closed 语义；tape_node 注明 canonical 语义在
  runtime（不复制上游实现，仅外壳消费契约）。(b) 四份工程文件：
  docs/01_KERNEL_CONTRACTS.md / 02_SOFTWARE_3_UI_PRD.md /
  03_OPERATING_FLOW_ACCEPTANCE_TESTS.md / 04_ALPHA_EXECUTION_PLAN.md
  （v0.5 压成可执行工程规约；执行范围 = 用户批准的最小主干，缓行项明列）。
allowlist:
  - "contracts/"
  - "fixtures/"
  - "docs/01_KERNEL_CONTRACTS.md"
  - "docs/02_SOFTWARE_3_UI_PRD.md"
  - "docs/03_OPERATING_FLOW_ACCEPTANCE_TESTS.md"
  - "docs/04_ALPHA_EXECUTION_PLAN.md"
  - "scripts/validate_contracts.sh"
max_new_files: 30
predicates:
  - "7 个新 schema 文件存在且 scripts/validate_contracts.sh 通过"
  - "负控有效：人为破坏任一 fixture → 校验器 FAIL（gate 有牙），恢复后 PASS"
  - "grep -q visible_card_hash contracts/approval_envelope.schema.json && grep -q workflow_file_hash contracts/merge_dossier.schema.json && grep -q fail-closed contracts/capability_manifest.schema.json"
  - "test -s docs/01_KERNEL_CONTRACTS.md && test -s docs/02_SOFTWARE_3_UI_PRD.md && test -s docs/03_OPERATING_FLOW_ACCEPTANCE_TESTS.md && test -s docs/04_ALPHA_EXECUTION_PLAN.md"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "本 atom 不引入新外部论断；工程内容全部派生自 WHITEPAPER v0.5（已审）+ 用户批准的 GPT 执行裁决 + 既有 contracts/ 纪律"
    source: "WHITEPAPER.md (branch claude/a1-12-whitepaper-v04) + research/REVIEW_v04_user_gpt_dialogue.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. 架构师锁定字段契约与文档大纲（C 级，已在派发 prompt 内）；Sonnet 实现
   schemas + fixtures + 校验接线（含负控实测）；Sonnet 对抗核验。
2. 四份工程文件由 4 路 Sonnet 并行起草（读 v0.5 + GPT 裁决 + 新 schemas），
   Sonnet 一致性 critic + Haiku lint 收口。
3. 架构师终审 → shipgate 全绿 → 回执 → PR（堆叠于 v0.5 分支，#27 合并后自动重定向）。
   执行授权：用户 2026-06-12 批准 v0.5 最小主干落地（Sunday 15:00 窗口）。
