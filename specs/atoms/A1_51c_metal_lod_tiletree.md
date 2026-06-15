---
atom: A1_51c_metal_lod_tiletree
phase: "1"
depends_on: ["A1_51a_camera_spine", "A1_51b_galaxy_layout"]   # a: z-band token；b: 场景节点
intent: >
  望远镜的渲染引擎 + 语义缩放 LOD + 跨粒度 tile-tree——A1_51 拆卡第三颗。用户裁决③：直接上 **Metal 实例化**
  （混合 SwiftUI a11y overlay）。

    - **Metal 实例化渲染**：MTKView 一次 `drawIndexedPrimitive(instanceCount:)` 画密集**视觉层**（星场/星云/
      边/远景光点 glyph/commit 泳道点）。shader 走 **inline 源编译**（`device.makeLibrary(source:)`）——不引入
      .metallib/Resources，**不碰 Package.swift / build_app.sh**。
    - **a11y 混合（硬约束 + 真 teeth，对抗复核 wf_49c47696 实锤）**：Metal 绘制不进 a11y 树，但 VISUAL_SEMANTICS
      rule 3 + 现有 a11y 测试钉死每节点 a11y。**机制**：a11y 镜像做成**纯模型派生函数**
      `visibleA11yElements(scene, camera, viewport) -> [A11yMirror]`（每元素含 nodeId + accessibilityLabel +
      screen 坐标），RadarViews 把它 **1:1** 映射成透明 SwiftUI accessibility 元素叠在 Metal 层之上。这样 a11y
      不变式可在 RadarLODTests **对该纯函数**机械断言（无需 view-introspection harness）：可见集每节点（**含远景
      光点档**）有且仅有一个 A11yMirror、label 非空。杜绝「搬到 Metal 后悄悄丢 a11y 镜像、命名测试仍绿」的假绿洞。
    - **空间索引 + 视口剔除**：GKQuadtree（或等价）；每帧 cull AABB∩viewport 的 tile；远景取簇层 → O(#簇)
      （预聚合簇金字塔 Supercluster）。
    - **LOD band**：消费 A1_51a 的 z-band token（galaxy/cluster/node/detail），每 band 换表征 + cross-fade + 滞回防闪。
    - **tile-tree + LayerProvider + DeferredRef**（内部 app 结构，非契约——ADR-016）：
      `tile{level∈{project,branch,commit,decision}, bounds(子⊆父), summary/rollup, detailThreshold, refine:REPLACE}`；
      `LayerProvider{getTile,getChildren}`；`GitProvider` 服务 project/branch/commit（从 A1_51b 的 RadarScene）；
      `DeferredRef("chaintape", ref)` 在 commit→decision 边界=**leaf-until-provider**——未注册时 getChildren 返叶子，
      **绝不渲合成决策节点**（诚实律；命名对齐 daemon DeriveSource::Chaintape）。
    - **ADR-008 隔离**：27-only Metal API 仅放 `GalaxyRenderer27.swift` + `#available(macOS 27,*)`；**守护由 26.5-SDK
      整体编译（门16）保证**（grep 只验「符号仅在该文件」位置，不验 #available——本机 Xcode-27 SDK 不触发该守卫、
      CI 26.5 lane 才真正把关）。Metal device 不可用（headless/probe，`MTLCreateSystemDefaultDevice()==nil`）→
      fail-safe 降级 SwiftUI 占位，不黑屏、probe 仍 exit 0。
    - **非目标（allowlist 完整性自证）**：`RadarCanvasView` 公开 init 签名（store:focus:prefs:）**不变**，
      `ContentView.swift`（:98 构造它）**不碰**。

  **改了渲染手感/语义缩放——收工配真机截图视觉签字 + 性能观感**（主观判据走 RiskFinding）。本卡不改 scene 派生
  （A1_51b）、不改美学精修（A1_51d）。
allowlist:
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Sources/TuringOS/GalaxyRenderer.swift"
  - "app/Sources/TuringOS/GalaxyRenderer27.swift"
  - "app/Sources/TuringOS/TileTree.swift"
  - "app/Sources/TuringOS/DesignTokens.swift"
  - "app/Tests/TuringOSTests/TileTreeTests.swift"
  - "app/Tests/TuringOSTests/RadarLODTests.swift"
  - "fixtures/snapshots/p1_tiletree.golden.txt"
  - "specs/atoms/A1_51c_metal_lod_tiletree.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 6   # GalaxyRenderer.swift, GalaxyRenderer27.swift, TileTree.swift, TileTreeTests.swift, RadarLODTests.swift, fixtures/snapshots/p1_tiletree.golden.txt（shader inline、无 .metal/Package.swift；M4 扁平预算超 3 = minimalism RiskFinding 已justify）
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；app lane 门16 真 swift build+test+bundle；27-only Metal API #available + 源文件级隔离 → 26.5 SDK 整体编译过；新测加进执行计数 ≥ MIN_TESTS=302 floor，**不动 build_app.sh**；过门前 pkill 'turingosd serve'）"
  - "视口剔除正确性测（**独立 oracle**）：cull(tiles, camera, viewport) == oracle，oracle 由**独立 brute-force point/rect-in-rect**计算（非复用生产 AABB 例程，杜绝同错双绿）；对 N≥10k 桩 scene 断言远景 band 渲染集大小 ≤ 簇数 ≪ 节点数（具体数值上界）"
  - "tile-tree 不变式测：每 tile 子 bounds ⊆ 父 bounds；detailThreshold 决定 summary（停）vs refine:REPLACE（钻子）；同 RadarScene ⇒ 同 tile-tree（确定性）"
  - "DeferredRef leaf-until-provider 测：ChainTapeProvider 未注册 → getChildren(DeferredRef(\"chaintape\", x)) 返叶子——**断言不产任何合成决策节点**（诚实律）；注册桩 provider 后**同一** DeferredRef 解析出子节点（零重设计缝）"
  - "LOD band + 滞回测：band(z) 确定性；滞回 hysteresis（同 z 升/降途中可不同 band 但对给定历史确定）；cross-fade alpha 纯函数"
  - "a11y 不退化测（**对纯函数 visibleA11yElements，真 teeth**）：现有 RadarNode.accessibilityLabel/Value 测试全过；断言 `visibleA11yElements(scene,camera,viewport)` 的输出与可见节点集**一一对应**——|output| == |visible nodes|、每 visible nodeId 恰一个 A11yMirror、label 非空，**含远景光点档**（far band 也每节点一镜像，不丢 a11y）；RadarViews 1:1 渲染该函数输出"
  - "Metal fail-safe + 隔离测：MTLCreateSystemDefaultDevice()==nil（headless/probe）→ GalaxyRenderer 降级 SwiftUI 占位、不崩不黑屏（probe 仍 exit 0）；grep 断言 27-only Metal 符号**仅出现在 GalaxyRenderer27.swift**（位置；#available 守卫由 26.5-SDK 编译门16 保证、非 grep）；**正向 teeth**（镜像 A1_51a Float 审计）：临时往非-GalaxyRenderer27 文件注入一个 27-only 符号时该 grep **必须命中**，证 matcher 非空转（防本机 Xcode-27 SDK 不触发编译守卫时唯一信号假绿）"
  - "tile-tree golden（本卡新建）：RadarScene → tile-tree 的 canonical dump（level/bounds/detailThreshold/refine）写入 fixtures/snapshots/p1_tiletree.golden.txt，复用 RADAR_GOLDEN_WRITE 首写守卫（首次生成即 XCTFail，禁自我祝福），committed 后重生逐字节相等"
verified_external_facts:
  - fact: "海量节点 LOD 三层：① 空间索引视口剔除（GameplayKit GKQuadtree / KD-tree，bbox 查询比全扫快百倍）；② 预聚合簇层级（Supercluster 自底向上 zoom 金字塔，getClusters(bbox,zoom) 返回有界簇+点，6M 点可交互）；③ Metal 实例化（一次 drawIndexedPrimitive(instanceCount:)，Apple 样例 240k 三角/帧 60fps 几个 %CPU）。Metal device 在无 GPU/headless 下 MTLCreateSystemDefaultDevice() 可返回 nil，须降级；shader 可 device.makeLibrary(source:) 运行时编译（无需 .metallib 资源）。跨粒度场景=LOD tile-tree（OGC 3D Tiles tileset：level/bounds/geometricError/refine:REPLACE，子 bounds⊆父→剔除 O(1)），多源缝合用 external-tileset 间接引用（DeferredRef leaf-until-provider）。"
    source: "Apple GameplayKit/Metal 样例 docs + mapbox/supercluster + OGC 3D Tiles spec；workflow wf_1de05afa research:huge-graph-lod / granularity-model（见 research/R1_infinite_zoom_memo.md §7）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  galaxy 渲染换 Metal（密集分支/commit 节点流畅）；语义缩放各档换表征。a11y 全保留（VoiceOver 可达每节点，含远景
  光点档，由 visibleA11yElements 纯函数 1:1 背书）。**收工配真机截图视觉签字 + 性能观感**（主观判据走 RiskFinding）。
  失败：Metal 不可用 → 降级 SwiftUI 占位（fail-visible，不黑屏）。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## TileTree.swift（new，纯结构 + 派生，可测）
- `enum TileLevel{project,branch,commit,decision}`；`struct Tile{level,bounds,summary,detailThreshold,children:ChildRef}`。
- `protocol LayerProvider{getTile;getChildren}`；`GitProvider`（from RadarScene）服务 project/branch/commit。
- `enum ChildRef{resolved([Tile]); deferred(DeferredRef)}`；`DeferredRef(source:"chaintape",ref:)`；未注册→叶子（不合成）。
- `cull(camera,viewport)`、`band(z)`、`refine` 纯函数（cull 测用独立 brute-force oracle）。
- `visibleA11yElements(scene,camera,viewport) -> [A11yMirror{nodeId,label,screenPoint}]`（纯函数，a11y 真 teeth 的来源）。

## GalaxyRenderer.swift（new，MTKViewRepresentable）
- inline shader（`device.makeLibrary(source:)`）；实例 buffer；一次 drawIndexedPrimitive(instanceCount:)。
- device nil → 降级 SwiftUI Canvas 占位。**不引入 Resources/.metal，不改 Package.swift/build_app.sh。**

## GalaxyRenderer27.swift（new，27-only 隔离）
- 仅 `if #available(macOS 27,*)` 的 27-only 调用；26.5 SDK 不引用其符号（编译即守卫）。

## RadarViews.swift（组合；RadarCanvasView 公开 init 不变、ContentView 不碰）
- ZStack：底=GalaxyRenderer（Metal）；中=SwiftUI 节点卡 overlay（承 A1_51b）；顶=a11y 镜像层（`visibleA11yElements` 输出 1:1 → 透明 accessibility 元素）。LOD band 决定各层取舍。

## DesignTokens.swift
- LOD/instancing/簇阈值常量（band 已由 A1_51a 定义）。
