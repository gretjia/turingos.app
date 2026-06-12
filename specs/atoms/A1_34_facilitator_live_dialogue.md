---
atom: A1_34_facilitator_live_dialogue
phase: "1"
intent: >
  白皮书 §5.1/§6/§7 Facilitator 对话流的 live 点亮（lawful-now 合法子集，
  model call = shell 观测记录，零 Q 前进）：Orb 输入未命中确定性 IntentRouter
  路由时（现 fallback = intent-suggestions escape hatch），若 Facilitator
  runtime 可用（probe != degraded）→ 异步经 ModelGateway 调 Facilitator
  （DeepSeekPresets .facilitator = deepseek-v4-flash, thinking disabled）→
  响应文本渲染为 summary_card ViewIRDocument（红线 1：模型产出进 IR 块，
  永不 HTML/JS；derive_source 含 model_call 引用 + user_input）。Gateway
  生产组装 = FileTapeSink.defaultSink() + LiveURLSessionTransport（I8：每次
  调用入 shell tape JSONL）。失败（无 key/网络/超时）→ 回退 escape hatch +
  确定性错误行（fail-visible 不 fail-silent）。确定性路由命中时零模型调用
  （规则先行，§5.6）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 4
predicates:
  - "确定性路由命中（早/设置/立项/ci 等）→ 零 gateway 调用（mock 断言 invocation count == 0）"
  - "未命中 + Facilitator 可用 → gateway 收到 role=facilitator/model=deepseek-v4-flash/thinking=disabled 请求（mock transport golden）；响应文本出现在 summary_card 块且 derive_source 含 model_call 引用"
  - "未命中 + gateway 抛错 → escape hatch + 错误行（确定性，不崩溃）；无 key 时同路径"
  - "测试零网络（mock transport；LiveURLSessionTransport 零构造）；模型文本永不进 HTML/JS（结构上仅 summary_card body）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "DeepSeek wire/模型名已于 A1_31 实证（真 key probe）；本卡零新外部论断"
    source: "specs/atoms/receipts/A1_31_deepseek_live_wiring.receipt"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Workflow：Sonnet 实现 + 3 路对抗验证（零调用负控 / golden+IR 红线 / 失败路径+零网络）。
2. 架构师终审 → shipgate → 回执 → 合 main → computer-use 真实对话验证（真 DeepSeek 应答出现在 Orb）。
