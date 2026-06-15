---
atom: A1_70_commit_body_capture
phase: "1"
depends_on: ["A1_69_commit_detail_info"]
adr: "(DESIGN 三定律 语言优先；ADR-017 honesty：只显观测事实；git 语义 %s=subject %b=body)"
intent: >
  用户反馈(细节卡 #7,2026-06-15):commit popover 有了主题,但 GitHub 上每个 commit 都有的"说明"(message 正文)
  始终看不到。**实证根因(读 daemon 实时 tape 钉死)**:daemon `branch_poller.rs:448`
  `let summary = message.lines().next()` 把 commit message **只取首行**,正文被丢弃 —— 从实时 tape 抽
  turingos_app 1107 条 CommitObserved,**0 条含换行**,全部截成主题行。故 app(A1_69)的 body 渲染代码正确,
  但收到的 `summary` 里从来没有正文。**非 build 问题,是 daemon 截断 bug。**

  **修复(诚实数据模型,非权宜)**:git 语义里 `summary`=subject(首行,%s)本就该是首行 —— daemon 命名没错,
  错在**正文从未承载**。故**加一个独立 `body` 字段**(message 首行之后、trim 后的正文,%b 语义),additive:
  - daemon `CommitFact` 加 `body: String`;parse 时 summary=首行、body=余下正文(trim);两处 CommitObserved
    emit(默认分支 commits ~770 / compare commits ~822)都带 `body`。
  - contracts `event_stream.schema.json` payload 是 `type:object`(无逐字段约束)→ 加 body 无需改 schema;
    fixture `commit_observed.jsonl` 给一条 commit 补 `body` 以演练新路径(additive,其余消费者忽略未知字段)。
  - app `AttentionModel.CommitFact` 加 `body`(decode `payload["body"] ?? ""`,缺省 → 向后兼容旧事件);
    `RadarModel.CommitMeta` 加 `body`;`deriveCommit` **改用 commitFact.body**(headline = summary 主题行直接用,
    不再"劈 summary"——A1_69 的劈法是基于"summary=全文"的错误假设,本原子纠正为真字段)。

  **诚实**:summary(主题)/body(正文)/author/ts 全是已观测 GitHub API 事实(gh `.commit.message`);
  body 缺省空串(commit 无正文 → body 为空 → app 不渲染说明块,诚实占位非伪造);**commitMeta/body 不入 canonicalDump**
  (展示层,golden 逐字节不变)。不动 scene 结构/positions/triage/价格。
allowlist:
  - "daemon/src/branch_poller.rs"
  - "fixtures/event_streams/commit_observed.jsonl"
  - "app/Sources/TuringOS/AttentionModel.swift"
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "specs/atoms/A1_70_commit_body_capture.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock)"
  - "**daemon 截断修复(机械)**:branch_poller 单测 —— 构造多行 message(subject\\n\\nbody paragraph) → 解析出 CommitFact.summary==首行 subject、CommitFact.body==trim 后正文;单行 message → body==''。两处 emit 的 payload 都含 body。"
  - "golden 不变:body 加在 CommitFact/CommitMeta 但**不入 canonicalDump**(deriveCommit 视图层);fixtures/snapshots golden 逐字节不变(testSceneGoldenOverP1Fixture / testSameLeadgeSameCanonicalDump 仍绿)"
  - "**app 内容测(机械)**:带 body 的 CommitMeta → deriveCommit body==正文、headline==summary 主题;无 body(空串)→ NodeCardContent.body==nil 不渲染说明块。branch/worktree derive 不受影响。"
  - "无回归:swift build+test 绿;rust fmt/clippy/test 绿;既有 CommitObserved 消费者(无 body 的旧事件)decode 不崩(body 缺省空串)。"
  - "**真机 UX 验证(我 computer-use 或用户)**:重启 daemon + app,点一个有正文的 commit 节点(如 53f7f209)→ popover 在主题下显示正文说明。截屏 /tmp/galaxy_evidence/commit_body_*.png;环境漂移则诚实代偿(同 detailPopover 机制已目视证实 + 机械测钉死)。"
verified_external_facts:
  - "daemon branch_poller.rs:448 summary=message.lines().next() 截断;实时 tape 1107 条 turingos_app CommitObserved 0 条含换行 — verified_on 2026-06-15(只读 socket 订阅实测)"
  - "GitHub commits/compare API .commit.message 含完整多行 message(gh 已取);mindsync 为空仓库(0 分支,API 409 Git Repository is empty)= 诚实空,非 bug — verified_on 2026-06-15"
  - "event_stream.schema.json payload=type:object 无逐字段约束 → 加 body additive 无需改 schema — verified_on 2026-06-15"
ux_touchpoints: >
  commit 节点 popover 在主题(headline)下显示 message 正文(说明),用户能读懂每个 commit 到底做了什么、为什么。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
## daemon/src/branch_poller.rs
- `CommitFact` 加 `pub body: String`。
- parse(~448):`let mut it = message.splitn(2, '\n'); let summary = it.next().unwrap_or("").trim().to_string();
  let body = it.next().map(|r| r.trim()).unwrap_or("").to_string();`(首行=subject,余下 trim=body)。
- 两处 emit(~770 默认 commits / ~822 compare commits):payload 加 `"body": commit.body`。
- 单测(~1120):多行 message → summary==首行、body==正文;单行 → body==""。
## fixtures/event_streams/commit_observed.jsonl
- 给一条 CommitObserved(如 merge commit)补 `"body":"..."`(additive)。
## app/Sources/TuringOS/AttentionModel.swift
- CommitFact 加 `public let body: String`;init 加 body 形参;decode `event.payload["body"]?.stringValue ?? ""`。
## app/Sources/TuringOS/RadarModel.swift
- CommitMeta 加 `body`;commit-node 构造 fold commitFact.body;deriveCommit 改用 commitMeta.body(headline=summary 主题直接用,删"劈 summary")。
- 注释 RadarModel:21 改为 `summary // commit subject(首行)` + `body // commit message 正文(说明),空串=无正文`。
## app/Tests/TuringOSTests/RadarModelTests.swift
- commit case:带 body 的 CommitMeta → headline==subject、body==正文;空 body → body==nil。
