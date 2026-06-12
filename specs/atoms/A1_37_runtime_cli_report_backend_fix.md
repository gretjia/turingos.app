---
atom: A1_37_runtime_cli_report_backend_fix
phase: "1"
intent: >
  E2E 真测发现的两个真 bug 修复（runtime/ CLI 域，Class 1 plumbing，非 §6 受限面）：
  (1) `turingos report wallet/positions/bankruptcy` shell-out 到 TASK_RUNNER_BIN
  常量 "lean_market"，但全仓无 lean_market 构建目标（自动发现，实际产物
  lean_market_agent）。report wallet 先 prepend "view-wallet" 子命令再 shell-out。
  → 决策树（real-run 仲裁，禁猜）：若 lean_market_agent（或任一已构建二进制）
  真能处理 "view-wallet" 子命令 ⇒ 改常量为正确名，real-run `report wallet`
  exit 0 证明；若无任何二进制处理 view-wallet ⇒ 常量非笔误而是命名未构建的
  Phase-6.1 后端，改 CLI help / QUICKSTART 如实标注"需另建后端"，不伪造常量。
  (2) QUICKSTART.md 8 处 Linux 旧机路径 /home/zephryj/projects/turingosv4/...
  macOS 导入后失效 → 改为 turingos.app/runtime 相对路径 + 标注此为导入副本。
allowlist:
  - "runtime/src/bin/turingos/common.rs"
  - "runtime/QUICKSTART.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "QUICKSTART.md 中 /home/zephryj 命中数 == 0（grep 负控）"
  - "runtime cargo build 干净；bash scripts/predicates/check_runtime_workspace.sh PASS（棘轮不破，无新红）"
  - "report-wallet 真测：CASE-A 改常量后 `turingos report wallet --repo <g0>/runtime_repo --cas <g0>/cas` exit 0 且印出 wallet 内容；CASE-B 若无后端处理 view-wallet，常量不改、help/QUICKSTART 如实标注，回执写明命中 CASE-B 及证据（哪个二进制不认 view-wallet 的原文）"
  - "bash scripts/shipgate.sh p1.9 全绿（19 门）"
verified_external_facts:
  - fact: "E2E 实测：TASK_RUNNER_BIN=\"lean_market\"（common.rs:74）无构建目标；产物 lean_market_agent；report wallet prepend view-wallet（cmd_report_wallet.rs）；QUICKSTART 8 处 /home/zephryj"
    source: "本会话 2026-06-13 E2E turingosv4 全流程真测"
    verified_on: "2026-06-13"
gate: "bash scripts/shipgate.sh p1.9"
---

# 工序

单 Sonnet 实现者（effort high）：调查 view-wallet 处理方 → 按决策树改 → g0 fixture
real-run 仲裁 → check_runtime_workspace + shipgate p1.9 → 回执。架构师终审回执 + 提交。
