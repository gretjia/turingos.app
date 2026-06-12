---
atom: A1_24_strategy_observe_only
phase: "1"
intent: >
  执行裁决批准的第一阶段策略层（白皮书 §11/§12 的 v0 子集，GPT 裁决原文：
  "Portfolio Radar / Project Stumps / observe-only statistics / manual
  strategy branching"）：(a) ProjectStump 模型（§11 七种树桩类型的可见策略树，
  手动分支操作 = 纯状态变换，草案域持久化带三件套）；(b) ObserveOnlyStatistics
  ——对传入记录的确定性统计（预算消耗/重复失败按 reject_class/CI 成本/worker
  成功率/人类审阅负担计数），纯函数，宪法 Art. I.2；(c) Portfolio Radar 投影
  （组合层 IR 文档，复用既有 block 类型）。**边界**：零自动决策、零 reward
  优化、零 MCTS、market signal 永不入任何放行路径（不可谈判项 8）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "统计纯函数确定性 ×2 字节一致；不含任何主观估值（输入→标量，无模型）"
  - "Stump 操作 = 纯状态变换；无自动生成/自动扩展路径（grep auto 负控）"
  - "投影复用既有 block 类型（ViewIR.swift 不变）；derive_source 非空"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；派生自 WHITEPAPER §11/§12、宪法 Art. I.2/II.2、执行裁决二-1"
    source: "WHITEPAPER.md + research/REVIEW_v04_user_gpt_dialogue.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（确定性 ×2、零自动决策负控、ViewIR 不变审计）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
