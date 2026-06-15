---
atom: A1_56_daemon_reconnect
phase: "1"
depends_on: ["A1_38_uds_transport", "A1_50_branch_relationship_facts"]
intent: >
  真机实证反馈 #4：daemon 流断开后 app 永不重连。根因(调研 wf_cc0c719c 高置信实锤)：
  `UDSClient.disconnect` 设计为终态(generation bump 围栏),唯一的有界重试只覆盖**首次 connect()**
  的瞬时 errno(ENOENT/ECONNREFUSED),**不覆盖连上之后的 EOF/close**;而 daemon 是**故意关流
  等客户端重连重放**的(uds.rs:403-408,418-422)。检测半边是诚实且正确的(RadarMood 变灰 + 断连
  banner,A1_50);**恢复半边整个缺失** —— 没有任何组件负责"流断了之后重连"。

  **修复(恢复半边,不碰检测/诚实)**：
  1. **GlanceStore 加重连督导**(它已持 client + 消费状态流;UDSClient 不动,保住顺序/代次不变式)：
     消费循环见 `.state(.disconnected)` 且**非用户主动 stop** → 有界退避(0.5→1→2→4→8s 封顶,
     jitter)排程重连;每次先 `DaemonController.socketIsLive(path)` 探活才 `client.connect()`
     (updates 是长寿 AsyncStream、disconnect 不 finish 它、connect() 重置 lastSeq+daemon 全量重放
     → 同一 client 直接重连即得一致投影,无需特殊重放逻辑)。`.state(.connected)` → 退避计数归零。
  2. **可选 daemon 重生(注入,不耦合)**：app 经构造注入 `ensureDaemon: () -> Void`(= daemon.ensureRunning),
     督导在 socket 死时先调它再连;GlanceStore **不 import DaemonController**(coupling 留在 app 装配层)。
  3. **手动「重连」affordance**：断连 banner 上一个按钮 → `GlanceStore.reconnect()`(退避归零 + 立即
     socketIsLive-gated 尝试)+ 一句模板白名单引导语。三定律:健康时静默,断连时一句话 + 一个 tap。

  **fail-visible 铁律(承 macOS-27 NWConnection→BSD AF_UNIX 教训 A1_38)**：重连窗口状态恒为**可见的
  .connecting/.disconnected**,绝不吞 .waiting;每次失败原文带 errno(attemptConnect 已如此);退避有界
  后转入清晰标注的"仍断连·可重连"而非无限静默转圈(本卡用慢速持续重试自愈 + 手动按钮,不留死局)。
  **诚实律不变**：disconnected/reconnecting 全程保持灰 + banner,只有真 `.connected` + 首个重放回执到才翻 live=true;绝不自动隐藏失败。
allowlist:
  - "app/Sources/TuringOS/GlanceProjection.swift"
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Sources/TuringOS/TuringOSApp.swift"
  - "app/Tests/TuringOSTests/GlanceProjectionTests.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "specs/atoms/A1_56_daemon_reconnect.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;app lane 真 swift build+test+bundle;过门前 pkill 'turingosd serve')"
  - "重连督导测(有 teeth)：驱动 update 流 connected→.closed(daemon 关流)→断言**有界次数**的重连尝试触发、每次都被 stub 的 socketIsLive 把门(socket 死=不 connect、socket 活=connect);`.connected` 重置退避;**用户 stop() 抑制重连**(reason 区分);注入的 ensureDaemon 在 socket 死时被调"
  - "fail-visible 测：重连窗口 connection 恒为可观测 .connecting/.disconnected(枚举断言),绝不出现吞掉的 .waiting/静默态;失败 reason 非空带因由"
  - "诚实律不变测：disconnected+reconnecting 全程 RadarMood.live==false ∧ banner 非空(承 A1_50 mood 不变式);只有真 .connected 才 live==true(不自动隐藏失败)"
  - "手动重连测：reconnect() 退避计数归零 + 触发一次 socketIsLive-gated 尝试;引导语经 Sentences 模板白名单(无 free-form 字符串,grep 断言 banner/guidance 文案来自 Sentences)"
verified_external_facts:
  - fact: "UDSClient.updates 是 init 一次性建的长寿 AsyncStream(UDSClient.swift:87);disconnect(:215-219) 只 yield .state(.disconnected) **不 finish 外层 continuation**(仅内层 per-connection signalCont.finish() at :198)→ GlanceStore 消费循环跨 connect/disconnect 不退出;connect()(:101-106) bump generation+lastSeq=nil+yield .connecting+attemptConnect,可安全再调,daemon 全量重放。故重连督导放 GlanceStore、UDSClient 零改动。"
    source: "调研 wf_cc0c719c daemon-reconnect finding(grep + 读 UDSClient.swift/GlanceProjection.swift/uds.rs 实证)"
    verified_on: "2026-06-15"
ux_touchpoints: >
  断连时:galaxy 保持灰 + 诚实 banner(不变),banner 上多一个安静的「重连」按钮 + 一句引导;
  自动有界退避重连(socketIsLive 把门),daemon 回来即自愈翻 live。真机验证(机器现已解锁):
  kill daemon → 见断连 banner → 见自动重连(或点按钮)→ daemon 回来后 galaxy 复活变彩色。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## GlanceStore(GlanceProjection.swift)— 督导
- 存 `socketPath`、`ensureDaemon: (() -> Void)?`、`reconnectTask: Task<Void,Never>?`、`reconnectAttempt`、`userStopped`。
- 消费循环 `.state` 分支:`.connected` → attempt=0、清 reconnectTask;`.disconnected(reason)` → 置 connection;若 `!userStopped && reason != 用户stop标记` → `scheduleReconnect()`。
- `scheduleReconnect()`:取消旧 task;spawn `Task { sleep(backoff(attempt)); guard !userStopped; if !socketIsLive(path) { ensureDaemon?() ; sleep 短 }; if socketIsLive(path) { client.connect() } else { /* 留 .disconnected,下一轮再排 */ recheck-loop } ; attempt = min(attempt+1, cap) }`。backoff = min(0.5 * 2^attempt, 8.0) + jitter。
- `stop()`:userStopped=true、取消 reconnectTask、disconnect。
- `reconnect()`(手动):userStopped=false、attempt=0、立即一次 socketIsLive-gated connect(socket 死则先 ensureDaemon)。

## RadarViews — 手动按钮 + 引导
- MoodBanner 区(断连时)加一个安静玻璃「重连」按钮 → `store.reconnect()`;旁一句 Sentences 引导语。

## RadarModel(Sentences)— 模板白名单
- 加 `Sentences.reconnectHint()`(引导语)若需;重连尝试窗口复用现有 .connecting → `Sentences.reconciling()`,不新增 ConnectionState 枚举(避免契约涟漪)。

## 验证
- 机械:上述督导/fail-visible/诚实/手动测 + shipgate p1。
- 真机(机器已解锁):kill daemon→断连 banner→自动重连/点按钮→daemon 回来 galaxy 复活。截屏存证。
