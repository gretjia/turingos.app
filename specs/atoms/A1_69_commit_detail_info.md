---
atom: A1_69_commit_detail_info
phase: "1"
depends_on: ["A1_57_detail_card_popover_content"]
adr: "(DESIGN 三定律 语言优先；ADR-017 honesty：只显观测事实)"
intent: >
  用户反馈(细节卡 #5 续,2026-06-15):
  ① **commit 节点 popover 应显示 commit 基本信息**（message/作者/日期），让用户知道"这个 commit 到底是什么意思、
     发生了什么",从而理解项目全貌。当前 commit popover 只显 sha8 + 所在分支,太薄。
  ② 颜色/字体轻度优化（用户原话"如果有时间的话"——次要、主观）。

  **根因(实锤)**:数据**已观测**——`CommitFact` 已带 `summary`(commit message)/`author`/`ts`,daemon `CommitObserved`
  已 emit 三者(branch_poller.rs:765-770/817-822,gh 取 `.commit.message`+author.name/.date)。唯一缺口:
  `RadarScene.derive` 构造 commit 节点时**丢弃**了 summary/author/ts(只传 sha/branch),故 popover 看不到。
  → 纯 **app 侧**修复,无需 daemon 工作,且**全诚实**(已在 tape 的观测事实)。

  **修复**:
  - RadarModel:加 `CommitMeta {summary, author, ts}` 值类型 + RadarNode 末尾 additive `commitMeta: CommitMeta? = nil`
    (默认 nil → worktree/branch 构造与既有调用点不变);commit 构造从 CommitFact 填 commitMeta。
  - `deriveCommit`:headline = commit message **首行(subject)** = "发生了什么"(语言优先);
    **body = message 余下正文(说明)**(用户反馈续:像 PR 一样要有说明)展示在 headline 下方(NodeCardContent
    加 `body: String?`);行 commit(sha8)+ 作者 + 时间(ts prefix10 日期)+ 分支。subject 空则回退"提交节点"。
  - RadarViews `detailPopover` **轻度视觉打磨**(语言优先 + Tokens 内,低风险):headline 升为主色更醒目的引导句、
    背景/描边与 chip 的 V6 glass 一致、间距节奏。**主观,走 RiskFinding 非 predicate。**

  **诚实**:summary/author/ts 是已观测 tape 事实;**commitMeta 不入 canonicalDump**(展示层,保 golden-free;
  如架构师要入 golden 另起 atom)。不动 scene 结构/positions/daemon。
allowlist:
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "specs/atoms/A1_69_commit_detail_info.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock)"
  - "golden 不变:commitMeta 加在 RadarNode 但**不入 canonicalDump**(deriveCommit 是视图层);fixtures/snapshots golden 逐字节不变(testSceneGoldenOverP1Fixture / testSameLeadgeSameCanonicalDump 仍绿)"
  - "**commit 内容测(机械)**:构造带 CommitMeta(summary 多行)的 commit 节点 → deriveCommit headline == summary 首行(subject),行含 作者/时间(日期 prefix10);commitMeta nil → 回退'提交节点'。branch/worktree derive 不受影响(既有测仍绿)"
  - "无回归:swift build+test 绿;既有 RadarNode 调用点(worktree/branch 构造)无需改(commitMeta 默认 nil);RadarNode Equatable 仍合成"
  - "**真机 UX 验证(我 computer-use)**:点 commit 节点 → popover 首行显 commit message(subject)、行显作者+日期+sha+分支,用户能看懂'发生了什么'。视觉打磨经 RiskFinding 目视(主观)。截屏 /tmp/galaxy_evidence/commit_*.png"
verified_external_facts:
  - "CommitFact 已带 summary/author/ts 且 daemon CommitObserved 已 emit(branch_poller.rs:765-770/817-822,gh .commit.message+author.name/.date)— verified_on 2026-06-15"
ux_touchpoints: >
  commit 节点 popover 显示 message(subject)/作者/日期 —— 用户能理解每个 commit 是什么、项目全貌;popover 视觉轻度打磨。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
## RadarModel.swift
- `public struct CommitMeta: Equatable, Sendable { summary; author; ts }`。
- RadarNode 末尾加 `public let commitMeta: CommitMeta? = nil`(默认 → 既有构造不变)。
- commit-node 构造传 `commitMeta: CommitMeta(summary: commitFact.summary, author: commitFact.author, ts: commitFact.ts)`。
- deriveCommit:headline = summary 首行(空→"提交节点");行 commit/作者/时间(prefix10)/分支。
## RadarViews.swift
- detailPopover 轻度打磨:headline 主色 ui13、glass 背景+描边、间距;低风险、Tokens 内。
## RadarModelTests.swift
- 更新 commit case(带 CommitMeta 断言 subject headline + 作者/时间行)。
