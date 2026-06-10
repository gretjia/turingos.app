---
atom: A1_04_fs_watch_spike
phase: "1"
intent: >
  实证 notify crate 的分平台 watch 能力并接入 daemon：Linux inotify lane 单测全绿；
  macOS FSEvents backend 在 macos-26 CI 实测（R1 UNVERIFIED #6/#7 销项）。
  FileChanged 事件携带 hint_only=true 与 debounce 元数据（反向塑形登记落地）。
  失败降级路径：纯周期对账，契约不变。
allowlist:
  - "daemon/**"
  - ".github/workflows/**"
  - "research/R1_memo.md"
max_new_files: 5
predicates:
  - "cargo test --manifest-path daemon/Cargo.toml watch_"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "FSEvents 为递归监听正解（目录粒度 coalesced、latency 合并窗口、kFSEventStreamCreateFlagFileEvents 文件级）；notify crate FSEvents backend 能力 UNVERIFIED 待实测"
    source: "research/R1_memo.md §2.f"
    verified_on: "2026-06-10"
ux_touchpoints: >
  活动脉冲的"呼吸感"由 debounce 窗口参数决定（默认 800ms，进 payload 元数据）；
  hint_only 事件在 UI 永远是 blue 提示态，git 确认前不转 green。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

notify::RecommendedWatcher（Linux→inotify，macOS→FSEvents）+ 自实现 debounce 聚合层
（窗口可配，事件 payload 带 {hint_only:true, debounce_ms}）；watch 回调只置脏标记，
重活全在对账循环（与 R0/R1 纪律一致）；macOS CI job 跑真实文件写入→事件到达断言，
结果回写 R1_memo UNVERIFIED 清单（销项留痕）。

## 修订记录（留痕）

- 2026-06-10 本地执行 agent，S-stage 对抗双审裁决落地：
  ① critic 报告 `.git` 自激反馈回路（blocker）——**实证部分推翻**：本 daemon 的全部 git
  调用带 `--no-optional-locks`，实测 .git/index mtime 不变（critic 探针用的是 plain
  status）；但「外部 git 操作的 bookkeeping 冒充用户编辑脉冲」成立 → watcher 回调源头
  过滤 `.git` 组件路径 + 回归测试 watch_git_internal_churn_filtered（.git 写入零脉冲、
  真实编辑仍脉冲）。git 状态变化仍由 ≤2s 周期对账捕获。
  ② 无界 mpsc → sync_channel(1024) + try_send 溢出丢弃 + dropped_signals 计数进
  payload（hint 本就 best-effort，丢弃可见不沉默）。
  ③ FileChanged 在 retained log 无界累积 → EventHub::publish_hint 合并连续 hint
  （live 全保留，replay 只留最新；守恒不破，watch_hint_log_coalesces 钉死）。
  ④ Linux 上 source=fsevents 名实不符 → cfg 分平台（macOS=fsevents 真值；其余=daemon），
  **登记契约债务**：EventSource 需增通用 fs_watch/inotify 值（contracts minor，
  不在本卡 allowlist）。
  ⑤ 测试 300ms 固定 arm-sleep 颤抖面 → write_until_first_batch 重试式装填。
- 2026-06-10 实证补记：drop 顺序死锁（join 先于 watcher 析构）由真跑发现并修复，
  顺序语义入 Drop 注释。
