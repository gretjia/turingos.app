# R-stage 备忘 — Galaxy Canonical-Main + 未合并分支即机会（数据模型）

> 触发：用户真机测试反馈 #2/#3（turingosv4 看不到节点、主面与分支无关联）+ 用户纠偏：
> 「不能完全依赖本地，要找到项目真正的 main 主线（通常在 GitHub 或本地主 Git），散落的未合并分支
> 正是机会点、正是 galaxy 要做全局洞察的地方。这在行业里讨论很多，去调研、别草率决策。」
> 状态：研究 + 对抗审查完成；待 ADR-017 落定。依据本备忘开 Phase-1 后续 galaxy 数据模型 atom。
> verified_on: 2026-06-15（调研 wf_3a765aaa / 对抗审查 wf_35cdeba3，均含真机实证）

## 0. 病灶（真机实证，非记忆）

- **今天 galaxy「主线」在用户自己的仓库上就选错了。** `gh api repos/gretjia/turingos.app -q .default_branch`
  = `claude/brave-knuth-5uo3ce`（一个 Claude 临时分支），不是 main。而 `branch_poller.rs` 的
  `is_default = (name == gh default_branch)` 是**唯一**主线来源（无本地回退、无 origin/HEAD、无 main/master 启发）；
  RadarModel 把 isDefault 锚成星系中心。三个朴素信号在该仓库**全不一致**：local HEAD =
  `claude/uds-fix-and-worktree-provisioner`、缓存 origin/HEAD = `claude/brave-knuth-5uo3ce`、
  gh default = `claude/brave-knuth-5uo3ce`，且本地另有 `main` 分支谁都不是。
- **Fork 陷阱（VibeInk 实证）**：`origin`→上游 Beingpax/VoiceInk，`mine`→用户 gretjia/vibeink。
  盲信叫 "origin" 的 remote 取到的是**上游**的 trunk，不是用户的。"origin" 只是 clone 来源简写，非"正统家"。
- **分支发现 100% 远程、0% 本地**：分支只来自 `gh api .../branches`；daemon 的本地 reconcile（snapshot.rs）
  只读 `git worktree list`+`git status`，从不读 `git for-each-ref`/`refs/heads`。→ 没 push 的本地分支
  （最易丢、最该被看见的机会）**今天在模型里无法表示**，与 galaxy 立意相反。
- **turingosv4「0 BranchObserved」不是它专属 bug，是串行慢轮询的假象**：poller 串行、300s/轮、
  ~4.2 分钟/轮（~1.45s/gh-compare），turingosv4（73 分支、排第二）光它 ~100s；9 分钟 replay 抓在它还没刷完时。
  它那 34 条 ReconciliationCompleted 来自另一条 2s 的本地 reconcile 线程（turingosv4 同时有 path+remote）。
  retained-log replay 不会丢已发事件 → 0 条 = 那个窗口里**确实没发过**（poller 没轮到/没跑完），非传输丢失。
  根因仍是 remote-only 模型 + 串行吞吐 + stderr 无落盘（失败只对没人看的 TTY 可见）。

## 1. 行业调研结论（带源）

- **canonical trunk = 级联，不是单一来源**。GitHub default branch 是 server-side 人为声明、可为任意名
  （不一定 main/master）；读取：`gh repo view --json defaultBranchRef` / `git symbolic-ref --short refs/remotes/origin/HEAD`
  （**离线缓存、会过期、常根本不存在**，须 `git remote set-head origin -a` 刷新或 `git ls-remote --symref origin HEAD` 读活值）。
  没有单一权威；GitLab 甚至迁向 HEAD-only 检测。
  源：docs.github.com（changing-the-default-branch / rest/branches）、git-scm.com/docs/git-remote、karl.berlin/git-default-branch.html。
- **节点身份 = commit OID，分支只是贴在 commit 上的标签**——所有 DAG 工具（git-branchless、Sapling smartlog、
  jj、GitKraken/GitLens、Fork）统一做法；"不去重分支，锚 commit、折 ref 为标签"。同 OID→一个点（多标签）；
  异 OID→两点，差距=真实图距离。jj 规则：同 target 折一个、分叉显两个（`main??`/`main*`）。
  源：git-branchless wiki/Concepts & Command:git-smartlog、sapling-scm.com/docs/overview/smartlog、
  github.com/jj-vcs/jj/blob/main/docs/bookmarks.md、git-scm.com/docs/git-for-each-ref（`%(upstream:track)` 等）。
- **smartlog 拓扑 = galaxy 几乎逐字模板**：main+祖先=public（脊柱、省略已合并内部），其余=draft（机会点），
  相对 trunk 度量（`% main()`）。git-branchless/Sapling 已 ship。
- **未合并分支：业界主流是"债，删之"**（Fresh/Aging/Stale/Fossilized 生命周期 + auto-delete-on-merge）。
  用户的**正向"机会点"框架是真空白地**——只在博客感慨层出现、无工具落地；现有可视化（Gource 等）都是历史时间动画，
  没人做"当前未合并分支集围绕脊柱的静态机会宇宙"。**信号是借来的，价值外显的静态宇宙是原创。**
  源：codepulsehq branch-aging-report、github.blog 2022-05-16 compare-branches、git-scm fsck/reflog、Gource。
- **可 sound 观测的机会信号（全中性，绝不断言 merged/abandoned）**：距 trunk 的 ahead/behind、
  独有 commit 数（=机会权重头条）、最近活动年龄（中性、不叫债）、本地/远程 provenance、contained（可达性≠已合并）。
  **"abandoned" 断不了**：git-branchless 能说 abandoned 只因它装了 rewrite 事件钩子（obsolescence markers）；
  passive observer 无此日志，最多对中性信号做 UI 强调，绝不下判决。reflog/stash 是 local-only/per-clone，
  只能单仓富化，不是 galaxy 级统一信号；refs（分支）才是唯一可跨仓 sound 枚举的单位。

## 2. 对抗审查：被强化且通过诚实复核的大胆想法（wf_35cdeba3，12 条全 honest+landable）

> 审查框架（用户定）：找更大胆能落地的想法 + 守宪法，不许收缩。以下均"保留胆略、补诚实栏"通过。

1. **RefReconciliation 一等对象**（不是一个黄点）：每项目发 typed `{remote_default, local_trunk}`（各带 ref/oid/observed_at/source）
   + `relation` 枚举（agree / ref_differs_same_oid / oid_differs / remote_unobserved / local_unobserved，纯观测元组函数，不补缺失边）；
   galaxy 核心画两个候选锚 + gap-arc（长度=真实 commit 距离，未观测则虚线"距离未知"）。turingos.app 就是 canonical demo。
   泛化为通用 RefReconciliation（trunk 争议是首例），同结构复用到同名分叉/never-pushed。
2. **commit-OID 唯一身份、ref=标签**（落地 model B；RadarModel 今天还是 3 个不相交数组=回归）。
   守诚实：两 OID 间的边**仅当中间 commit 全部已观测**才实线，否则显式"省略/未观测跨度"边带 truncated（daemon 已有 250 截断 flag，要外显不要吞）。
3. **游离/无分支的本地工作**（detached WIP、stash、被删分支 tip、reflog-only）= 一等机会节点，机会权重最响。
   中性标"local-only, unreferenced"+中性年龄，永不 abandoned/debt；provenance=local-only（灰），绝不投成远程信任态。
4. **多脊柱/森林拓扑**为一等可能（非异常）：trunk-candidacy 是多值**观测**属性；>1 候选分歧时脊柱**可见地分叉**，不静默选王。
   turingos.app（gh default≠local，且无 main）使之成为**当下 bug**而非未来需求。
5. **机会升进 triage 脊柱**：加第 4 个 `AttentionSeverity.opportunity`，走**现有** AttentionTriage→AttentionItem→AttentionTarget→radar fly-to
   管线（须把 AttentionTarget 从只有 worktreeIds 扩成通用 nodeIds、RadarScene.resolve 支持任意已定位节点）。
6. **Meta Orb scope=注视点 = 机会动词**，接已写好但死的 A1_41（WorktreeResearch.gather + proposeWorktreeTask）；
   生成文本走 R3 `generated` 灰徽 + 与原始证据共置（R8），只 L≤2 propose、绝不自动改世界。
7. **机会是 tape 上的 fold、可重放**：opportunity_weight(seq) 是 `assert(view==derive_from_tape)` 应用到机会，Replay 可 scrub；
   按 **seq** 锚定不按 wall-clock；opportunity_weight = **纯字节确定函数**（独有 commit 数 + 由 observed_at 派生的 recency），
   主观排序走 RiskFinding/产品判断，**绝不冒充 {PASS,FAIL} predicate**（宪法红线 4）。

## 3. 视觉方案（颜色+美学区分，用户点名；全部带非颜色腿、过灰度测）

**核心法则：结构一律 achromatic（白-alpha）+ 项目辨识 accent（Tokens.Accent，≥72 离每语义锚），语义六色（红/黄/蓝/灰/紫/绿）只留给信任态。branch/commit 结构永不上语义色、永不上绿。**

1. **脊柱 vs 普通分支 = 几何+光度,非颜色**：脊柱=中心锚+白-alpha 0.12→0.35 轴线+6s axisSweep+唯一 360° 白 halo+2px 双描边环；普通分支=极坐标轨道上的小 accent 点、无轴无 halo。
2. **四态 provenance = 描边形状,非色相**：both-synced=实心盘+实线环；local-only=实心+点线环(dash[2,3])+house 字形;remote-only=空心(填充 α0.15)+长虚线环(dash[6,4])+cloud 字形;both-diverged=实心+双环带缝(缝即分叉)+branch 字形。同一 hue,纯形状→过灰度/色盲。
3. **远程默认↔本地主干分歧 = 黄(唯一正当语义复用):两个候选锚 + 粗黄 conflictTension 边(1.5s 慢脉冲,区别于 active-blue)+ ⚠ 一句话标(「GitHub 默认=claude/brave-knuth… ≠ 本地主干 main」)。halo 在达成一致前withheld → "王冠悬而无主"。
4. **机会权重 = 连续 bloom(glow 半径 × 轨道环厚度)+ 轨道半径**,绝非计数网格(Software 3.0 §3 黑名单"等权重三计数并排");选中才出语言头条「12 commits unique, 路过 3 天前」。
5. **陈旧/年龄 = 热力冷却(向冷背景 0x030305 LERP+glow 衰减),中性不是债红、不是语义灰**;≥0.25 不透明度地板(冷星仍是星、仍可点)。与全局 mood.live 灰washisolated。

## 4. 诚实律红线（ADR 必钉,审查实锤的现存假象一并修）

1. 只渲已观测;两 OID 间实线边仅当中间全观测,否则显式 elided/truncated。
2. branch/commit 永不绿;merged_into_default 恒 false;contained=可达性,popover 必带「≠ 已并入内容」。
3. 每事实加 `observed_at` + `source` 枚举;**recency 只能由 observed_at 派生**——BranchFact 今天**无任何时间戳**,所以"年龄/recency"在补字段前是**纯虚构**,先加字段再用。
4. opportunity_weight = 纯确定函数(观测整数),非 predicate。
5. **swimlane 行序必须是观测 parent-DAG 的拓扑排序(Kahn over parentShas),时间戳只做并列 tie-breaker**——今天 RadarModel.swift:528 按 ISO 字符串 `$0.ts<$1.ts` 排序=**虚构了观测 DAG 里没有的顺序**(审查实锤)。
6. RefReconciliation.relation 纯观测元组函数,缺失侧显式 `*_unobserved`,绝不推断。

## 5. 与现有裁决的冲突(ADR 须显式处理)

- **`design/V6_RECONCILIATION.md` / DESIGN_SPEC_V6 仍保留 green=#34D399 给「Merged 节点」(冰冻态)**——直接抵触诚实律(merged-green 已判 unsound,A1_50/ADR-016)。ADR-017 须**显式退役/覆盖**该绿-合并-节点规格:本方案对 branch/commit 结构全 achromatic+accent,绿无插槽。
- `cross_source_state`(agree/diverged 等)是**新加性字段**,不得复用/重载 `provenance`(那是观测来源标签);走 contracts/README 规则 4 加性演进。
