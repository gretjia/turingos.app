---
atom: A1_29_turing_skill_model
phase: "1"
intent: >
  白皮书 §13.9 Turing Skill 模型（GPT 裁决 §二-2 顺序：eval harness → **内置
  official skills** → 库；本卡建 Skill 模型这一前置）。合法子集 = SKILL.md
  兼容的草案域打包，不激活、不入带（激活=状态迁移=runtime tape）：
  (a) SkillMD 解析器（YAML frontmatter + 正文，渐进披露三级语义，纯函数）；
  (b) TuringSkill 模型 = SKILL.md（instructions/scripts/schemas）+ 法律外壳
  （allowed_action_classes / credential_scopes / receipt_schema / replay 规则 /
  evals / failure_modes，对照白皮书 §13.9 字段）；(c) SkillValidator（frontmatter
  required 字段 + action_classes 合法值 + 与 A1_21 FailClosedClassifier 复用——
  未声明 action_classes 的 skill fail-closed 视为 class_3）；(d) 2-3 个 official
  skill 定义作为**模板数据**（fixtures，非激活条目——GPT 的"2-3 内置 skill"步）：
  如 Markdown→Doc、Failure Certificate 根因。Skill 状态仅 {draft,
  awaiting_activation}——无 activated case（类型层面=tape 门控，与 A1_18 同族）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 10
predicates:
  - "SkillMD 解析确定性 ×2；SkillStatus 无 activated case（类型不可表示 + 测试）"
  - "未声明 action_classes → fail-closed class_3（复用 A1_21，负控 fixtures）；frontmatter 缺 required → 校验 fail"
  - "2-3 official skill 模板 = 数据非激活（grep 无 activate/入带路径）；零持久化/零入带（负控）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "SKILL.md 已是开放标准（2025-12-18，32 工具支持）= A1_13 已核（FEASIBILITY Part IV-3）；本 atom 不新增外部论断"
    source: "FEASIBILITY.md Part IV + research/R_v05_protocol_live_sources.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（无 activated case 追踪、fail-closed 复用 A1_21、确定性 ×2、零入带）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
