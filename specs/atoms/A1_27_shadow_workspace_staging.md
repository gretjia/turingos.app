---
atom: A1_27_shadow_workspace_staging
phase: "1"
intent: >
  白皮书 §13.3 Shadow Workspace v1 的合法子集（Class-1 可逆本地动作的暂存底座）。
  边界（ADR-002：App 不发明私有工作区格式，用 git 语义；§13.3：用户态副本，
  零 entitlement）：本卡只做**应用自有暂存区**的 git 语义暂存——不碰用户真实
  repo。(a) ShadowWorkspace：在 app-support 下用 git init 的副本暂存目录
  stage(edit) / diff / listPending / discard，全部经 git 命令（git add/diff/
  stash/checkout，commands-as-data 只读+暂存动词白名单，无 push/无写用户 repo）；
  (b) StagedEdit 模型 + 还原点（git stash ref / commit sha）；(c) 投影：staged
  diff → diff_view IR（复用既有 block）。**promote-to-real（落到真实位置）明确
  等批准仪式 = 等 runtime tape**——本卡的 apply 仅在暂存区内，不出副本。测试
  全在 temp git repo，零真实 repo 触碰。
allowlist:
  - "app/Sources/TuringOS/"
  - "app/Tests/TuringOSTests/"
  - "fixtures/"
  - "scripts/build_app.sh"
  - "specs/atoms/CURRENT"
max_new_files: 8
predicates:
  - "命令白名单仅 git init/add/diff/stash/checkout/status（commands-as-data，grep 无 push/无 promote 到副本外）"
  - "stage/diff/discard 在 temp repo 往返正确；还原点可恢复；测试零真实 repo（仅 temp dir）"
  - "promote-to-real 不存在（grep 负控：无写副本外路径）；diff 投影复用既有 block，derive_source 非空"
  - "MIN_TESTS 上调；bash scripts/shipgate.sh p1 全绿"
verified_external_facts:
  - fact: "用户态暂存（git 语义、零 entitlement）= §13.3 v1 默认 = A1_13 已核（FEASIBILITY Part I 隔离排序）；本 atom 不新增外部论断"
    source: "FEASIBILITY.md + WHITEPAPER §13.3 + ADR-002"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. Sonnet 实现 + Sonnet 对抗核验（命令白名单、零真实 repo 触碰、promote 不存在负控、还原点往返）。
2. 架构师终审 → shipgate → 回执 → PR → 合 main（ADR-012）。
