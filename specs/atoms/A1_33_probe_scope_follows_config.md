---
atom: A1_33_probe_scope_follows_config
phase: "1"
intent: >
  computer-use 真实测试发现的最后缝隙：SystemFacilitatorProbe 默认探
  MetaAIConfig.defaultCredentialScope（旧常量 meta_ai_api_key），而 A1_32 后
  key 存于当前配置 scope（deepseek-api）→ key 已入库但重启后 Facilitator
  仍判降级。修复：probe 默认 scope 跟随 MetaAIConfigStore.load().credentialScope
  （当前配置即真相；用户自定义配置同样被跟随）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "SystemFacilitatorProbe() 默认 metaAIKeyScope == MetaAIConfigStore.load().credentialScope（机械断言）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "缝隙由 computer-use 真实 GUI 测试发现（key 已存 deepseek-api 条目，Keychain security 工具独立确认；probe 源码读 defaultCredentialScope=meta_ai_api_key）"
    source: "FacilitatorRuntime.swift:51 + security find-generic-password 输出"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

架构师直接实现（一行语义修复 + 测试）→ shipgate → 回执 → 合 main。
