---
atom: A1_40_worktree_provisioner
phase: "1"
intent: >
  回路2 第一颗（写侧起点 + galaxy 富化）：新增 WorktreeProvisioner —— app 经既有
  ProcessRunner/git seam（ShadowWorkspace 同款 commands-as-data 白名单 + 路径围栏 +
  hermetic env + 并发抽管道防死锁，沿用 A1_38 教训）对目标项目 repo 执行
  `git worktree add <path> -b <newBranch> <base>`，把 worktree 建在受控根
  `<app-support>/TuringOS/worktrees/<project>/<branchDir>` 下（WHITEPAPER §13.3 class-1
  可回滚写）。**新分支专用**（-b；同名分支已存在 → branchAlreadyExists，不覆写）。
  **路径围栏**：目标 canonicalize 必须落在 worktrees 根内（绝对路径拒绝；.. 经
  sanitize 中和，永不逃逸根）。**verb 白名单**仅 worktree add/list + rev-parse，
  禁 push/remote/clone/fetch/pull/merge/reset/rebase/rm（ShadowWorkspace 禁 worktree，
  本模块是被授权允许 worktree add/list 的唯一处）。daemon 既有 2s reconcile 会自动把新
  worktree 观测成 RadarNode（本会话真机实证：建 3 worktree 即现 3 节点 + membership 边），
  故本卡零 daemon/雷达改动即富化 galaxy（修"只见项目标题"投诉的数据侧）。本卡是
  纯能力 + 真跑测；UI 触发在 A1_41/42 装配 Meta 提议→provision 流时落。
allowlist:
  - "app/Sources/TuringOS/WorktreeProvisioner.swift"
  - "app/Tests/TuringOSTests/WorktreeProvisionerTests.swift"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/A1_40_worktree_provisioner.md"
  - "specs/atoms/CURRENT"
  - "scripts/build_app.sh"
max_new_files: 2
predicates:
  - "bash scripts/build_app.sh 全绿（executed >= MIN_TESTS）"
  - "真跑测 testProvisionsRealWorktree：临时 git repo → provision(newBranch,base) → `git worktree list --porcelain` 含新 worktree 且 refs/heads/<branch> 存在 + 工作树已检出（exit-code 断言）"
  - "verb 白名单测：枚举 allSpecs，verb ∈ {worktree,rev-parse}；baseArgs 无 push/remote/clone/fetch/pull/merge/reset/rebase/rm；worktree 子命令 ∈ {add,list}"
  - "路径围栏测：绝对 newBranch（/etc/evil）→ 抛 outsideWorktreeRoot；含 .. 的 projectId 经 sanitize 后产物路径仍 hasPrefix(根)（不逃逸）"
  - "新分支专用测：同名分支已存在 → 抛 branchAlreadyExists（不覆写）"
verified_external_facts:
  - fact: "app shell-to-git 是既有已发布范式（GitConnect/CIObservation/ShadowWorkspace/RepoCatalog/SpecDraftStore 均用 Process/ProcessRunner）；ADR-015 边界 grep（gate17）只拦 Rust `use runtime::` 不拦 Swift→git Process；daemon 2s reconcile `git worktree list` 自动观测新 worktree → WorktreeDiscovered → RadarNode"
    source: "本会话 2026-06-14 Plan 架构师核验（uds.rs:485-512 / RadarModel.swift:129）+ 真机 git worktree add 实证（建 demo/radar-a,b 即现 3 节点+边）"
    verified_on: "2026-06-14"
  - fact: "git worktree add 会向 stderr 输出大量 'Updating files: N%' 进度（turingos.app 15790 文件）—— 顺序读 stdout 后 stderr 会因 64KB pipe 缓冲死锁，故 LiveRepoGitRunner 必须并发抽两管道（沿用 A1_38 GitConnect 修复）"
    source: "本会话 2026-06-14 真机 git worktree add 输出实证"
    verified_on: "2026-06-14"
ux_touchpoints: >
  雷达/galaxy：新建 worktree 经 daemon reconcile 自动成节点（membership 边连项目锚点）。
  本卡纯能力，UI 触发在后续卡；失败 fail-visible 抛 typed WorktreeProvisionError。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
WorktreeGitSpec（commands-as-data 白名单 + forbiddenVerbs，含 worktree 子命令白名单）；
RepoGitRunner 协议 + LiveRepoGitRunner（/usr/bin/git，cwd=repo，hermetic env，并发抽管道
+ wall-clock 超时 + SIGTERM→SIGKILL，沿用 A1_38）+ MockRepoGitRunner（测试）。
provision(projectRepo, projectId, newBranch, base, root, runner)：sanitize 组件 → 路径围栏 →
rev-parse 查分支存在（存在则拒）→ mkdir 父 → worktree add -b → worktree list 验在册。
