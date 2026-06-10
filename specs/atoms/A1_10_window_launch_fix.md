---
atom: A1_10_window_launch_fix
phase: "1"
intent: >
  修复 D5 评审阻断：app 启动后 0 窗口（lsappinfo 实证 Foreground/0 windows，
  用户 open 后看不到任何界面）。根因假设：MenuBarExtra 声明在 WindowGroup 之前，
  SwiftUI 以首个 scene 为启动主场景导致主窗不自动打开。修复=场景重排（WindowGroup
  在前），以真实启动 + 窗口计数实证（real test beats review），不引入新功能。
allowlist:
  - "app/Sources/TuringOS/TuringOSApp.swift"
predicates:
  - "bash scripts/build_app.sh"
  - "bash scripts/shipgate.sh p1"
  - "launch dist app; osascript window count >= 1 within 5s"
verified_external_facts:
  - fact: "lsappinfo: type=Foreground 且 windows=0；进程存活无崩溃报告——非 Gatekeeper/签名/崩溃问题"
    source: "本机实测 2026-06-11 02:01"
    verified_on: "2026-06-11"
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

TuringOSApp.body 场景重排：WindowGroup 第一、MenuBarExtra 第二（功能不变）。
真实验证：构建 bundle → open → osascript 数窗口 ≥1 → 关闭。若重排不奏效，
回到调研（SwiftUI scene 启动语义官方文档）再修，不试错堆叠。
