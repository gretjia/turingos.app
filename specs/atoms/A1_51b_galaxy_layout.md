---
atom: A1_51b_galaxy_layout
phase: "1"
depends_on: ["A1_51a_camera_spine", "A1_52_commit_observation"]   # 须 a + A1_52 均 green 后方可 /atom-open（A1_52 落地 EventKind.commitObserved + Swift case；a 落地相机 API）。A1_50 = 数据源依赖（非 build）：见 ux_touchpoints
intent: >
  望远镜的跨粒度数据模型 + 星系/泳道布局——A1_51 拆卡第二颗。把 A1_49 的「每项目分支计数」临时占位换成真正的 galaxy。

    - **数据 fold**：`AttentionModel.BranchFact` 补 A1_50 字段（ahead/behind/mergeStatus/mergeBase/
      containedInDefault），`apply(.branchObserved)` 扩字段提取；新 `CommitFact` + `WorktreeLedger.commits`，
      `apply(.commitObserved)` fold（A1_52 供源）。commit 节点 append-only——无 CommitRemoved 事件；
      `apply(.branchRemoved)` 级联清理该 branch_ref 的 commits。
    - **节点派生**：`RadarScene.derive` 除 worktree 节点外，从 ledger.branches/ledger.commits 派生**分支/commit 节点**
      （RadarNode.kind 区分 worktree/branch/commit；非计数，替 A1_49 branchCounts）。默认分支节点 isAnchor=true。
    - **类型保全（硬约束，对抗复核 wf_49c47696 实锤——防 guard 硬挡 + 编译断裂）**：`RadarNode.Form` + `.classify(_:)`
      的 5 个 case 与 `RadarScene.derive(ledger:)` 的签名/返回类型 **必须按 API 字节保全不变**。worktree chrome 仍走
      Form；branch/commit chrome 是**独立的中性 kind-based 路径**（不挂 Form）。`ProjectProjections.swift`
      （:174/203 调 Form.classify + 穷举 5-case switch）、`GlanceProjection.swift`（:72/102）、`OrbState.swift`
      （:139/154）、`ProjectProjectionTests.swift`（:136…）**均不在 allowlist、刻意不编辑**——它们的编译通过 = 类型保全的见证。
    - **布局**（RadarLayout 横轨道 → 星系团，纯算术、无 clock/random；djb2 复用 `Tokens.Accent.stableHash`，
      module-internal、不编辑 DesignTokens）：① 项目中心散布（stableHash(project_id)，任两中心间距 ≥
      `MIN_GALAXY_GAP` 常量，零跨项目边 ADR-009）；② 星系内 = 默认分支中心锚 + 分支角度=stableHash(branch_ref)、
      半径=base+k·(ahead+behind) 截断 + fork 边→merge_base 锚；③ 分支内 commit-graph **在线泳道**
      （row=时序拓扑、lane=active-branches 列表、空 lane 置 nil 不删→列不抖）。
    - **诚实律**：branch/commit 节点 chrome **永不产 .green**；contained/merge_status 经位置+中性 chrome；
      无 CommitObserved ⇒ 无 commit 节点（只渲已观测）；worktree=贴对应分支的活跃占用标记。

  **改了已裁决的 V6 默认宏观视图（A1_49 横轨道 → 星系团）——ADR-016 授权，收工配真机截图视觉签字**（主观判据
  走 RiskFinding，不冒充机械 predicate）。canonicalDump 格式变更影响面已 grep 实证（2026-06-14）完全限于本卡
  allowlist（canonicalDump + branchCounts 消费者仅 RadarModel/RadarViews/RadarModelTests；
  `p1_worktree_radar.golden.md` 是 placeholder dashboard、非 RadarScene dump、不受影响；AttentionModelTests/
  GlanceProjectionTests 不引用 dump/golden/branchCounts）。本卡有意重生 A1_51a 冻结的两 scene golden = 新基线
  （A1_51c/d 以此为准）。
allowlist:
  - "app/Sources/TuringOS/AttentionModel.swift"
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "fixtures/snapshots/p1_radar_scene.golden.txt"
  - "fixtures/snapshots/a1_09_mixed_scene.golden.txt"
  - "fixtures/snapshots/p1_galaxy_scene.golden.txt"
  - "specs/atoms/A1_51b_galaxy_layout.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 1   # fixtures/snapshots/p1_galaxy_scene.golden.txt（分支+commit 泳道场景）；既有两 golden 为重生非新建
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；app lane 门16 真 swift build+test+bundle；新测加进既有 RadarModelTests、执行计数升 ≥ MIN_TESTS=302 floor，**不动 build_app.sh**；过门前 pkill 'turingosd serve'）"
  - "类型保全见证测：`git diff --exit-code` 断言 app/Sources/TuringOS/ProjectProjections.swift、GlanceProjection.swift、OrbState.swift、app/Tests/TuringOSTests/ProjectProjectionTests.swift **逐字节不变**；且 swift build 全绿（它们对 RadarNode.Form/.classify/RadarScene.derive 的依赖编译通过 = Form 5-case + derive 签名保全的机械见证）"
  - "分支→节点派生测：inline BranchObserved（含 ahead/behind/merge_status/contained/is_default）fold → 每分支一个节点（kind=branch，**非计数**）；默认分支节点 isAnchor=true；同 ledger ⇒ 同 positions"
  - "commit→节点派生测：inline CommitObserved（含 parent_shas）fold → 每 commit 一节点（kind=commit）；parent 边按 parent_shas；**无 CommitObserved ⇒ 无 commit 节点**；branchRemoved 级联清理该 branch commits；同 ledger ⇒ 同 positions"
  - "绿保留不变式测（**对实际派生节点对象、非 Form.allCases；对抗 fixture 须真携带 flag 穿 fold**）：构造一条 BranchFact 其 containedInDefault=true **且** mergedIntoDefault=true，断言（a）派生出的 branch 节点确实**承载**这两个 flag（非 vacuous——flag 真穿 fold 进节点）∧（b）其 resolved chrome ∈ {nil,中性} ∧ ≠ .green（merged-green 永不渲染）"
  - "星系布局测：每项目=空间一区（任两项目中心间距 ≥ MIN_GALAXY_GAP 数值断言、零跨项目边 ADR-009）；分支按 merge_base 锚分叉、按 ahead/behind 定半径；fork 边存在；commit 泳道 row=拓扑序、lane 稳定（空 lane 置 nil 不删）；canonicalDump 含逐分支/commit 节点 + 边；committed golden 重生逐字节相等"
  - "worktree 标记测：worktree 节点贴对应分支；kind 区分 worktree/branch/commit 不混淆"
  - "确定性测：同 ledger ⇒ 同 canonicalDump（无 clock/random；djb2=Tokens.Accent.stableHash 跨进程稳定）；p1_radar_scene/a1_09_mixed/新 p1_galaxy_scene golden 对同输入双生成 sha 相等"
verified_external_facts:
  - fact: "2D commit-graph 布局用 git commit-graph 在线泳道算法（pvigier/gitk 系）：row=时序拓扑排序；lane=维护 active-branches 列表（空出的 lane 置 nil 不删→列不抖），放最低非禁用 lane，直分支留同 lane、merge 横转竖。在线/流式=只布局已加载窗；dense 交叉才回退 Sugiyama。"
    source: "pvigier 'Building a Git graph' 系列 + gitk lane 算法；workflow wf_1de05afa research:granularity-model（见 research/R1_infinite_zoom_memo.md §7）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  galaxy 宏观重做：深空里散布的项目星系（星云晕 + 巨型幽灵项目名 + 主干脊柱 + 分支光点群 + commit 泳道），近观=
  分支/commit 节点。**改了已裁决 V6 默认宏观——收工配真机截图视觉签字**（主观判据走 RiskFinding）。导航留 macOS
  菜单（A1_30）。**A1_50 = 数据源依赖（非 build）**：mechanical green 不需 A1_50（fold 用默认值兜底、inline 测自供
  字段），但**真机视觉签字须 A1_50 在 registry live** 才有真实 ahead/behind/merge_status——否则分支关系渲染为诚实
  空（非伪造），视觉签字应推迟到 A1_50 供真值。失败：分支/commit 观测缺失 → 该节点不出现（不伪造）；daemon 断连
  → RadarMood gray-wash。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## app/Sources/TuringOS/AttentionModel.swift
- `BranchFact` 补 ahead/behind/mergeStatus/mergeBase?/containedInDefault；`apply(.branchObserved)` 多取（默认兜底）。
- 新 `CommitFact{...parentShas...}` + `WorktreeLedger.commits`；`apply(.commitObserved)` fold；`apply(.branchRemoved)` 级联删该 branch commits。

## app/Sources/TuringOS/RadarModel.swift（类型保全：Form/.classify/derive 签名不变）
- `RadarNode` 加 `kind {worktree, branch, commit}`；branch/commit chrome 走**独立中性 kind 路径**（不挂 Form，
  Form + .classify 5-case **保全不变**——ProjectProjections 穷举 switch 不破）。
- `RadarScene.derive(ledger:)` **签名不变**；内部加分支/commit 节点 + 边（fork→merge_base / parent→parent_shas）。
  移除 public `branchCounts`（RadarViews:322-325 同步改）。
- `RadarLayout` 重写（galaxyCenters + MIN_GALAXY_GAP / starSystem 极坐标 / commitSwimlane 在线泳道）；djb2 复用 Tokens.Accent.stableHash。
- `canonicalDump` 扩逐 branch/commit 节点 + 边；golden 重生（新基线）。

## app/Tests/TuringOSTests/RadarModelTests.swift
- 重写 testBranchObservedFoldsToCounts（:137-150，原断言 scene.branchCounts）→ 断言**逐分支 NODE 数**；
  绿保留测升级为对实际派生 branch/commit 节点 + 携 contained/merged flag 的对抗 fixture（见谓词 4）。

## app/Sources/TuringOS/RadarViews.swift（最小适配，精致留 d）
- nodeOverlay/drawEdge 适配新节点 kind + 星系坐标（仍 Canvas）；移除 branchCounts 计数渲染。**不换 Metal/不上美学**。
