---
atom: A1_46_branch_observed_contract
phase: "1"
intent: >
  galaxy 分支扩展第一颗（纯加性契约地基）：在 event_stream.schema.json 的 kind 枚举加
  BranchObserved / BranchRemoved，source 枚举加 github（用户授权 gh 取全仓分支）。
  Rust events.rs + Swift Events.swift 两侧镜像同步加枚举。新增 fixture
  branch_observed.jsonl（BranchObserved×2 + BranchRemoved×1，含 github source）证明
  新 kind 在 Rust + Swift 双语 fixture-replay 都能解码（跨语言守恒）。payload 开放对象，
  无 sub_map 强制键。这是 A1_47（daemon gh 取分支）+ A1_49（app 渲分支节点）的地基。
allowlist:
  - "contracts/event_stream.schema.json"
  - "daemon/src/events.rs"
  - "app/Sources/TuringOS/Events.swift"
  - "fixtures/event_streams/branch_observed.jsonl"
  - "specs/atoms/A1_46_branch_observed_contract.md"
  - "specs/atoms/CURRENT"
max_new_files: 1
predicates:
  - "bash scripts/shipgate.sh p1 全绿（gate2 contracts+fixtures valid、gate15 rust fixture conformance、gate16 app fixture-replay 都吃下新 fixture）"
  - "新 fixture 三行（BranchObserved×2 含 merge_status/provenance、BranchRemoved×1，source=github）在 Rust events.rs + Swift EventsContractTests 双语 replay 通过"
  - "schema kind 枚举含 BranchObserved/BranchRemoved；source 枚举含 github；Rust+Swift 枚举同步（无遗漏 = 双语解码通过）"
verified_external_facts:
  - fact: "用户 25 仓真实分支规模：turingosv4=72、turingos.app=18、turingosv5=6、omegav5=2；gh compare 返回 {status,ahead_by,behind_by,merge_base_commit.sha} 作为 fork-DAG 原语"
    source: "本会话 2026-06-14 gh repo list + gh api branches/compare 实测"
    verified_on: "2026-06-14"
ux_touchpoints: >
  纯契约层，无直接 UI；为 galaxy 分支节点（A1_49）供事件类型。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
schema enum +2 kind +1 source；events.rs EventKind +BranchObserved/BranchRemoved、
EventSource +Github；Events.swift 同步；fixtures/event_streams/branch_observed.jsonl 新建。
若 Swift/Rust 有 EventKind 穷尽 match 报错 → 加 default/分支处理（不静默）。
