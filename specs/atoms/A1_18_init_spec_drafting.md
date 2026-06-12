---
atom: A1_18_init_spec_drafting
phase: "1"
intent: >
  Sprint 2 草案侧（合法子集）：Init Spec 起草向导 + Retro-Init 预填 +
  WorkOrderPackage 构建器。边界裁决（C 级，依 UPSTREAM_CONTRACT 判例
  "上游不可达时暂记 ratification → 拒绝"）：本 atom 只做 draft 域——
  SpecPackage 模型（spec_hash 确定性计算；status 仅 {draft,
  awaiting_ratification}，类型层面不可表示 ratified）、确定性向导
  reducer（无模型的模板问答流，Meta AI 起草待 Gateway atom）、本地草案
  持久化（三件套投影声明）、Retro-Init 从 catalog 预填、WorkOrderPackage
  构建器（产物机械符合 contracts/work_order_package.schema.json）。
  批准 #1/#2 与 tape genesis 明确等待 P1.9 runtime 导入（并行会话车道），
  Project Ready 状态如实显示"草案，待内核仪式"。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 10
predicates:
  - "SpecPackage.status 枚举不含 ratified（类型不可表示 + 测试断言）；零 ratification/approval 写入（grep 负控）"
  - "spec_hash 确定性：同一草案 ×2 → 相同 sha256；向导 reducer 纯函数可测"
  - "WorkOrderPackage 构建产物含 schema 全部 required 字段（对照 contracts 文件机械断言）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；边界依 docs/UPSTREAM_CONTRACT.md 判例与 docs/03 §2/§3 验收"
    source: "docs/UPSTREAM_CONTRACT.md + docs/03_OPERATING_FLOW_ACCEPTANCE_TESTS.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（负控：ratification 写入 grep 零命中；
   schema required 字段对照真实 contracts 文件；hash 确定性 ×2）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
