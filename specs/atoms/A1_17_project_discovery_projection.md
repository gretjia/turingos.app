---
atom: A1_17_project_discovery_projection
phase: "1"
intent: >
  Sprint 1 第三颗（收官）：项目发现 + Git 只读状态投影接入 Orb。
  (a) IntentRouter 的"项目"意图从样例数据切换为真实 RepoCatalog/store 数据 →
  project_picker IR；(b) 选中项目 → 只读项目状态投影（summary_card +
  worktree_map blocks，确定性派生自 GlanceProjection store 的 triage/radarScene
  状态，derive_source 指向事件流/快照）；(c) specs/atoms/NUMBERING.md 编号车道
  注册表入库（用户授权撞号处置）。全程只读——不写 git、不调模型；投影守恒：
  同一 store 状态 → 相同 IR 文档。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "project_picker 由真实 RepoCatalog 数据构建（无样例占位）；空目录降级为引导卡"
  - "项目状态投影确定性：同一 store fixture 状态 ×2 → 字节一致 IR；derive_source 非空"
  - "零写操作：新代码 grep 无 git commit/push/写 repo 路径"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；派生自 docs/02 §2/§4 与 docs/04 Sprint 1 验收（能选择一个 repo / 所有投影可重建）"
    source: "docs/04_ALPHA_EXECUTION_PLAN.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现（读 RepoCatalog/GlanceProjection/Workspace 既有 API + A1_15/16 产物），
   Sonnet 对抗核验（确定性 ×2、零写 grep、空目录降级、app lane ×2）。
2. 架构师终审 → shipgate → 回执 → PR（base=main，链已收齐不再堆叠）。
