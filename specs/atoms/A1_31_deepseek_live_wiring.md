---
atom: A1_31_deepseek_live_wiring
phase: "1"
intent: >
  用户裁决 2026-06-12：Facilitator AI = deepseek-v4-flash（thinking disabled），
  Meta AI = deepseek-v4-pro（thinking enabled），同一 API key，OpenAI 兼容 wire。
  接线四件（A1_22 Gateway 的预留注入点全部落地）：
  (a) GatewayRequest.thinkingMode 可选字段（enum {enabled, disabled}，加字段=
  向后兼容，contracts 演进规则 2）+ OpenAI codec 编码 {"thinking":{"type":...}}
  仅当非 nil（golden 断言两形状）+ 响应 reasoning_content 容忍（解码不抛）；
  (b) LiveURLSessionTransport：ModelTransport 协议的 URLSession 实现（live 域，
  测试零网络——协议注入，mock 测）；
  (c) FileTapeSink：TapeSink 协议的 shell 侧 JSONL appender（append-only，
  位于 Workspace 支持目录；record 形状 == contracts/model_call.schema.json，
  测试读真实 contracts 断言 14 required 键；I8 不变量保持：无 sink 仍
  tapeUnavailable——A1_22 负控测试不回归）；
  (d) DeepSeekPresets：facilitator → (deepseek-v4-flash, thinking=disabled)、
  meta → (deepseek-v4-pro, thinking=enabled)，baseURL https://api.deepseek.com
  /chat/completions；key 经 KeychainStore credentialScope（I9：key 仅入
  transport header，零持久化于代码/记录/投影——负控 grep 无 sk- 模式）。
  实证依据：模型名/参数/响应形状 2026-06-12 真 key probe 验证
  （FLASH_OK 无 reasoning / PRO_OK 有 reasoning_content）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 6
predicates:
  - "golden：flash+disabled 与 pro+enabled 两种请求体字节断言（thinking 字段形状）；thinkingMode=nil → 请求体无 thinking 键（向后兼容字节不变）"
  - "FileTapeSink append 产物逐键覆盖 model_call.schema.json 全部 14 required（运行时读真实 contracts 文件断言）；append-only（二次 append 不重写首行）"
  - "无 TapeSink ⇒ send() 必抛 tapeUnavailable（A1_22 负控不回归）；测试零网络（URLSession 不在测试路径，全 mock transport）"
  - "key 零泄漏负控：grep 'sk-' app/Sources/ app/Tests/ fixtures/ 零命中；record/log 无 authorization 字段"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "DeepSeek API：模型 deepseek-v4-flash / deepseek-v4-pro；thinking 参数 {\"thinking\":{\"type\":\"enabled\"|\"disabled\"}}；OpenAI 兼容 base https://api.deepseek.com；deepseek-chat/reasoner 2026-07-24 弃用；响应思考内容在 reasoning_content"
    source: "https://api-docs.deepseek.com/zh-cn/ + /guides/thinking_mode（WebFetch）+ 真 key 双 probe（FLASH_OK/PRO_OK）"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Workflow：Sonnet 实现 + 3 路并行对抗验证（golden 独立复核 / schema 14 键
   独立复核 + I8 负控 / key 泄漏狩猎 + 零网络证明）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main。
