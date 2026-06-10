---
atom: A1_01_daemon_scaffold
phase: "1"
intent: >
  存在可构建可测试的 Rust daemon 骨架（daemon/ workspace，turingosd bin + 模块化 lib），
  Linux 与 macos-26 双 CI lane 跑 cargo build/test/clippy/fmt，shipgate p1 接线。零业务逻辑。
allowlist:
  - "daemon/**"
  - ".github/workflows/**"
  - "scripts/shipgate.sh"
max_new_files: 10
predicates:
  - "cargo test --manifest-path daemon/Cargo.toml"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "macos-26 arm64 runner GA, Xcode 26.5 preinstalled"
    source: "https://raw.githubusercontent.com/actions/runner-images/main/images/macos/macos-26-arm64-Readme.md"
    verified_on: "2026-06-10"
ux_touchpoints: >
  none - 纯脚手架；但 CI 徽章是贡献者的第一个"证据界面"。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

cargo workspace：`daemon/`（bin turingosd + lib core 模块占位 events/snapshot/uds）；版本钉 PINS；
rust.yml workflow（ubuntu + macos-26 矩阵）；shipgate p1 = p0.5 全部 + cargo gates 存在性检查。
ADR-013 预留：core 里先放 `signer` 模块的 trait 定义骨架（无实现——P2 接线），让"业务只依赖抽象"从第一行代码成立。
