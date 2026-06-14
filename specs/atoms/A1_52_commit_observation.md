---
atom: A1_52_commit_observation
phase: "1"
intent: >
  Git 观测机制建实第二颗（daemon 观测侧，galaxy commit 层的诚实底座；A1_50 分支关系观测的姊妹原子）：
  让 A1_47/A1_50 的 branch poller 在算 compare 时**顺带发 per-commit 观测**，把 galaxy 的可观测深度从
  「分支顶点」下探到「commit」。新增 CommitObserved 事件（additive 契约，contracts/README 演进规则 4）。

  **为什么需要它（实证，见 research/R1_infinite_zoom_memo.md §1）**：深读 daemon 实锤——今天 daemon 最深
  只观测到分支顶点，无 per-commit 事件、无 commit DAG。研究综述设计的 commit-graph 泳道因此无源可渲。
  ADR-016 裁决本轮补此原子。

  **有界 + 诚实（Art.0：只渲已观测、绝不伪造、绝不无界）**：
    - 非默认分支：emit 其 ahead-commits = compare 响应里**已有的** `commits[]`（base=default head=branch）——
      首轮**零额外 API**；GitHub compare commits **上限 250**，超出 → payload 标 truncated、**不补造**（fail-visible）。
    - 默认分支：emit 近 N 条主干脊柱（一次 `commits?sha={default}&per_page=N`，N=30；按 default_sha memoize）。
    - **cache-hit 幂等再发（对抗复核 wf_913b000f 实锤的设计洞）**：现 compute_merge() 在 (branch_sha,default_sha)
      未变时**命中缓存早返、不再跑 gh**——此时**没有**新 compare 响应可读 commits[]。BranchObserved 本就每轮幂等
      再发（memoize 只省 gh 调用、不省 emission）。故 **CachedCompare 加宽存 `Vec<CommitFact>`**：缓存命中时
      **用缓存的 commits 幂等再发 CommitObserved（零 gh 调用）**——与 BranchObserved 同步、app fold 幂等覆盖。
      绝不在 cache-hit 上静默丢 commit（否则 poll #2 起 galaxy 丢 commit 节点 = 假绿）。
    - compare/commits gh 失败 → 该分支 commit 不发（eprintln + 降级，never crash/fake，承袭 A1_47）。

  **范围 + 跨语言同步**：本卡 daemon 诚实吐 commit 观测 + **Swift EventKind 加 `.commitObserved`**（共享 fixture
  守恒测试解码严格 rawValue 枚举，未知 kind 抛 DataCorrupted、门16/15 红；Events.swift:8-12 的「容忍 additive
  unknown」只指 unknown **字段**非 kind 值——对抗复核已证 daemon/Swift 两侧均有 `_=>{}`/`default:break`，加 case
  零越界、零 MIN_TESTS 改动）。app **暂不 fold**（apply default break；commit-graph 泳道 = A1_51b）。
allowlist:
  - "daemon/src/branch_poller.rs"
  - "daemon/src/events.rs"
  - "contracts/event_stream.schema.json"
  - "app/Sources/TuringOS/Events.swift"
  - "fixtures/event_streams/commit_observed.jsonl"
  - "specs/atoms/A1_52_commit_observation.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 1   # fixtures/event_streams/commit_observed.jsonl（卡 .md 与 CURRENT 不计）
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；rust fmt/clippy/test 13-15 + 本卡新 Rust 测 + contract validate 门2 + fixture determinism 门9 + slice render 门11（glob 新 fixture，placeholder 渲染器 fall-through 忽略未知 kind、确定性，故绿）+ 门12 不受影响 + rust fixtures_conform 门15 + app lane 门16（Swift 加 .commitObserved 后 commit_observed.jsonl 双语言解码不抛）。**本卡不动 MIN_TESTS**——无新增 Swift 测试函数。过门前 pkill 'turingosd serve'[操作纪律]）"
  - "parse_compare_commits 纯函数测：parse_compare_commits(compare_jq_json) → Vec<CommitFact>{sha, parent_shas:Vec, author, ts, summary}（parent_shas 取 parents[].sha）；缺 commits → []；坏 json → Err；summary = message 首行截断"
  - "有界性 + cache-hit 幂等测（GhClient 计数桩，**两轮 poll**）：第一轮非默认分支对其 compare.commits 造节点（不为 ahead 之外任何 commit 造节点=无伪造）；**第二轮同一未变分支**：gh compare 调用计数仍 ==1（缓存命中、零额外 gh）∧ CommitObserved 条数与第一轮**逐一相同**（缓存 commits 幂等再发，不丢不增）；默认分支仅 1 次 commits 调用、按 default_sha memoize"
  - "截断诚实测：compare.commits 命中 250 上限 → payload 标 truncated:true、emit 已得 ≤250 条、**断言不存在 sha 为空/合成的 CommitObserved**"
  - "CommitObserved payload 测：{project_id, commit_sha, parent_shas:[...], branch_ref, author, ts, summary, provenance} 字段齐全；trust_state=observed_unsigned；source=github；**无任何 merged/green/verified 字段**（grep 断言）"
  - "跨语言解码守恒测（自执行）：Swift EventKind 含 .commitObserved；现有 EventsContractTests 自动 glob 解码 commit_observed.jsonl 全行不抛（Rust 门15 + Swift 门16 双绿）；app apply() 对 commitObserved 无 case → default break（结构性自证：本卡不向任一 Swift apply switch 加 commitObserved 分支）"
  - "真机复观（**receipt-backed RiskFinding，非 shipgate 门**；承 A1_50 真机复观形态）：daemon 对真 turingosv4 registry 真跑、**捕获一段 CommitObserved 的 JSONL 回执**（含非空非合成 commit_sha/parent_shas/author）落 handover/ 或 receipt——**该回执即证据，非口头自述**；核对某非默认分支 CommitObserved 条数 == 该分支 compare ahead_by（或命中 250 标 truncated）。此步依赖网络/gh/live registry，不被 `shipgate.sh p1` 执行，故走 RiskFinding 通道、与机械门分离"
verified_external_facts:
  - fact: "GitHub compare（GET /repos/{o}/{r}/compare/{base}...{head}）响应含 `commits` 数组：每条有 sha、commit.author（name/email/date）、commit.message、parents[]（{sha,url,html_url}）。无分页参数时 commits **上限 250**，列表最后一条是整个比较的最近提交；超 250 需分页。分支近 N 提交：GET /repos/{o}/{r}/commits?sha={ref}&per_page={N}（per_page 上限 100、默认 30）。"
    source: "docs.github.com/en/rest/commits/commits（Compare two commits + List commits；WebFetch 实证 250-cap 与 commits[] 字段形状 2026-06-14）+ A1_50 真机验 compare status/ahead_by"
    verified_on: "2026-06-14"
ux_touchpoints: >
  无直接 UI（内核轨，ADR-012 增补不限）。commit 观测经 CommitObserved 上 tape；app Events.swift 加 EventKind
  case 但**不 fold**（A1_51b 才渲 commit-graph 泳道）。失败时用户看到：该分支 commit 不出现（eprintln 降级，
  never crash/fake），与 A1_47 fail-visible 一致。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## daemon/src/branch_poller.rs
- 纯函数 `parse_compare_commits(compare_json) -> Vec<CommitFact>`（零网络、单测）：compare --jq 多取 `commits`。
- `CachedCompare` **加宽**：除 CompareFact 外存 `commits: Vec<CommitFact>`（cache-hit 幂等再发的来源）。
- poll() 每个非默认分支：compute_merge cache **miss** → 跑 gh compare、parse_compare_commits、缓存 commits、emit；
  cache **hit** → 用缓存 commits **幂等再发**（零 gh），与 BranchObserved 同步。命中 250 → 标 truncated。
- 默认分支：一次 `commits?sha={default}&per_page=N` emit 近 N 主干 commit；按 default_sha memoize。
- payload：`{project_id, commit_sha, parent_shas, branch_ref, author, ts, summary, provenance:"github_api"[, truncated]}`；
  trust_state=ObservedUnsigned、source=Github。**不发 CommitRemoved**（commit append-only；branchRemoved 时由 A1_51b fold 端按 branch_ref 级联清理）。

## daemon/src/events.rs / contracts/event_stream.schema.json
- `EventKind::CommitObserved`；kind 枚举加 "CommitObserved"（additive）。envelope deny_unknown_fields 不变。

## app/Sources/TuringOS/Events.swift
- `case commitObserved = "CommitObserved"`。**不加 fold**（apply default break）。理由：共享 fixture 守恒测试解码严格枚举，未知 kind 抛 DataCorrupted（门16/15 红）。

## fixtures/event_streams/commit_observed.jsonl
- 诚实行：project_registered → branch_observed（默认 + 非默认）→ 非默认分支 N 条 commit_observed（parent_shas 链）→
  默认分支 recent commit_observed → 一条 truncated:true 示例。**seq 跨全文件严格单调、每 event_id 全局唯一**
  （validate_contracts.sh:71-72）；全行无 merged/green。亦被门11 双渲（placeholder 忽略未知 kind、确定性）。
