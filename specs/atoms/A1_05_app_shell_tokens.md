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
  - fact: "Network.framework NWConnection 对 UDS（NWEndpoint）的支持 UNVERIFIED——本卡第一步实测；失败降级 = BSD socket 薄封装（POSIX read loop）"
    source: "design/V6_RECONCILIATION.md §3（待实测销项）"
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
