---
atom: A1_25_se_signer_touchid
phase: "1"
intent: >
  白皮书 §9/§13.2 正文落地（能力≠仪式）：SE-P256 签名器 + Touch ID 门控的
  信封签名能力。(a) EnvelopeSigner 协议（ADR-013 daemon signer.rs 同构的
  Swift 侧抽象）+ SecureEnclaveSigner（kSecAttrTokenIDSecureEnclave +
  .privateKeyUsage + .biometryCurrentSet，FEASIBILITY 已核 API；SE 不可用 →
  类型化 Unavailable，fail-closed 永不静默回退）+ MockSigner（测试）；
  (b) 签名负载 = ApprovalEnvelopeDraft 的规范化字节（sortedKeys）——所见哈希
  已在负载内（A1_23 绑定）；产物 = signature_receipt 形状记录（对照
  contracts/signature_receipt.schema.json required 键）；(c) A1_23 builder
  修订：required_signature_level = f(签名器可用性探针)（注入式，调用方仍不可
  任意指定；SE 可用 → touch_id_se 可声明，否则 app_approval——能力到了才可
  声明，与 A1_23 同一原则的正向半边）；(d) 仪式记录（receipt 入带）仍等
  runtime tape——签名能力与记录义务分离，签名器产物只返回不持久化。
  CI 无 SE/生物识别：全部测试走 Mock；真 SE 路径 XCTSkip 守护（这同时是
  FEASIBILITY Part III 第 1 项实证的前置工程）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "SE 不可用 → 类型化错误（无静默回退，ADR-013 M2 fail-closed 负控）；测试零真 SE 依赖（Mock + XCTSkip）"
  - "签名负载 = 信封规范化字节（含 visible_card_hash）；receipt 形状覆盖 signature_receipt schema required 键（运行时读真实 contracts 文件）"
  - "builder 修订后调用方仍不可任意指定 signature level（level=f(探针)，负控测试）"
  - "零持久化/零入带（grep 负控）；MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "SE P-256 + .privateKeyUsage + .biometryCurrentSet + 指纹重录作废 = A1_11 已核（FEASIBILITY Part I）；本 atom 不新增外部论断"
    source: "FEASIBILITY.md Part I + research/R_agentic_os_sources.md"
    verified_on: "2026-06-11"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（fail-closed 负控、receipt schema 键独立复核、
   level 不可任意指定追踪、CI 安全证明）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
