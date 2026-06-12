---
atom: A1_36_ci_live_observation
phase: "1"
intent: >
  CI 观测真实闭环（A1_20 LiveRepoObservationSource 首次接通 UI）：handleInput
  的 ci/检查/check 意图 → 同步立即"检查中"占位卡（确定性）→ Task.detached
  后台跑只读观测（git/gh commands-as-data，A1_20 禁写谓词已固化）→ 主线程
  替换为 CIStatusProjection（真 PR/checks 数据）或 CIUnavailableNotice
  （无 PR/无 gh，诚实降级）。注入：ciObservationProvider 闭包（默认 nil =
  现状 CIUnavailableNotice；生产 = catalog 首个本地项目 →
  LiveRepoObservationSource）。零模型调用（CI 路径永不触 gateway）。
  routeBase 的 ci 分支保留（菜单兜底，A1_34 谓词不回归）。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 2
predicates:
  - "provider nil → 立即 CIUnavailableNotice（确定性 ×2），零 task"
  - "provider mock 有 PR → 占位卡先出现，异步替换为 CIStatusProjection（derive_source 含 pr 号）；无 PR → 诚实 notice"
  - "ci 路径零 gateway 调用（transport count==0 负控）；观测在 detached 上下文（不阻塞 MainActor）"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "无新外部论断；LiveRepoObservationSource 只读命令表 A1_20 已审（禁写 grep 负控在册）"
    source: "specs/atoms/receipts/A1_20_ci_observation_readonly.receipt"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

架构师直接实现（异步模式与 A1_34/35 同款，三连 Workflow 模式已成熟）→ shipgate → 回执 → 合 main → computer-use 终验。
