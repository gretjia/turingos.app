---
atom: A1_62_canonical_main_cascade
phase: "1"
depends_on: ["A1_50_branch_relationship_facts", "A1_52_commit_observation"]
adr: "ADR-017"
intent: >
  ADR-017 落点第 1 颗(daemon 数据基座)。修真机实证缺陷:今天 galaxy 主线 = `gh .default_branch`
  字符串等值(branch_poller.rs:119 `is_default = name==default_branch`),实测把 turingos.app 的临时分支
  `claude/brave-knuth-5uo3ce` 当唯一主线;无本地 trunk、无 observed_at、provenance 硬编码 "github_api"。

  **本卡范围(只做主线级联 + 对账事实,本地"全分支发现"押到 A1_63)**:
  1. **canonical 主线 = 诚实级联,两候选各为独立观测**:对有本地 `path` 的项目,除现有 gh `.default_branch`
     (远程 default)外,加观测「本地 trunk」—— `git -C <path> symbolic-ref --short refs/remotes/origin/HEAD`
     (缓存值,标 stale-possible);缺失/可疑时 `git ls-remote --symref origin HEAD` 读活值;再退化 main/master
     名启发(仅存在性匹配)。**永不用任意 local HEAD**。多 remote(fork)时按"承载本项目的 remote"选,不盲信叫 origin 的。
  2. **发新事件 `RefReconciliation`(契约加性)**:payload `{ remote_default:{ref,source,observed_at}|null,
     local_trunk:{ref,source,observed_at}|null, relation }`;`relation` ∈
     {agree, ref_differs, remote_unobserved, local_unobserved} = **纯观测元组函数,缺失侧显式 *_unobserved,绝不推断**。
     (oid 级 gap 距离押到 A1_63 拿到 OID 后做;本卡先 ref 级。)
  3. **每分支/对账事实加 `observed_at`(daemon 观测时刻,用 envelope ts)+ `source` 枚举**
     (github_api / local_symref / remote_symref);**不重载现有 payload `provenance`**(那是观测来源标签,审查实锤)。
  4. **诚实律不变**:merged_into_default 恒 false;contained 仅可达性;trust_state 仍 observed_unsigned;
     源不可达=显式 *_unobserved,绝不补造主线。

  **不做(本卡)**:本地全分支枚举/游离工作(A1_63)、OID 身份 scene 重构(A1_63)、任何渲染(A1_64/65)。
  Swift 侧仅 Events.swift **解码新事件不 fold**(apply default break),不动 galaxy 渲染。
allowlist:
  - "daemon/src/branch_poller.rs"
  - "daemon/src/events.rs"
  - "daemon/src/main.rs"
  - "contracts/event_stream.schema.json"
  - "fixtures/event_streams/ref_reconciliation.jsonl"
  - "app/Sources/TuringOS/Events.swift"
  - "specs/atoms/A1_62_canonical_main_cascade.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 1
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;含 rust fmt/clippy/test + 契约 fixture 一致性 + app lane;过门前 pkill 'turingosd serve')"
  - "契约加性演进测:event_stream.schema.json `kind` 枚举加 `RefReconciliation`、`source` 枚举加 `local_symref`/`remote_symref`(不删改既有值/语义);同 PR 加 fixtures/ref_reconciliation.jsonl(seq 单调、event_id 唯一、payload 合 schema);events.rs EventKind 加 RefReconciliation;Events.swift 加 case 解码不 fold(承 contracts/README 规则 4)"
  - "relation 纯函数测(Rust 单测,有 teeth):relate(remote_default, local_trunk) 对 {两者同 ref→agree, 异 ref→ref_differs, 远程 None→remote_unobserved, 本地 None→local_unobserved} 逐一断言;缺失侧绝不被推断成具体 ref"
  - "本地 trunk 检测纯函数测:给定 symbolic-ref 输出/ls-remote 输出/启发,解析出 ref 名;缓存缺失(exit128)不 panic、退化到 live/启发;detached/无 main 等边界有断言"
  - "诚实律回归:merged_into_default 仍恒 false(承 A1_50 测);RefReconciliation 不携带任何 merged/green;源不可达 → relation=*_unobserved 且对应候选为 null,绝不填猜测 ref"
  - "**真机验证(我 daemon replay,非子 agent;RiskFinding+证据)= 已证 2026-06-15**:重建 daemon→真机跑→capture replay。实测(/tmp/galaxy_evidence/a162_replay*.jsonl):**turingos_app** relation=`local_unobserved`(registry 无 local path → 本地 trunk 诚实未观测、local=null、绝不猜测),remote=claude/brave-knuth-5uo3ce(github_api);**turingosv4** relation=`agree`,remote=main(github_api) ∧ local=main(local_head_cached,级联 rung1 命中)。每事实带 observed_at+source。**诚实结论**:本卡级联是 remote-default vs local-origin/HEAD,二者实测一致(origin/HEAD 镜像远程 default),故 relation=agree/local_unobserved 而非 ref_differs。用户关切的「designated default(claude/brave-knuth)≠ 实际存在的惯名 main」**不是 remote-vs-local 冲突**,是 trunk-candidacy 信号(main 按名是候选但非 designated default)→ 押 A1_63(本地全分支发现 + 多候选 trunk)。本卡是诚实基座,非用户可见 spine 修复。fixture 的 ref_differs 行=合法可能态的示例(远程 default 改名而 origin/HEAD 未刷新时会出现),非 turingos.app 实况。"
verified_external_facts:
  - fact: "canonical trunk = 级联非单源。GitHub default 可为任意名(turingos.app 实测=claude/brave-knuth-5uo3ce 临时分支)。读法:gh `defaultBranchRef` / `git symbolic-ref --short refs/remotes/origin/HEAD`(离线缓存、会过期、常不存在 exit128,须 `git remote set-head -a` 刷新或 `git ls-remote --symref origin HEAD` 读活值)。fork 多 remote 时叫 origin 的可能是上游(VibeInk 实测 origin→Beingpax 上游)。"
    source: "调研 wf_3a765aaa(docs.github.com default-branch、git-scm.com/docs/git-remote、karl.berlin/git-default-branch.html;真机 turingos.app/VibeInk 实证)"
    verified_on: "2026-06-15"
ux_touchpoints: >
  本卡纯 daemon 数据层 + Swift 解码,无可见 UI 变化(渲染在 A1_64/65)。真机验证靠 daemon replay 看
  RefReconciliation 事件正确(主线分歧被诚实观测、不静默选王)。galaxy 中央"主线争议"的视觉呈现在 A1_64+。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## daemon/src/branch_poller.rs
- poll() 内,对有 `path` 的 entry:加 `observe_local_trunk(path) -> Option<TrunkObservation{ref, source, observed_at}>`
  (symbolic-ref 缓存 → ls-remote --symref 活值 → main/master 启发;纯解析函数另抽 testable)。
- 远程 default 包成 `TrunkObservation{ref: default_branch, source: github_api, observed_at: now}`。
- `relate(remote, local) -> Relation`(纯函数,单测)。
- 每项目发一条 `RefReconciliation`(EventKind 加值),payload 两候选 + relation。
- 现有 BranchObserved payload 加 `observed_at` + `source`(不动 provenance)。

## daemon/src/events.rs + contracts
- EventKind 加 `RefReconciliation`;contract kind 枚举 + source 枚举加性;fixtures/ref_reconciliation.jsonl。

## app/Sources/TuringOS/Events.swift
- 加 `case refReconciliation`;apply 里 default break(本卡不 fold、不渲染)。

## 验证
- 机械:契约加性 + relation/本地检测纯函数测 + 诚实回归 + shipgate p1。
- 真机:daemon replay 看 turingos.app relation=ref_differs、observed_at/source 齐。
