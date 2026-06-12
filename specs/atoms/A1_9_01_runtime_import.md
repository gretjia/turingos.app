---
atom: A1_9_01_runtime_import
phase: "1.9"
intent: >
  完整版 turingosv4 @ PINS 钉定 rev 以 squash 单 commit 进入 runtime/（仓库内容逐字，
  含 src/tests/全部宪法门禁/scripts/frontend）；cargo workspace 接线（daemon 与 runtime
  并列成员，互不依赖）；既有外壳零改动。导入后 runtime 自身测试在本机跑绿（基线棘轮口径）。
allowlist:
  - "runtime/**"
  - "Cargo.toml"
  - "constitution/PINS.toml"
  - "specs/atoms/CURRENT" # amended 2026-06-12: ship-cycle bookkeeping (same as every other atom card)
  - "scripts/shipgate.sh" # amended 2026-06-12: import-inherent coupling — gate 10 dead-link check must declare the runtime/ jurisdiction boundary (verbatim-imported foreign legal domain carries 4907 historical dead links in v4 handover docs; its doc discipline is owned by its own 194-gate suite, not the shell's doc gates). Minimal change: exclude runtime/ prefix in gate 10 md scan.
max_new_files: 0
predicates:
  - "test -f runtime/Cargo.toml"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "锚点 rev 与新红编目以本地 Mac 锚点再验证 protocol 输出为准（U 项先行并入 v4 main）"
    source: "research/R1.9_synthesis.md 参数 0/2"
    verified_on: "PIN-AT-REVERIFICATION"
ux_touchpoints: >
  none——但导入即注定 P2+ 全部体验的真相底座；导入 commit message 是永久溯源锚。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

前置（v4 仓侧，非本卡范围）：U 项 PR → 锚点再验证 → 钉 rev 入 PINS（[runtime_port].anchor）。
本卡：`git read-tree --prefix=runtime/` 或 subtree add --squash 等价物导入钉定 rev；
顶层 Cargo workspace 把 runtime 与 daemon 并列（保留 runtime 自己的 workspace 配置与 exclude）；
max_new_files=0 的含义：除导入树与两处接线文件外不新增（导入树不计入预算——它是搬迁不是创作）。
执行位置：本地 Mac session（v4 访问权 + 体量）。
