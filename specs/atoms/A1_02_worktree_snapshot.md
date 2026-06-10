---
atom: A1_02_worktree_snapshot
phase: "1"
intent: >
  daemon 能对任意本地 git 仓库产出 WorktreeDiscovered/DiffSnapshot 事件（契约信封），
  数据来自 git2 枚举 + `git worktree list --porcelain -z` + `git status --porcelain=v2 -z`；
  R1 六边界全部以单元测试固化（同分支 --force 冲突检测/detached/prunable/submodule S 标志/
  LFS pointer 嗅探/untracked normal 模式）。
allowlist:
  - "daemon/**"
  - "fixtures/cli_transcripts/**"
max_new_files: 8
predicates:
  - "cargo test --manifest-path daemon/Cargo.toml worktree_"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "porcelain 字段顺序 worktree/HEAD/branch|detached(+locked/prunable)；同分支 add 拒绝 exit 128，--force 可绕过；porcelain v2 的 S<c><m><u> 与 ?/! 前缀；二进制 numstat 给 '-\\t-'，LFS pointer 是 3 行文本"
    source: "research/R1_memo.md §1-§2（本机 git 2.43.0 实测）"
    verified_on: "2026-06-10"
ux_touchpoints: >
  Radar 每一行的全部数据源；异常态（attention/orphan）在此产生 trust_state 与证据字段。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

git2::Repository::worktrees() 枚举 + Worktree::validate()/is_locked/is_prunable；
状态走 spawn git（--porcelain=v2 -z，NUL 解析）——CLI_ABI 同款纪律对内生效；
测试用 tempdir 现造仓库逐一复现六边界（fixtures 即测试断言的 golden）；
事件经 contracts/event_stream.schema.json 信封输出，复用 P0 校验器跑契约一致性测试。
