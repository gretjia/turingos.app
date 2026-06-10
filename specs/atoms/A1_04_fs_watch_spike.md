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
