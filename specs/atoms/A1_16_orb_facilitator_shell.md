---
atom: A1_16_orb_facilitator_shell
phase: "1"
intent: >
  Sprint 1 第二颗：Dynamic Orb 第一屏壳 + Facilitator 运行时三分支检测（本地
  Apple FM 可用性 / API-key 云端 / 降级模板）+ 密钥安全入库（SecureField →
  Keychain，永不入日志/上下文）+ Meta AI 配置卡。Orb 状态机
  idle/listening/thinking/needs-ruling/degraded（docs/02 §2）；文字入口先行
  （语音后续）；所有呈现走 A1_15 View IR 渲染器与确定性模板（本 atom 不接真实
  模型调用——Model Gateway 是后续 atom）。既有 ContentView（radar/attention）
  降为可达的内核调试面，不作主导航（docs/02 §6）。FM 可用性检测必须协议化
  + 测试用 mock（CI 无 Apple Intelligence）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
max_new_files: 12
predicates:
  - "Orb 为第一屏（WindowGroup 首场景内容），传统侧栏/菜单不作主导航（grep 断言）"
  - "Facilitator 运行时检测三分支可测（协议 + mock）；降级路径产出 A1_15 模板投影"
  - "Keychain 写入路径存在且密钥明文在日志/tape/任何 print 中 0 次出现（grep 断言）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "Apple FM 可用性检测 API（SystemLanguageModel.availability）为 A1_11 已核事实（macOS 26 GA，运行时检查义务）；本 atom 不新增外部论断"
    source: "research/R_agentic_os_sources.md + FEASIBILITY Part I"
    verified_on: "2026-06-11"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现（读 docs/02 §1/§2/§4/§5/§7 + A1_15 的 ViewIR/TemplateProjections +
   既有 TuringOSApp/OnboardingView 风格）；FM 检测协议化防 CI 不可用。
2. Sonnet 对抗核验（自跑 app lane；负控：密钥明文 grep；降级路径真实触发；
   场景顺序回归 A1_10 教训——WindowGroup 必须先于 MenuBarExtra）。
3. 架构师终审 → shipgate → 回执 → PR（堆叠 A1_15 分支）。
