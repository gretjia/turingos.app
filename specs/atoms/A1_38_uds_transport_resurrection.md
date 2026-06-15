---
atom: A1_38_uds_transport_resurrection
phase: "1"
intent: >
  E2E 真机测发现的致命连通 bug 修复（app 壳层 I/O，Class 1 plumbing，非 §6 受限面、
  非宪法 trust-root —— 宪法 manifest 只钉 runtime/ Rust 内核，app/Sources 不在内）。
  现象：app 主屏永远停在「正在对账…」、orb 灰、雷达只剩星点无星云无节点，全 app
  数据饿死 = 用户报告的「完全不可用」。
  根因（真题真跑定位，非静态评审）：
  (1) UDSClient 用 `NWConnection(to:.unix, using:.tcp)`（V6_RECONCILIATION §3 明文标注
      "本机 UNVERIFIED"的写法）在 macOS 27 (Darwin 27.0) 卡在 .waiting；而 handleState
      只处理 .ready/.failed/.cancelled，把 .waiting 吞进 `default: break` → 连接态永远
      停在 .connecting（AttentionModel 证明「正在对账…」唯一对应 .connecting），既不报错
      也不重试，违反 app 自身「fail-visible 永不静默」原则。daemon 本身健康（直连 UDS
      实测在吐真实事件，seq 已到 5465）。
  (2) GitConnect.SystemProcessRunner.run 顺序 readDataToEndOfFile(stdout) 再 stderr →
      子进程 stderr 撑满 64KB pipe 缓冲时死锁；且无 wall-clock 上限，gh 挂起则调用方
      永久卡住（onboarding「接入」按钮永远 disabled）。
  修复：
  (1) UDSClient 传输层换成 BSD AF_UNIX SOCK_STREAM（V6_RECONCILIATION §3 已预授权的
      降级方案；DaemonController.socketIsLive 已证 BSD unix connect 在本机工作）。保持
      全部不变量：state+event 单一全序流（用 FIFO AsyncStream 单消费者保证字节序）、
      generation 栅栏、LineBuffer 分帧、seq 严格递增门。connect 失败/EOF/读错 一律
      fail-visible 落 .disconnected(reason)，永不再吞。fd 单一所有者 = DispatchSource
      cancelHandler（无 double-close）。--probe 路径同享此修复（probeMain 复用 UDSClient）。
  (2) GitConnect 并发抽干 stdout/stderr 两管道 + 子进程 wall-clock 超时终止。
  净效果：app 连得上自己的 daemon，雷达自动 populate voiceink+turingos_app 的 worktree，
  orb 转出灰态，只读 Observe 链路恢复可跑。
allowlist:
  - "app/Sources/TuringOS/UDSClient.swift"
  - "app/Sources/TuringOS/GitConnect.swift"
  - "app/Tests/TuringOSTests/UDSTransportTests.swift"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 1
predicates:
  - "bash scripts/build_app.sh 全绿（swift build+test+bundle + 真线 wire-probe 收到真 envelope；executed >= MIN_TESTS）"
  - "bash scripts/shipgate.sh p1 全绿（含 16 app lane）"
  - "新回归测试 UDSTransportTests：真 AF_UNIX listener 喂 N 条 JSONL → UDSClient 先 .connected 再按序 N 条 .event；连不存在的 socket → 立刻 .disconnected(reason)（不卡 .connecting）；SystemProcessRunner 对 >64KB stderr 不死锁且全量捕获"
  - "真机复观（真题真跑，截图为证）：open dist/TuringOS.app 后连接到达 .connected —— orb 非灰、雷达渲染出 voiceink+turingos_app 的节点/星云（不再「正在对账…」空白）"
verified_external_facts:
  - fact: "NWConnection(to:.unix,using:.tcp) 在 macOS 27 (Darwin 27.0) 运行 app 中卡 .waiting，handleState default:break 吞之 → 永停 .connecting；daemon 直连 UDS 实测健康（ProjectRegistered/WorktreeDiscovered/DiffSnapshot/ReconciliationCompleted，seq→5465）；BSD AF_UNIX connect 在本机工作（socketIsLive 同款代码 + 本会话 python 探针即时收到事件）"
    source: "本会话 2026-06-14 真机诊断（截图 + 直连 UDS 读流 + AttentionModel:269 状态映射 + UDSClient:93 default:break）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  Glance（菜单栏点 + 一句话）、Orb 主屏内嵌投影、Worktree Radar、Attention Stack —— 全部
  依赖 GlanceStore 的 connection/ledger；本卡修复前它们一律灰/空。失败时用户看到的是
  fail-visible 的 .disconnected 句子（「daemon 断连——<reason>」）而不是永久「正在对账…」
  假活态。GitConnect 修复触及 onboarding Connect 时刻。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路（非强制草图）

## UDSClient（传输层替换，公共 API 与不变量不变）
- 删除 `import Network` + NWConnection；改 `import Darwin`。
- `connect()`：bump generation → teardown → 清 lineBuffer/lastSeq → yield .connecting →
  `socket(AF_UNIX,SOCK_STREAM,0)` + sockaddr_un（镜像 Workspace.socketIsLive 的填充）+
  `connect()`。任一失败 → yield .disconnected(reason: errno 文案)，return（fail-visible）。
  成功 → 设 O_NONBLOCK → `DispatchSource.makeReadSource` 在专用 queue。事件处理器把当次
  可读字节抽干成一个有序 chunk，通过 **FIFO `AsyncStream<ReadSignal>`** 交给**单一消费者**
  Task（保证字节序 → LineBuffer 重组与 seq 门看到的是真实顺序，杜绝多 Task 乱序）。
  cancelHandler 是 fd 的**唯一**关闭者（杜绝 double-close）+ finish 信号流。yield .connected → resume。
- `handleSignal`：generation 守卫；.data → LineBuffer.append → decode EventEnvelope →
  seq<=prev 则 disconnect(stream integrity) → yield .event；decode 失败 disconnect(undecodable)；
  .closed → disconnect(reason)。
- `disconnect`/`teardown`：bump generation 栅栏 + cancel source（→关 fd+finish）+ cancel ioTask。
- LineBuffer 结构原样保留（已单测）。

## GitConnect.SystemProcessRunner.run（防死锁 + 超时）
- 两管道用并发 queue 各自 readDataToEndOfFile（DispatchGroup 汇合）—— 杜绝顺序读导致的
  64KB pipe 缓冲死锁。
- terminationHandler signal 一个 semaphore；`wait(timeout: deadline)` 超时则 terminate()
  子进程再收尾。返回 (status, out, err)。线程安全 DataBox（NSLock）承接两管道结果。

## 工序
单实现者（Opus 亲操，C 级流式不变量不降档）→ build_app + shipgate p1 → 真机 open 截图复观 →
清洁视角对抗复核（Critic 列举 / Witness 裁决）→ 架构师终审回执 + 提交。
