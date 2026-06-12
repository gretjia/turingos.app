---
atom: A1_30_menubar_no_sidebar
phase: "1"
intent: >
  用户裁决 2026-06-12：完全去除 left menu panel（ContentView 的
  NavigationSplitView sidebar），功能迁入 macOS 系统顶部菜单栏。
  Software 3.0 宪法相容性：主交互仍是 Orb（第一屏不变），菜单栏 =
  安静的 discoverability 逃生通道（docs/02 §6 逃生舱门设计），不是主导航。
  设计（架构师定稿）：CommandMenu("项目")=立项⌘N/连接仓库⌘O/项目总览⌘1；
  CommandMenu("视图")=Orb主屏⌘0/内核调试面⌘D（暗捷径升级为正式菜单项）/
  Radar/Attention/CI 各面板直达；CommandMenu("检查")=CI检查⌘R/Morning
  Ritual⌘M。通路=AppCommandBus（ObservableObject，菜单项 → bus → 视图
  响应，纯状态可测）。ContentView 改造：去 NavigationSplitView，detail
  全屏，面板切换走菜单+CommandBus；NavItem enum 保留（面板 switch 复用）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 4
predicates:
  - "grep -c NavigationSplitView app/Sources/TuringOS/*.swift == 0（sidebar 完全去除）"
  - "OrbView 仍是 onboarded 第一屏（现有测试不回归）；WindowGroup 仍先于 MenuBarExtra（A1_10 教训）"
  - "AppCommandBus 纯状态可测：每个菜单命令 → 预期面板/动作状态（枚举完整性测试）"
  - "⌘D 快捷键保留（菜单项 keyboardShortcut 断言或源码 grep）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "SwiftUI .commands/CommandMenu/keyboardShortcut 为既有稳定 API（项目内 MenuBarExtra 已在用 Scene 级 API；A1_05/A1_10 验证过 Scene 组合行为）"
    source: "app/Sources/TuringOS/TuringOSApp.swift 既有代码 + A1_10 receipt"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Workflow：Sonnet 实现 + 3 路并行对抗验证（grep 负控+真跑 / 设计契约核对 /
   回归狩猎：第一屏、A1_10 WindowGroup 次序、⌘D、MenuBarExtra dot）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main。
