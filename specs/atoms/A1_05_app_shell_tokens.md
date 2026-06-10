---
atom: A1_05_app_shell_tokens
phase: "1"
intent: >
  SwiftUI app 骨架落地：Xcode 工程（deployment target macOS 26，本机经
  DEVELOPER_DIR=/Applications/Xcode-beta.app 用 27 SDK 构建，27-only API 源文件级隔离）、
  design tokens 单文件（V6 全量色值/字阶/动效 + 项目辨识色第二通道，VISUAL_SEMANTICS
  第 5-7 条合规）、UDS JSONL 订阅客户端（解码 EventEnvelope，断连=可见 gray 态）、
  MenuBarExtra Glance 骨架 + 主窗骨架。CI 增 app lane（runner Xcode 26.5，ADR-008）。
allowlist:
  - "app/**"
  - ".github/workflows/**"
  - "scripts/shipgate.sh"
  - "scripts/build_app.sh"
max_new_files: 24
predicates:
  - "bash scripts/build_app.sh"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "Xcode 27.0 beta (27A5194q, MacOSX27.sdk) 位于 /Applications/Xcode-beta.app；本机另无 stable Xcode（xcode-select 校正进本卡）"
    source: "本机实测 ls + defaults read"
    verified_on: "2026-06-10"
  - fact: "MenuBarExtra 最低 macOS 13.0+；Liquid Glass macOS 26 引入、27 精修多为 SDK 重编自动生效"
    source: "research/R1_memo.md §3"
    verified_on: "2026-06-10"
  - fact: "NWConnection(to: .unix(path:), using: .tcp) 走 UDS 全链路可用——Xcode 27 SDK
      (Swift 6.4) 编译最小客户端连真实 turingosd socket，收到并 JSON 解析真实
      EventEnvelope（kind=WorktreeDiscovered, schema=tos.app.event.v0）。UNVERIFIED 销项，
      无需 BSD socket 降级"
    source: "本机实测（swiftc + 真实 daemon serve，探针 /tmp/uds_probe.swift）"
    verified_on: "2026-06-10"
ux_touchpoints: >
  V6 设计 tokens 是全产品视觉法源（DESIGN.md 美学门禁化：单文件无散落魔数）；
  Glance 三计数绑 prj_glance_counts；断连/未对账永远可见 gray，不静默。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

app/ 新目录：Xcode 工程（手写 pbxproj 或 XcodeGen/SwiftPM-bundle 方案，开工时实测择优）；
DesignTokens.swift 单文件（语义六色 + 项目辨识色调色板避开六色值 + 字体注册 Inter/JetBrains
Mono OFL 打包）；UDSClient（actor，NWConnection 实测→降级 BSD socket；JSONL 逐行解码，
seq 严格递增断言，断连状态发布）；MenuBarExtra + 主窗 NavigationSplitView 骨架（十导航占位，
P1 外 disabled）。CI：app.yml 或并入 rust.yml 增 xcodebuild lane（macos-26 镜像 Xcode 26.5）。
shipgate 增 app 构建检（cargo 同款 fail-closed：无 xcodebuild 环境时 CI lane 负责，本地跳过须显式可见）。

## 修订记录（留痕）

- 2026-06-10 技术裁决：SwiftPM 工程取代手写 pbxproj（Xcode 直接打开 Package.swift；
  swift build/test headless 进 CI；bundle 由 build_app.sh 组装）；Inter/JetBrains Mono
  以名称+回退链引用，OFL 字体二进制打包延后 A1_08。
- 2026-06-10 S-stage 对抗双审落地（一名 critic API 断线，幸存者覆盖双镜头；Veto PASS）：
  ① [blocker] swift test 经 `tail -3` 只展示 Swift-Testing 的空摘要 = 法证假信号 →
  build_app.sh 改为全量捕获 + 断言 XCTest pass 行 + 最低执行数 MIN_TESTS=11（runner 漂移即红）；
  ② shipgate.yml 升级为双 OS matrix 跑 **p1**（CI 与 atom 卡 gate 完全一致；macOS lane 先建
  daemon → 第 16 检的 wire-probe 在 CI 真跑）；app.yml paths 补 scripts/shipgate.sh；
  ③ 近似值条款落地：accent 调色板重选（cyan/fuchsia/orange/lime/ice/sand），测试强制
  RGB 距离 accent↔语义 ≥72、accent 互距 ≥56（实测最小 77.3/63.7）；
  ④ UDSClient 改单一全序 updates 流 + generation 守卫（消灭双流 reset/replay 竞态与
  断连后旧回调泄漏；connect 可重入安全）；⑤ 删除死代码 Delivery；
  ⑥ Events 镜像松紧不对称（Rust 生产侧 deny_unknown / Swift 消费侧容忍增字段）裁定为
  **有意设计**并注释成文。
- RiskFinding 移交 A1_08 用户视觉评审：V6 原稿中 --tx-secondary 与语义 gray 同值
  （0x9CA3AF）——徽章依赖图标+文本双通道消歧（VISUAL_SEMANTICS 规则 3/4），是否调整由
  用户在视觉评审 checkpoint 裁定。
