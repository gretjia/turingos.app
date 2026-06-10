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

## 修订记录（留痕）

- 2026-06-10 范围裁决：registry 模式 V0 不带 per-repo fs-watch（多 watcher 生命周期归
  P1 收尾债务；周期对账即 canonical——ADR-010）。
- 2026-06-10 S-stage 对抗双审落地（双 critic 全部带活体探针；Veto PASS）：
  ① [blocker] 同 id 换 path 静默错绑（or_insert_with 丢弃新 path）→ repoint 检测：
  retire 旧绑定 + 桶驱逐 + 重建 reconciler，回归 registry_path_repoint_rebinds_reconciler；
  ② [blocker] 移除项目留幽灵桶（project_ids 永久列出冻结计数）→ EventHub::retire_project
  驱逐桶（retire 事件先发后驱逐），回归 registry_removal_evicts_bucket_and_rereg_conserves；
  ③ [blocker] 同 path 双 id 击穿 rollup==Σbuckets（path 派生 worktree_id 全局碰撞 +
  retire 毒化幸存者）→ load_registry 强制 canonical path 唯一，回归含 symlink 别名用例；
  ④ [blocker] 跨项目 idle marker 合并破坏分桶守恒（稳态空转实测 bucket≠refold）→
  合并范围限定为「尾部 idle 连串内本项目的上一条 marker」：空转日志有界（≤1 marker/项目）
  且守恒保持，回归 registry_steady_state_idle_buckets_conserve（6 空转 tick + 日志长度不变）；
  ⑤ [blocker] 守恒唯一测试未覆盖稳态空转（false pass）→ 上述回归补齐；
  ⑥ project_id 提取表达式双处复制（paired-path drift 隐患）→ 收敛单一 event_project_id
  helper（桶路由/守恒重折叠/idle 限定三处共用）；
  ⑦ RegistryTickStats 生产路径消费：reconcile_errors>0 时 stderr 健康行；
  ⑧ WorktreeRemoved 两发射点 payload 形状统一（in-tick 补 reason="worktree gone"）。
- **登记债务**：(a) runner panic 重启 = 全量 re-announce/re-discover 风暴（seq 单调、
  payload 幂等，订阅端 latest-wins 语义无害但有放大面）——重启自愈状态重建（从 retained
  log 恢复 dedup）归 P1 收尾；(b) 分桶的 active_sessions/pending_proposals 在当前发射
  集合下结构性为 0（AgentSession*/Proposal* 事件尚无 project_id 载体，P5+ 接线时附带）——
  UI 压缩卡 P1 只渲染 anomalous 一项为活数，另两计数标 inferred/未接线，防止假活数。
