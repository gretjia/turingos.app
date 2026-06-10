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
  - "cargo test --manifest-path daemon/Cargo.toml uds_"
  - "cargo test --manifest-path daemon/Cargo.toml projection_"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "std UCred 分平台（Linux SO_PEERCRED / Apple 专有 impl）；macOS xucred 只可靠给 uid/gid，pid 需 LOCAL_PEERPID（UNVERIFIED，待 macos-26 CI 实测）"
    source: "research/R1_memo.md §5"
    verified_on: "2026-06-10"
  - fact: "tokio::net::UnixStream::peer_cred() 在 macOS 上 uid/gid/pid 全部可得（pid 即 LOCAL_PEERPID 路径）——本机 macOS 真实 socket 实测 PASS（uds_peer_cred_uid_and_pid，cfg 同时断言 linux/macos）；R1 UNVERIFIED #6 本机销项，macos-26 CI rust lane 持续复证"
    source: "daemon/tests/uds_subscription.rs（本机实测）"
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

## 修订记录（留痕）

- 2026-06-10 本地执行 agent：原 predicate `cargo test ... uds_ projection_` 不可执行
  （cargo 拒绝第二个 TESTNAME 位置参数），拆为两条等价 predicate。
- 2026-06-10 本地执行 agent：macOS peer-cred pid 实测可得（tokio UCred.pid() = Some），
  PeerAuth 不需要 cfg 占位——SameUid 直接用 uid 对比即跨平台成立；pid 平台断言进集成测试。
- 2026-06-10 S-stage 对抗双审裁决落地：①rebuild_command/derive_source 名不副实（不存在的
  --replay flag + 硬编码 git）→ DeriveSource 枚举参数化，rebuild 文案与来源强绑定；
  ②RowDigest 漏 locked 等字段 → 漂移判据改为 WorktreeDiscovered payload 本身（单一真相源）；
  ③对账线程 panic 静默冻结 → 监督线程重启 + 可见 stderr；④空转 marker 无界增长 →
  retained log 合并连续 idle marker（live 心跳保留，seq 独立计数保证严格递增）；
  ⑤守恒测试自证 → 增补独立手写 tally 外部金标；⑥socket 0600 出生即正确的 umask 方案
  **实测后否决**（umask 进程全局：并行测试/继承给 git 子进程 → 0600 目录不可遍历，
  比原 info 级窗口更危险；维持 bind→chmod + peer-cred 双锁，理由入代码注释）。
- **登记债务（不在本卡 allowlist/范围）**：(a) retained log 仍随真实 drift 单调增长，
  完整解 = snapshot+tail 重放协议 + 落盘游标，归 P1 收尾或 A1_04 后评估；
  (b) `serve` 子命令待补登 docs/CLI_ABI.md 命令清单（文档不在本卡 allowlist）；
  (c) replay 全量 clone 在持锁期间发生，订阅高频时阻塞 publish——与 (a) 同解。
