---
atom: A1_06_daemon_multi_repo
phase: "1"
intent: >
  daemon 多 repo 化（四次裁决反向塑形）：注册表文件（projects.json：project_id/path/
  来源 remote 元数据）驱动 N×Reconciler；事件按 project_id 隔离；聚合投影按 project
  分桶 + 全局 rollup，双层守恒测试；`turingosd serve --registry <file> <socket>` 与
  单 repo 形态并存。注册表热重载（fs-watch 或周期重读）= 新增/移除 repo 不重启。
allowlist:
  - "daemon/**"
  - "scripts/shipgate.sh"
max_new_files: 8
predicates:
  - "cargo test --manifest-path daemon/Cargo.toml registry_"
  - "cargo test --manifest-path daemon/Cargo.toml projection_"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "EventEnvelope payload 已携带 project_id（A1_02 起）；hub seq 全局单调（A1_03 next_seq），多 repo 共享一条流不破坏订阅契约"
    source: "daemon/src/snapshot.rs / uds.rs（本仓已合并代码）"
    verified_on: "2026-06-10"
ux_touchpoints: >
  Global Workspace 压缩卡的每 repo 健康度 = 分桶投影；全局 Glance 三计数 = rollup；
  注册表中无本地 clone 的条目投影为 gray "remote-only" 占位行。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

registry.rs：serde 结构 + 原子读取（损坏=可见错误不静默）+ 路径 canonical 化（R1 §2.a）；
EventHub 不变（全局单流），Reconciler 改为 per-project 实例集合由 registry 驱动；
projection.rs 增 per-project BTreeMap 分桶（apply 按 payload.project_id 路由）+ rollup
守恒 assert(rollup == Σ buckets == fold(log))；serve 子命令加 --registry 形态。
六边界测试复用 tests/common，多 repo 场景：两 repo 各自漂移互不串桶。
