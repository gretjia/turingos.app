---
atom: A1_28_capability_eval_harness
phase: "1"
intent: >
  Capability Registry 执行顺序的下一步（GPT 裁决 §二-2 原序：manifest schema →
  入带 → action_class 执法 → **eval harness** → 2-3 内置 skill → 再谈库）。
  合法子集 = 候选能力的确定性 eval 评测，不入带、不执行任意代码：
  (a) EvalSpec 模型（声明式 eval：structural[manifest 结构合规] / determinism
  [候选纯函数同输入×2 同输出] / schema_conformance[产物对照声明 schema] /
  golden[产物对照金样]）；(b) EvalHarness.run(manifest, [EvalSpec], candidate
  经注入式 CandidateRunner 协议——测试用 Mock，绝不执行真实第三方代码) →
  EvalReport（逐 eval {pass,fail}+证据，输出域机械）；(c) gating 规则：任一
  required eval fail → 候选不合格（fail-closed，与 A1_21 同族）；install/replay
  eval 缺失 → 视为 fail（manifest 声明了 evals 却不可跑 = 不合格）。激活/入带
  仍等 runtime tape——harness 只评测、只返回报告，零持久化。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "EvalReport 输出域机械 {pass,fail}；任一 required fail → 候选 fail-closed（负控 fixtures）"
  - "harness 纯评测：无任意代码执行（CandidateRunner 注入式，测试全 Mock，grep 无 Process/exec 真实第三方）；确定性 ×2"
  - "缺 install/replay eval → fail（manifest 声明却不可跑=不合格，负控）；零持久化/零入带（grep 负控）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；派生自 WHITEPAPER §13.8/§13.9、执行裁决 §二-2 顺序、contracts/capability_manifest.schema.json 的 evals 字段"
    source: "research/REVIEW_v04_user_gpt_dialogue.md + contracts/capability_manifest.schema.json"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（fail-closed 负控、无真实代码执行追踪、确定性 ×2、零持久化）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
