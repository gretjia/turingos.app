---
atom: A1_21_capability_manifest_validation
phase: "1"
intent: >
  Capability Registry 的执法核心（合法子集，纯函数）：CapabilityManifest Swift
  模型（镜像 contracts/capability_manifest.schema.json）+ ManifestValidator
  （required/enum/结构校验，与 schema 逐字段对照）+ FailClosedClassifier
  （manifest → 动作类；缺失/无效 action_classes → class_3 或 deny——白皮书
  §13.8 / §7.3 节点 16 / 不可谈判项 19 的机械落地）+ escalation → 签名节点
  路由表。安装/升级/移除生命周期明确等 runtime tape（"安装入带"不可外壳暂记）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "无效/缺类 manifest → 分类结果 ∈ {class_3, deny}（fail-closed 负控 fixtures ≥3 个变体）"
  - "Validator 与真实 schema 文件逐 required/enum 对照（测试运行时读 contracts 文件）"
  - "零安装生命周期代码（grep install/remove 写路径为零）；纯函数确定性 ×2"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；派生自 WHITEPAPER §13.8、docs/03 §8、contracts/capability_manifest.schema.json"
    source: "contracts/capability_manifest.schema.json"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（fail-closed 负控独立构造、schema 对照独立复核）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
