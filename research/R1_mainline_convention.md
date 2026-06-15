# R1 — 主线判定约定（Mainline Determination Convention）

> RATIFIED 2026-06-15（用户四问全批推荐）。依据 = 10-agent 研究+对抗 workflow（wf_ac035e39，5 研究 facet × 行业共识 + 3 对抗 lens 信号可靠性/森林多主干/宪法诚实律 + 综合）。全量输出钉档 `/tmp/mainline_convention_full.json`（本机临时）。
> 本约定 refine 并部分覆盖 **ADR-017** 的 trunk-candidacy 信号（退役"高入度"），正式留痕见 **ADR-018**。

## 一句话原则
**一个仓库的 PRIMARY 主线由"指定类"信号选出，不是由"最活跃"选出。** 行业共识（git-branchless `branchless.core.mainBranch` / Sapling / GitKraken "Pin to Left" / GitLens / pvigier git-graph）= 拓扑只**提议**，指定才**裁决**。first-parent 深度、recency、descendant-count（`--contains` 高入度）**永不**做选择器——它们恰是把 `develop` 选成 `main`、把陈旧 `brave-knuth` 选回来的根因。

## 判定级联（designation-class，最权威优先）
- **rung 0 — 人工 pin**：`PinObserved` 事件携 pinned git_ref + who/when（tape-canonical，非静默字段）。本期**先桩事件类型，缓做 UI**（决策4）。
- **rung 1 — live 远程 HEAD 命名常规分支**：path-present 用 `git ls-remote --symref origin HEAD`（**LIVE**，不是缓存的 `symbolic-ref refs/remotes/origin/HEAD`——后者在本 repo = 陈旧 brave-knuth）；path-absent 用 `gh api .default_branch`。**仅当**命名 ref 是常规集成名（main|master|trunk）**且** rung2 ancestry 不反对时才确认。turingos.app **在此 rung 失败**（brave-knuth 非常规名）→ 落 rung2。
- **rung 2 — ancestry 消去 + 名称优先级**：候选集 = {存在的常规名 ref main|master|trunk|develop|release/* + 配置默认}。`merge-base --is-ancestor` 两两比，**丢掉任何严格祖先（0-ahead 被包含）**的候选（topological 硬事实）。幸存者按**名称优先级**破僵：`main/master > trunk > develop > release/*`。depth/recency 只在**同优先级**幸存者间做标注 tie-break，**绝不**越过更高优先级名称。>1 个分叉（互非祖先）幸存者 → rung5。**这是 turingos.app 落点：main 胜出**。
- **rung 3 — 缓存/配置默认（无 compare 可观测）**：仅 path-absent/offline 且**单候选无常规名共存**时，作 PROVISIONAL（灰）。**禁止**：当常规名 ref 共存且 ancestry 未观测时落此 rung（改走 rung5）。
- **rung 4 — 名称存在性启发**：main/master/trunk/develop 中第一个存在的 ref，无 ancestry 确认。PROVISIONAL。禁用 init.defaultBranch / 硬编码 'main' / checked-out HEAD / `--contains` 高入度（实测反转）。
- **rung 5 — FAIL-VISIBLE 终态（三态）**：(a) **mainline unobserved**（无候选 + 分支枚举空，如 mindsync 0-branch 空仓 API 409）→ 无锚点、不画脊柱、绝不退回缓存默认值；(b) **mainline ambiguous — N spines**（>1 分叉幸存者仅靠活跃度可分 / 或配置默认是某观测到的**非常规名**长寿线的严格祖先=真主线可能未命名）；(c) **declared default vs main, ancestry unobserved**（compare 限流/离线、二者共存）。

## 三类别（覆盖 ADR-017 的两类）
1. **PRIMARY** — 每仓库**恰一个**，rung0-2 designation 选出，画最左直 first-parent swimlane（pvigier/GitUp 脊柱）。
2. **MAINTAINED CO-TRUNK** — 名字本身是维护/发布常规名的长寿分叉线（`release/*` | `*-stable` | `hotfix/*` | `vN.x`），画**并行维护脊柱**，**显式不**归入"探索"（把 release/1.21 叫探索 lead 是语义谎言=生产维护）。检测靠名称模式（启发式，残留隐患，靠 recency 标注优雅降级）。
3. **SECONDARY 探索 lead** — 其余每条非主线长寿线，绕 PRIMARY，携对**纠正后的 mainline_ref**（**非**陈旧 ctx.default_branch——base-correction 是 load-bearing）观测到的 ahead/behind。

## 诚实律（必钉）
- `merged_into_default` **恒 false**，直到观测到真实 two-parent merge commit 并入 primary（无 cheap ancestry/PR 升级——[[reference_github_merged_detection_unsound]]：revert 让 mergeCommit 仍可达却内容已撤）。`contained_in_default`（ahead==0）= 中性"可达 trunk tip"，**绝不**"已并入/已完成"。
- 严格祖先**且在 primary 的 first-parent 脊柱上** → 折叠为历史 checkpoint；严格祖先但**不在**脊柱上（如被 revert 的 merge 祖先，可达但内容已撤）→ **保留为降权但可见**的 secondary（"0 ahead / N behind · reachable"），**绝不折叠**（否则 = 结构性 false-absorbed，比该约定禁的 merged-badge 更糟，branch_poller.rs:340-355 警告的正是此类）。
- recency（A1_62 observed_at）只**冷却 prominence**、**绝不熄灭**一个 lead；唯一诚实终态 = 观测到 remote 删除（"gone"，**非** "abandoned"）。recency 在全系统**一致**地只作 liveness 标注（不是 primary 选择器，化解了原候选"recency 既加冕又禁熄"的自相矛盾）。
- A1_62 `relate()=Agree` **不可**读作"主线正确"——它比的是 remote-default vs **缓存** origin/HEAD，二者互相镜像（实测都=陈旧 brave-knuth），故 Agree 与陈旧脊柱完全相容、不能证明 primacy。{配置默认, A1_62 local_trunk} 是**一个**owner-声明事实、非两个独立候选；唯一真正的第二信号 = 常规名 reachability 探针，**必须无条件运行**。
- 任何弱于 (pin / live-remote-HEAD-命名常规 / sole-ancestry-survivor) 选出的锚 → 渲染 PROVISIONAL：灰 chrome + 强制 icon+text {git_ref, TrunkSource, observed_at}（VISUAL_SEMANTICS 规则 3/4，颜色绝不单独承载置信度）。

## turingos.app worked example（实测 2026-06-15）
配置默认 = `claude/brave-knuth-5uo3ce`（**非**常规名 → rung1 失败）。rung2 候选含全部观测线：brave-knuth（0-ahead/90-behind 于 main）、codex/a1-08..11（103/0, 99/0, 97/0, 93/0 — 全 0-ahead）、claude/* 等 → **全部是 main 的严格祖先 → 全 fold**；`main`(4baca321) 是唯一常规名幸存者 → **PRIMARY = main**。provenance = `main · trunk by ancestry+name-precedence (configured default brave-knuth is 90 behind, folded)`。冲突经扩展 RefReconciliation `relation=default_behind_named`（0-ahead/90-behind）披露。**覆盖警示（load-bearing）**：turingos.app 无本地路径 → ancestry 须靠 gh compare；compare 不可得时**必须**落 rung5 (c)，**绝不**落 rung3 provisional-on-brave-knuth（main 廉价可知共存）。未来态：任一 codex/* 落一个 main 没有的 commit 即 diverge，旧候选会进 depth/recency 竞赛——本约定下名称优先级让 main 保持 primary（codex/* 非常规名），diverge 的 codex 线成可见 secondary，**绝不**夺取 primary。

## daemon vs app 改动（A1_63a 实现锚）
- **DAEMON（branch_poller.rs）两遍 whole-repo reduction**（主线判定**非** per-branch 局部）：
  - PASS A（gather，**无条件于缓存/声明信号**）：配置默认（:649-650 已读）+ live `ls-remote --symref`（非缓存 symbolic-ref）+ 常规名存在性+ahead/behind（`gh api branches` + `gh api compare/{cand}...{other}`；有 path 时本地 rev-list）。
  - PASS B（reduce）：① 非空枚举前置；② ancestry 消去；③ 名称优先级破僵；④ 分叉幸存→rung5 路由 → 产出 `mainline_ref` + TrunkSource tier + relation。depth/recency 算但只标注。
  - **`is_default` 改为 reduction 之后的 DERIVED 字段**（**非** parse_branch_list:289 的 per-branch stamp——它在 compare 之前跑，会冻结陈旧默认）。`mainline_ref` 作 compare base(:575)、recent-commit sha(:737)、default_ref(:768)——所有现 raw default_branch 线程改用解析后的 ref。
  - 扩展 RefReconciliation(:670-690) 携 resolved primary + relation（default_behind_named + ahead/behind），保持 merged_into_default=false-always、contained=可达性。
  - 加 PinObserved 事件类型桩（先桩缓 UI）。加 derive_from_tape 守恒测（Art.0：resolved primary 可从 emitted 事件输入重建）。
- **APP（Swift）**：① AttentionModel.swift **补缺失的 .refReconciliation fold case**（今天没有 → reconciliation 到不了任何投影）；② RadarModel.swift isAnchor(:224) + center-anchor 布局改吃 reconciled `mainline_ref`，非 raw is_default bool；③ 渲染 provenance tier（confirmed/provisional/ambiguous/unobserved）为 icon+text（VISUAL_SEMANTICS 3/4，含"配置默认 N behind"披露）+ **三 rung5 fail-visible 态** + **maintained-co-trunk 并行脊柱类**。rung3 provisional + rung5 chrome 是 load-bearing no-false-green，**必须与 daemon resolution 同原子 ship，不可 defer**。

## 残留隐患（诚实交代，非 blocking）
1. 常规名候选集仍**封闭** {main,master,trunk,develop,release/*}。特异名真主线（`production`/`mainline-v2`）+ 不是任何观测线祖先的陈旧常规默认 → 仅部分被 rung5(b) 覆盖（仅当未命名线**可观测地** superseding 才触发）；纯 diverge（非 superseding）的特异名真主线仍可能漏。完整覆盖需 pin 或可配置 per-repo trunk 名单（git-branchless mainBranch 模式）——后续 atom。
2. rung5 ambiguous 会**比原设想更常触发**（设计使然：活跃度不再静默破分叉僵局）。活跃多 agent 森林（如 turingos.app）这是**诚实结果**，但意味着某些库会显"N spines, no primary"直到人工 pin 落地。合宪（弃权胜过臆测），但架构师应预期此 UX 转变；rung0 pin 是逃生口（本期仅桩）。
3. co-trunk 检测是名称模式启发——特异名的真维护线落入"探索"、模式匹配的死 `release/old` 渲成 co-trunk 脊柱（直到观测删除）。recency 标注缓解不根治；pin/label 可解。
4. gh compare-API 限流暴露（~22 path-absent 库/轮）；fail-safe（compare 失败→rung5）诚实但限流时会间歇 blank 该库脊柱（honest-blank over confident-stale，用户已批此 trade）。
5. derive_from_tape 守恒测保 reduction 的确定性、**不**保它消费的观测（gh compare 结果）的新鲜度——observed_at 标注是那里唯一的守卫，与系统其余一致。
