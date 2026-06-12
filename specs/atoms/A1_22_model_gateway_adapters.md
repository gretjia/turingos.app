---
atom: A1_22_model_gateway_adapters
phase: "1"
intent: >
  Model Gateway 适配层（白皮书 §13.7 的合法子集）：三面请求/响应模型
  （OpenAI Chat Completions / Anthropic Messages / Apple FM 本地占位）+
  ModelCallRecordBuilder（机械覆盖 contracts/model_call.schema.json 全部 14 个
  required 键；privacy_mode=redacted ⇒ 内容换哈希 + replay_degraded=true 诚实旗）
  + 角色路由表（§5.6 判据清晰度律，纯查表）+ **fail-closed live-call 闸**：
  不变量 I8"ModelCall 必须入带"——tape sink 不存在 ⇒ send() 类型化拒绝
  （GatewayError.tapeUnavailable），与 A1_18/A1_21 同款"仪式不可用就是不可用"
  机械化。Gateway 是底层白盒管道，零放行裁决。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 10
predicates:
  - "无 TapeSink ⇒ send() 必抛 tapeUnavailable（负控测试）；测试零网络（URLSession 不在测试路径）"
  - "ModelCall 记录覆盖 schema 全部 14 个 required 键（运行时读真实 contracts 文件断言）；redacted ⇒ replay_degraded=true 且 content 字段为哈希"
  - "两面 wire 编码各有 golden 断言（Chat Completions / Anthropic Messages 请求形状）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "API 三面形状沿用 R_v05 论断库 B8（partially-verified 的三面框架）与官方 wire 常识；本 atom 不发真实请求、不新增外部论断"
    source: "research/R_v05_protocol_live_sources.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（tape-unavailable 负控、schema 14 键独立复核、
   redaction 诚实旗、零网络证明）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
