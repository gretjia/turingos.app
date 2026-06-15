---
atom: A1_49_branch_fold_and_counts
phase: "1"
intent: >
  galaxy 分支可视化第一颗（render 侧，value-first）：把 A1_47 daemon 已在吐的
  BranchObserved/BranchRemoved 折进 WorktreeLedger（新 BranchFact + branches 字典 +
  apply 两分支 kind），RadarScene 派生每项目 branchCounts，并在 galaxy **默认宏观视图**
  的每条项目轨道上渲染真实分支计数（"N 分支"，Canvas 文字 = 不引入 131 节点爆炸，
  确定性流畅）。这一刀把"GitHub 观测 → 屏幕"端到端打通：turingosv4 终于显示 72、
  turingos_app 18 等真实分支数。**诚实范围**：本卡只到"每项目分支计数可见"；逐分支
  节点 + fork 边 + 语义 LOD（数百节点的微观下钻 DAG）是下一颗 A1_50。merge_status 当前
  全为 unknown（poller 未算 gh compare），故 merged-green 解锁也留 A1_50，本卡不碰诚实规则。
allowlist:
  - "app/Sources/TuringOS/AttentionModel.swift"
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "fixtures/snapshots/p1_radar_scene.golden.txt"
  - "fixtures/snapshots/a1_09_mixed_scene.golden.txt"
  - "scripts/build_app.sh"
  - "specs/atoms/A1_49_branch_fold_and_counts.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/build_app.sh 全绿（executed >= MIN_TESTS）"
  - "折叠测：inline 构造 BranchObserved（含 is_default/provenance）→ ledger.branches 收录 → RadarScene.branchCounts[project] == 期望；BranchRemoved → 计数减"
  - "golden 一致测：canonicalDump 现含每项目 branches=N；committed golden 重生后逐字节相等（同 ledger 同字节）"
  - "真机复观（截图）：默认宏观 galaxy 每项目轨道显示真实分支计数（turingosv4=72 等），不卡顿"
verified_external_facts:
  - fact: "daemon (A1_47) 实时在吐 BranchObserved（source=github, provenance=github_api, payload: branch_ref/head_sha/is_default/merge_status/merged_into_default/project_id）；本会话真机 131 条已上线；merge_status 当前=unknown（poller 未算 compare）"
    source: "本会话 2026-06-14 真机读 daemon UDS（PID 27331，25-repo registry）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  Worktree Radar / galaxy 默认宏观视图：每项目轨道旁显示真实分支计数。逐分支节点/forks 下钻 = A1_50。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
AttentionModel：BranchFact + WorktreeLedger.branches[pid\0ref] + apply(.branchObserved/.branchRemoved)。
RadarModel：RadarScene.branchCounts（ledger.branches 按 project 分桶）+ canonicalDump 每项目加
" branches=N"。RadarViews.drawProjectLane far 模式画 "N 分支" 计数（Canvas 文字）。
golden 用 RADAR_GOLDEN_WRITE=1 重生。
