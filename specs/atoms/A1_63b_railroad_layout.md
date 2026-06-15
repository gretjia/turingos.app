---
atom: A1_63b_railroad_layout
phase: "1"
depends_on: ["A1_63a_mainline_resolution", "A1_71_galaxy_edge_line_render"]
adr: "ADR-017 §D (Railroad Swimlane, RATIFIED) + ADR-018 (mainline=isDefault) + research/R1_mainline_convention.md"
intent: >
  用户 #1 诉求:把 galaxy 的**扇形**(branch 极坐标轨道发散)换成 **Railroad Swimlane 树**——主线(isDefault,A1_63a 已解析为真 main)
  画成**竖直主干脊柱**(lane 0),分支为**平行 lane**,commit 按**拓扑序**沿 lane 排,parent→child 边为细线(A1_71 原语)。
  设计经 workflow(wf_516d0c7b:4 Sonnet reader map + Opus 设计)+ orchestrator 审定锁定。

  **锁定算法(替换 RadarLayout.positions 的 step3 极坐标扇 + step4 per-branch ts swimlane;step1 galaxyCenters + step2 worktree 原样保留)**:
  - **per-project**(按 projectId 分组 commits,非 branchRef=load-bearing)。trunk = isDefault 的 BranchFact;其 headSha first-parent 链(parentShas[0] 走到根/off-scene)= lane 0 脊柱。
  - **Kahn 拓扑排序** over parentShas(in-scene 父才计 in-degree;ts 升序 + commitSha 升序 tie-break,**确定性**)→ 全局 rowOf(父严格在子之上)。**替换 `sorted{ts<ts}`**(ADR-017 诚实律②:ts 仅 tie-break)。
  - lane:trunk 链恒 lane 0(**保留,非 trunk commit 永不占 lane 0**);其余 commit 走全局 nil-slot 复用(lane≥1,首个 in-scene 父同 lane 直走否则首个 nil 否则新 lane)。
  - branch 节点 = lane 头(列顶):x=center.x+lane*LANE_WIDTH,y=center.y;head off-scene 回退确定性 lane=1+(非默认 branchRef 字典序 rank)。
  - commit 世界坐标:x=center.x+laneOf*LANE_WIDTH;y=center.y+RAIL_TOP_OFFSET+rowOf*ROW_SPACING(y 向下,父在上)。
  - **抽纯函数** `RadarLayout.railroadLanes(branches:[BranchFact], commits:[CommitFact]) -> (rowOf:[String:Int], laneOf:[String:Int], branchLane:[String:Int])`(单项目,无 CGPoint/center → 可单测;positions() 乘常量+center)。
  - 常量:LANE_WIDTH=60 / ROW_SPACING=80 / RAIL_TOP_OFFSET=200(复用旧值);退役仅扇用的 starBaseRadius/starRadiusPerDivergence/starMaxRadius。
  - **森林降级(不崩)**:0 个 isDefault → 无脊柱,所有 branch lane≥1;>1 个 isDefault → 各占一 lane(co-trunk 全 chrome 推迟 A1_63a2)。MVP=单 trunk 情形。
  - **RadarScene.derive 不改**(节点/边/positions 调用已就绪);**GalaxyInstanceData.edge / buildInstances 不改** —— **唯一例外**:parent 边 alpha 0.08→0.30(GalaxyRenderer 边-alpha switch,让脊柱/rail 可见=用户核心诉求;alpha 是 GPU 值不入 canonicalDump,golden 不变)。
  - **DEFER(非本 MVP)**:commit fold、L/S-curve rail 路由(A1_63c)、co-trunk 全 chrome、drawProjectLane 旧横轨替换。
allowlist:
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Sources/TuringOS/GalaxyRenderer.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "fixtures/snapshots/p1_galaxy_scene.golden.txt"
  - "specs/atoms/A1_63b_railroad_layout.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock)。"
  - "**纯 railroadLanes 机械测**:① trunk 直脊柱:isDefault head a0(root)→ laneOf[a0]==0;a0<-a1<-a2 first-parent 链全 lane 0、rowOf 严格递增。② 分支 lane≠trunk:feat/wip(head a1,parent a0,非默认)→ laneOf[a1]≥1。③ **拓扑序非 ts**:子 ts 早于父(rebase/skew)但 parentShas 指父 → rowOf[child] 大于 rowOf[parent]，即 Kahn 胜、旧 ts-sort 会倒 = ADR-017 诚实律 load-bearing。④ tie-break 确定性:同父同 ts 兄弟 → commitSha 升序;derive 两次 canonicalDump 逐字节同(承 :851-852)。⑤ 偏 DAG:父 off-scene 的 commit 仍得有限坐标(成 Kahn root)不崩/无 NaN。⑥ 森林:0 isDefault → 无 lane0 碰撞、各 branch lane 互异;>1 isDefault → 各占一 lane 不丢。"
  - "**golden 须审重生(非盲接)**:positions 入 canonicalDump → p1_galaxy_scene.golden.txt **会变且应变**;须确认 diff **恰好** = main→lane0/a0 其下、feat/wip→lane1/a1 在 a0 下一行、gal_beta main 独 lane0 头(railroad 坐标),逐项核对后 RADAR_GOLDEN_WRITE=1 重生再无 flag 复核。**p1_radar_scene.golden.txt + a1_09_mixed_scene.golden.txt 必逐字节不变**(worktree-only,证 step2 未扰=回归守卫)。galaxyCenters 输出 + MIN_GALAXY_GAP 不变(宏观未扰)。"
  - "无回归:swift build+test 绿;rust 不动;parent 边 alpha 改不入 canonicalDump(golden 仅 positions 变)。"
  - "**真机 UX 验证**:重建 dist + 重启 app,zoom in turingos.app → 见**竖直主干脊柱(main)+ 平行分支 lane + 细线 rail**(非扇形)。截屏 /tmp/galaxy_evidence/railroad_*.png;环境墙则代偿(railroadLanes 机械测钉死脊柱/lane/topo + golden diff 审 + 用户亲见)。"
verified_external_facts:
  - "positions 入 canonicalDump(RadarModel.swift:378 `positions[n.id] ?? .zero` + :382/388/394 格式串)→ 布局变必改 p1_galaxy_scene.golden;worktree-only golden 不受 step2 影响 — verified_on 2026-06-15(workflow map)"
  - "golden 路径 fixtures/snapshots/p1_galaxy_scene.golden.txt;regen=RADAR_GOLDEN_WRITE=1 swift test --filter RadarModelTests/testGalaxySceneGolden — verified_on 2026-06-15"
  - "BranchFact.isDefault=A1_63a 解析的真 trunk(main);CommitFact.parentShas[0]=first-parent;RadarScene.derive 已发 RadarEdge.parent(commit→parent)+fork(branch→mergeBase) — verified_on 2026-06-15"
ux_touchpoints: >
  galaxy zoom in 项目 → Railroad Swimlane:主线竖直脊柱、分支平行 lane、commit 拓扑序、细线 rail —— 一眼看出是"有主干的树"非扇形。
gate: "bash scripts/shipgate.sh p1"
