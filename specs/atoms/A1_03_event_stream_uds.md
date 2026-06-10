---
atom: A1_03_event_stream_uds
phase: "1"
intent: >
  daemon 暴露 UDS JSONL 事件订阅端（socket 0600 + peer-cred 校验抽象 trait），
  维护常驻聚合投影（菜单栏三计数的数据源，带守恒测试），周期对账循环发
  ReconciliationCompleted。Linux lane 全测；macOS pid 取法 cfg 隔离待 CI 实测。
allowlist:
  - "daemon/**"
  - "scripts/shipgate.sh"
max_new_files: 8
predicates:
  - "cargo test --manifest-path daemon/Cargo.toml uds_ projection_"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "std UCred 分平台（Linux SO_PEERCRED / Apple 专有 impl）；macOS xucred 只可靠给 uid/gid，pid 需 LOCAL_PEERPID（UNVERIFIED，待 macos-26 CI 实测）"
    source: "research/R1_memo.md §5"
    verified_on: "2026-06-10"
ux_touchpoints: >
  菜单栏 Glance 的三计数恒时可信（反向塑形登记：常驻聚合投影非现算）；
  断连/重连状态必须可见（gray 未对账态）。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

tokio UnixListener；每连接 peer-cred trait 校验（PeerAuth trait：Linux impl 用 SO_PEERCRED，
macOS impl cfg(target_os) 占位 + CI 实测后补）；订阅协议 = 单向 JSONL 推送（contracts 信封）+
初始快照重放；聚合投影 = fold(events) 且 assert_eq!(投影, 全量重算) 守恒测试；
对账循环 = A1_02 快照 diff 上次状态 → 差异发事件。
