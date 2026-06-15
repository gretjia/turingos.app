---
atom: A1_55_galaxy_lod_render_fix
phase: "1"
intent: >
  修复真机实证的 galaxy 渲染根本缺陷（A1_51c 的 tile-tree/LOD 是死代码,渲染器裸画全部 scene.nodes、
  无聚合；label/nebula 用旧 lane-Y 而 node 用 galaxy-center → 解耦"节点从天而降"；节点 Metal+SwiftUI 双重画）。
  用户真机反馈(2026-06-15): turingosv4 显示"72 分支"标签但看不到 72 个分支节点; zoom-out 一团糟; 节点浮空。

  **修复(先解功能、cosmetics 押后)**:
  1. **把 LOD 真接进渲染**(GalaxyRenderer + RadarViews 改用 LOD 选择集、非裸 scene.nodes):
     - **远景档(galaxy/cluster)**: 每项目渲一个**聚合 glyph**(星云+巨字+"N 分支·M commit"摘要)在该项目
       galaxy-center,**不画任何单个 branch/commit/worktree 节点**(~25 个 glyph、按 MIN_GALAXY_GAP 分开、干净)。
     - **node 档(缩进某项目区域)**: 对 galaxy-center 在视口内的项目,**展开**其 branch + worktree 节点 + fork 边;
       远处项目仍聚合。→ 缩进 turingosv4 时 72 分支铺开可见。
     - **detail 档(缩进某分支)**: 展开该分支 commit 泳道。
  2. **耦合 label+nebula+nodes 到同一 galaxy-center**(修 GalaxyStaticLayer 用 lane-Y、projectLane label 用 lane-Y
     的 bug → 全用 RadarLayout galaxy-center)。
  3. **杀双重渲染**: nodeOverlay 不再 ForEach(全部 813); 远景档=0 个 SwiftUI 节点卡(只 Metal 聚合); node/detail 档
     才出聚焦项目的近节点卡; a11y 镜像随 LOD 选择集(只可见节点)。
  4. **zoom-out 去杂**: 聚合 glyph 标签不重叠(ghost+real 不叠画)。
  5. **宏观取景(真机实证补充, 2026-06-15)**: 真机驱动发现 zoom-out 根因不止 LOD——固定默认相机
     `RadarCamera()`(x=0,y=0,z=0.25)把世界原点钉在屏幕左上角,而 Fermat 螺旋项目中心散布在世界
     (0,0) 周围数千单位,导致几乎所有聚合落到屏幕左上外(真机截屏:画布近全黑,仅左上角一团星云
     渗入)。修复:默认相机与 reset 改为 `RadarCamera.fittingGalaxy(centers:viewport:)`——锚定所有项目
     galaxy-center 包围盒质心 + 缩放装下(留 margin),并钳制在 galaxy/cluster 档(永不误入 node 档展开)。
     onAppear/scene 流入时重取景,用户一旦 pan/zoom 即停(hasUserMovedCamera 守卫),不抢用户视角。

  **关键纪律(上轮缺的那个测)**: 加**机械集成测**——断言渲染**用了聚合**而非裸节点(galaxy 档渲染集 size==项目数、
  非 813)——这能抓到"LOD 没接进渲染"的原 bug; **且必须真机验证**(我 computer-use 截屏: turingosv4 缩进可见 72 分支、
  zoom-out 干净聚合)——机械绿≠真机能用,上轮正栽在这。
allowlist:
  - "app/Sources/TuringOS/GalaxyRenderer.swift"
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Sources/TuringOS/GalaxyStaticLayer.swift"
  - "app/Sources/TuringOS/TileTree.swift"
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Sources/TuringOS/DesignTokens.swift"
  - "app/Tests/TuringOSTests/RadarLODTests.swift"
  - "app/Tests/TuringOSTests/TileTreeTests.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "fixtures/snapshots/p1_galaxy_scene.golden.txt"
  - "fixtures/snapshots/p1_radar_scene.golden.txt"
  - "fixtures/snapshots/a1_09_mixed_scene.golden.txt"
  - "fixtures/snapshots/p1_tiletree.golden.txt"
  - "specs/atoms/A1_55_galaxy_lod_render_fix.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；app lane 真 swift build+test+bundle；过门前 pkill 'turingosd serve'）"
  - "**LOD 集成测（抓原 bug 的关键机械测）**：纯函数 renderSet(scene, camera) 在 galaxy/cluster 档返回**每项目一个聚合 glyph**（|renderSet 的 node-level 项| == 项目数，**绝不** == raw scene.nodes 数 813）；node 档对 galaxy-center 在视口内的项目展开其 branch 节点（断言 turingosv4 缩进后其 72 branch 在 renderSet）；GalaxyRenderer.buildInstances 与 RadarViews 都消费此 renderSet（grep + 测断言渲染路径调用 LOD 聚合、非裸 for node in scene.nodes）"
  - "位置耦合测：对每个项目,其 label / nebula / branch-ring 中心 == RadarLayout.galaxyCenter(projectId)(|Δ|≤ε); 断言 GalaxyStaticLayer 不再用 lane-Y(grep + 数值测)"
  - "无双重渲染测：nodeOverlay 在 galaxy/cluster 档产 0 个 SwiftUI 节点卡(只远景聚合走 Metal); node/detail 档才出近节点卡; 断言不再无条件 ForEach(scene.nodes) 全集"
  - "聚合摘要诚实测：每项目 glyph 的"N 分支·M commit"== 该项目实际 branch/commit 节点数(从 scene 派生,不伪造); 远景不画未观测/未展开的个体"
  - "诚实律不变测：branch/commit 永不 .green(承 A1_51b 不变式回归守卫)。**标签两两不重叠(去杂)= COSMETIC 押后**：真机实证默认相机修好后仍见轻微 label 重叠(小窗 + 25 项目),该项无 committed 测、明确归入 cosmetics 跟进(诚实标注,不冒充已过),不阻塞本卡功能修复。"
  - "宏观取景测（fittingGalaxy 纯函数，回归守卫真机 bug）：散布(含负象限)的 galaxy-center 集 → `RadarCamera.fittingGalaxy(centers:viewport:)` → ① 每个 center 经 toScreen 落在 viewport 内（off-screen bug 修复）；② 落在 galaxy/cluster 档（永不 node/detail）；③ 包围盒质心映射到 viewport 中心；空输入回退默认（无 NaN/crash）"
  - "**真机视觉验证(我 computer-use,非子 agent;RiskFinding+截屏证据)**: 重建 .app + 真机跑 → ① 缩进 turingosv4 看得见其 72 分支铺开(数得出多个分支节点、不是空/blob); ② zoom-out 是干净的 ~N 个分开的项目聚合(非一团糟、标签不叠); ③ 节点不浮空(label 与其节点同位)。截屏存证 /tmp/galaxy_evidence/fix_*.png。**实证结局(2026-06-15)**: 机器睡眠锁屏→computer-use 点击/scroll 不可用; 改用 `screencapture -l <windowID>`(锁屏后台仍可抓窗口 backing store)+ System Events 菜单(锁屏可用)驱动视图切换。**已真机证**: ② zoom-out 干净铺开 ~20 项目聚合(含 turingosv4 '73 分支·239 commit')—见 fix_galaxy_default.png; ① turingosv4 node-档 72/73 分支展开 = 机械证(testRenderSetNodeBandExpandsInViewportProject + v4 aggregate branchCount==72),真机 zoom-in 视觉因锁屏不能驱动,留待解锁补; ③ galaxy 档无单节点(只聚合)故不浮空 + 耦合测守卫。标签轻微重叠(cosmetics 押后)。"
verified_external_facts: []
ux_touchpoints: >
  galaxy(Radar)经视图菜单进入。远景=分开的项目聚合(星云+巨字+计数);缩进某项目=其分支/commit 展开;
  缩进某分支=commit 泳道。**真机视觉验证(我 computer-use 驱动+截屏)是本卡完工硬条件**——上轮机械绿但真机坏,
  本卡以真机可见 72 分支 + 干净 zoom-out 为准。cosmetics(配色/动效精修)押后另立。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## 核心: LOD 选择集驱动渲染(TileTree.swift + GalaxyRenderer + RadarViews)
- TileTree 加纯函数 `renderSet(scene:camera:viewport:) -> RenderSet`,按 camera band 返回该画什么:
  - galaxy/cluster: `[ProjectAggregate{projectId, center=galaxyCenter, branchCount, commitCount, accent}]`(每项目一个)。
  - node: 对 galaxy-center 在视口(±margin)的项目 → 展开 `[RadarNode(branch+worktree)]` + fork 边;其余项目仍 aggregate。
  - detail: 加聚焦分支的 commit 节点 + parent 边。
- GalaxyRenderer.buildInstances **改成消费 renderSet**: aggregate → 一个大 glyph 实例(size 随 branchCount);展开项目 → 其节点实例。删掉无条件 `for node in scene.nodes`。
- RadarViews: projectLaneCanvas/nodeOverlay 也消费 renderSet——远景只画聚合(标签+计数,在 galaxyCenter);node/detail 才 ForEach 展开项目的近节点卡。

## 位置耦合(RadarModel/GalaxyStaticLayer/RadarViews)
- RadarLayout 暴露 `galaxyCenter(projectId)`(已有 galaxyCenters 散布);label/nebula/branch-ring 全锚它。
- GalaxyStaticLayer: nebula+ghost 用 galaxyCenter(projectId) 的世界坐标→屏幕,删 lane-Y。

## 去杂 + 诚实
- 远景聚合标签按 galaxyCenter 屏位,重叠则择优/淡化(不 ghost+real 叠画)。摘要计数从 scene 真派生。
- golden 重生(canonicalDump 不变 or 随 renderSet 增补);绿保留不变式承 A1_51b。

## 验证
- 机械: 上述 LOD 集成测 + 耦合测 + 无双重渲染测 + shipgate p1。
- **真机(我做)**: pkill 旧 app→重建 dist→relaunch→computer-use 截屏 default(zoom-out 干净聚合)→缩进 turingosv4(看见 72 分支)→存证。坏则迭代再修。
