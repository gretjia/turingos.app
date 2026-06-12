---
atom: A1_23_approval_envelope_builder
phase: "1"
intent: >
  执行裁决红线 2 的正主："先做 ApprovalEnvelope，再做漂亮 Touch ID UI"。
  合法子集 = 信封的构建与所见绑定（构建 ≠ 记录；仪式记录仍等 runtime tape）：
  (a) ApprovalEnvelope Swift 模型（镜像 contracts/approval_envelope.schema.json
  全部 20 个 required 键）；(b) ApprovalCardContent 规范化序列化 +
  visible_card_hash = sortedKeys 规范 JSON 的 sha256——与 A1_15 ApprovalCard
  渲染内容**绑定**（卡内容变 ⇒ 哈希变 ⇒ 信封失配，测试断言双向）；(c)
  ApprovalEnvelopeBuilder 纯函数（nonce/expiry 注入式，无 Date/UUID 内生）；
  (d) host_threat_level 只可 T0-T2（T3 → 构建拒绝，fail-closed）；
  required_signature_level v0.x = app_approval（touch_id_se/external_anchor
  为预留值，构建时拒绝——能力未到不冒充）。零持久化、零仪式记录。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "信封编码覆盖 schema 全部 20 个 required 键（运行时读真实 contracts 文件断言）"
  - "所见绑定双向测试：同卡 ⇒ 同 hash ×2；卡任一字段变 ⇒ hash 变 ⇒ 与信封失配可检"
  - "T3 / touch_id_se / external_anchor 构建拒绝（fail-closed 负控）；构建器纯函数确定性 ×2"
  - "零持久化/零记录（grep 负控）；MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；派生自 contracts/approval_envelope.schema.json、WHITEPAPER §9/§9.1、执行裁决红线 2"
    source: "contracts/approval_envelope.schema.json + docs/01_KERNEL_CONTRACTS.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（20 键独立复核、绑定双向负控、T3 拒绝路径追踪）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
