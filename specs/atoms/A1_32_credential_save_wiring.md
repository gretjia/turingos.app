---
atom: A1_32_credential_save_wiring
phase: "1"
intent: >
  computer-use 测试前置缺口修补（A1_31 集成缝隙，代码审读实锤）：
  (a) CredentialFieldView 的 SecureField 无保存动作——输入的 key 哪儿也不去；
  接 onSubmit/保存按钮 → KeychainStore.save(service: payload.credentialScope,
  account: "api_key") + "已存入 Keychain" 视觉反馈（key 明文仍零回显/零日志）；
  保存逻辑经注入 saver 协议可测（测试不触真 Keychain）。
  (b) scope 统一：MetaAIConfigStore.load() 默认配置改为用户裁决的 DeepSeek
  预设（kind=openai_compatible, endpoint=DeepSeekPresets.endpoint,
  model=deepseek-v4-pro, credentialScope=DeepSeekPresets.credentialScope
  "deepseek-api"）——UI 卡显示的 scope 与 Gateway 读取的 scope 一字不差。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 2
predicates:
  - "默认 MetaAIConfig.credentialScope == DeepSeekPresets.credentialScope（机械断言）"
  - "保存动作经注入 saver 测试：submit → saver 收到 (service==scope, account==api_key, secret==输入值)；UI 状态变为已保存"
  - "key 明文零回显：保存后 secureValue 清空；无 print/log（grep 负控）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；缝隙由 A1_31 收尾后代码审读发现（ViewIRRenderer.swift CredentialFieldView 无保存路径；MetaAIConfig.defaultCredentialScope=meta_ai_api_key ≠ deepseek-api）"
    source: "app/Sources/TuringOS/ViewIRRenderer.swift + MetaAIConfig.swift + DeepSeekPresets.swift"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

架构师直接实现（小补丁）→ shipgate → 回执 → 合 main。
