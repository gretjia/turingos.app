---
atom: A1_9_02_runtime_ci_and_boundary
phase: "1.9"
intent: >
  内核的宪法随内核迁居：runtime 的全部宪法门禁 + cargo test --workspace 成为本仓 CI 的
  runtime lane（ubuntu + macos-26，堵死 v4 原 CI 盲区）；门禁跑器 POSIX 兼容修复
  （审计已验证的 2 行补丁）；shipgate 新增：门禁基准数核点（==PINS 记录数，少一即红）、
  基线棘轮（例外红清单只缩不扩、每红绑 atom）、外壳边界 grep 谓词
  （daemon/app 代码 import runtime internals = FAIL）。
allowlist:
  - "runtime/scripts/**"
  - ".github/workflows/**"
  - "scripts/shipgate.sh"
  - "scripts/predicates/**"
  - "constitution/PINS.toml" # amended 2026-06-12: card intent says gate-count check "==PINS 记录数" — the baseline count lives in PINS by design; list omission was an oversight
  - "specs/atoms/CURRENT" # amended 2026-06-12: ship-cycle bookkeeping
max_new_files: 4
predicates:
  - "bash scripts/shipgate.sh p1.9"
verified_external_facts:
  - fact: "v4 原 CI 无任何 workflow 跑 cargo test --workspace（trust-root 红因此漏检）；门禁跑器 grep -oP 在 BSD grep 下挂，2 行 POSIX 补丁已验证（前后哈希存证）"
    source: "research/R1.9_memo.md §0.2 + audit_data/machine_sweep/baseline_step2b_patch_provenance.log"
    verified_on: "2026-06-11"
ux_touchpoints: >
  CI 徽章矩阵新增 runtime lane——贡献者第一眼即见"内核宪法在此执行"。
gate: "bash scripts/shipgate.sh p1.9"
---

# 代码思路

runtime-gates.yml（paths: runtime/**）：跑门禁套件 + workspace 测试，矩阵 ubuntu/macos-26；
shipgate p1.9 = p1 全部 + ①runtime 门禁数 == PINS 基准（含"1 占位门"诚实标注）
②例外红清单文件 scripts/predicates/baseline_exceptions.list（带 owning-atom 注释，棘轮：
本卡后只许删行）③边界谓词：rg 'use turingosd?.*runtime|use runtime::' daemon/ app/ = 0。
