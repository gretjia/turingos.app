---
atom: A1_19_budget_contract_project_ready
phase: "1"
intent: >
  预算 + 自治契约草案域（合法子集，同 A1_18 宪法边界）：BudgetContract 模型
  （BudgetLimits / AutonomyConstraints；status 仅 {draft, awaiting_ratification}，
  类型层面不可表示 ratified）+ budgetHash（SHA256 over limits+autonomy，排除
  status/projectId，与 specHash 同款）+ BudgetContractBuilder（复用 A1_23
  ApprovalEnvelopeBuilder，signatureNode=2，构造层仅产物，不写入 tape）+
  BudgetProjections（budgetDraftCard / projectReadyPendingCard，确定性 View IR，
  复用 A1_15 BudgetCardPayload）。tape genesis 写入明确等待 P1.9 runtime 导入
  （"仪式不可用就是不可用"判例，宪法边界 docs/UPSTREAM_CONTRACT.md）。
  依据：白皮书 §7.2 立法回路 / docs/02_SOFTWARE_3_UI_PRD.md §5 / 04 Sprint 2 A1_19。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 7
predicates:
  - "BudgetContractStatus 枚举不含 ratified（类型不可表示 + CaseIterable 测试断言 count==2）"
  - "budgetHash 确定性 ×2 字节一致；内容变更 → 哈希不同；status/projectId 变更 → 哈希不变"
  - "Builder signatureNode==2 机械断言；budgetHash 字段 == 'sha256:'+ hex（schema pattern）"
  - "投影确定性 ×2 字节一致；derive_source 非空；schema_version 非空"
  - "零 ratification/tape 写入路径（grep 负控：BudgetContractStatus.allCases 无 ratified）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "边界依 docs/UPSTREAM_CONTRACT.md 判例（2026-06-12 A1_18 落地验证）；模式与 A1_18/A1_21/A1_22 完全同款"
    source: "docs/UPSTREAM_CONTRACT.md + specs/atoms/receipts/A1_18_init_spec_drafting.receipt"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. 实现 BudgetContract.swift + BudgetContractBuilder.swift + BudgetProjections.swift。
2. 写 BudgetContractTests.swift（12 个测试覆盖全部 predicate）。
3. shipgate p1 全绿 → /atom-ship → PR → 合 main。
