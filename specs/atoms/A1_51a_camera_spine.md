---
atom: A1_51a_camera_spine
phase: "1"
intent: >
  望远镜的相机与坐标骨架——A1_51 拆卡第一颗（见 research/R1_infinite_zoom_memo.md §3、ADR-016）。
  把现 RadarCamera（scale+offset、缩放线性 clamp 0.1–2.0、单一 isFar 阈值 0.6）升级为 tldraw 式
  `Camera{x,y,logZoom}` 内核，并**新增** screenToPage/pageToScreen + zoom-to-cursor 闭式 + floating-origin
  （供 A1_51c 用）；同时**保留旧读面 value-equivalent**以隔离视觉：

    - **新增 API**：`screenToPage / pageToScreen`（floating-origin：`screen=(world−renderOrigin)*z+offset`）；
      `zoom(by/to, anchor)` zoom-to-cursor 闭式（`camera.x += pointer.x*(1/oldZ − 1/newZ)`）；log 空间
      z = pow(2, logZoom) ∈ [~0.01, 256]，logerp 平滑；z-band 阈值 token（galaxy/cluster/node/detail，本卡只定义）。
    - **Float32 审计**：世界/变换数学全 Double（jitter 病根 = 任何 Float/Float32 进世界数学）。
    - **隔离（关键，对抗复核 wf_49c47696 实锤）**：RadarViews 当前**直接读** `displayCamera.scale`
      （:279/319/328/341 星云半径、巨字 Y、边控制点）与 `displayCamera.isFar`（:294/310/314/351/357/368
      线宽、远景 label/dot 门控），并在 nodeDrag(:215) 除以 `camera.scale`。故 RadarCamera **保留** `scale`
      （computed = z）、`isFar`（computed = z < 旧阈值 0.6 等效）、`offset`、`toScreen/toWorld`、`zoom(by:anchor:)`、
      `pan`、`focusing(on:scale:)`、默认 init 为 **value-equivalent 读面**（同值同行为）。**「外观不变」由
      value-equivalence 谓词机械背书**（非口头断言）：默认 z==0.25、且跨 z 采样 scale/isFar/nodeDrag 反演值与
      今天逐一相等 → RadarViews 读出值不变 → 渲染不变。本卡因此**无需 render golden / 无视觉签字**。

  **测试迁移**：现有 RadarModelTests 的 testCameraMouseAnchoredZoom/testFocusingCentersWorldPoint 硬绑旧
  clamp（scale==2.0/0.1）；新 clamp 为 z∈[0.01,256]，这两个断言必改 → RadarModelTests 在 allowlist 内，
  将其相机覆盖迁入新 RadarCameraTests.swift（并按新 clamp 改写）。净测试数升、仍 ≥ MIN_TESTS=302 floor →
  **不动 build_app.sh**。
allowlist:
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Sources/TuringOS/DesignTokens.swift"
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "app/Tests/TuringOSTests/RadarCameraTests.swift"
  - "fixtures/snapshots/p1_camera_transform.golden.txt"
  - "specs/atoms/A1_51a_camera_spine.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 2   # RadarCameraTests.swift + 新 committed golden p1_camera_transform.golden.txt（RadarModelTests 为既有文件编辑）
predicates:
  - "bash scripts/shipgate.sh p1 全绿（16 门；app lane 门16 真 swift build+test+bundle+wire-probe；两旧相机测迁入 RadarCameraTests 后 RadarModelTests 仍编译/绿；**2 旧相机测迁出后 RadarCameraTests 净增 ≥3 函数 → swift test 执行计数 ≥ MIN_TESTS=302 floor**（302−2+≥3≥303），**不动 build_app.sh**；过门前 pkill 'turingosd serve'）"
  - "zoom-to-cursor 不变式测：任意 (world, cursor, oldZ→newZ)，zoom 后 pageToScreen(world) 落在 cursor（|Δ|≤1e-9）；闭式 camera.x += cursor.x*(1/oldZ − 1/newZ) 成立"
  - "往返恒等测：pageToScreen∘screenToPage == id 且 screenToPage∘pageToScreen == id（|Δ|≤1e-9），跨 z∈{0.01,0.25,1,16,256}；**含 nodeDrag 反演**：screenΔ/z 还原成 worldΔ 与今天 screenΔ/scale 在 default z 逐一相等"
  - "log 空间 + clamp 测：z == pow(2, logZoom)；zoom clamp 到 [zMin,zMax]=[~0.01,256]（越界饱和不溢出/不 NaN）；logerp(a,b,t) 纯函数确定性（同输入同输出，无 clock/random）"
  - "floating-origin 正确性测：大世界坐标（如 1e7）下，pageToScreen∘screenToPage 往返误差**有界 |Δ|≤1e-6**（renderOrigin 贴近相机 与 origin=0 **均**成立）。**不**断言 near<far 严格不等——纯 Double 在 1e7≪9e15 整数精度天花板下往返无损、near=far=0，严格不等不可满足（对抗复核 wf_913b000f 实证）；floating-origin 的精度**收益**（Float32 下 near<far）留 A1_51c 对真 Metal/Float32 消费者演示，本卡只确立 renderOrigin 管线 + 有界正确性"
  - "Float32 审计测（**已实证、CGFloat-safe、BSD/GNU 可移植的钉死正则 + 正向 teeth**）：对 RadarModel.swift 全文件 + RadarViews.swift 相机/变换区，正则 `(^|[^A-Za-z0-9_])Float(32)?([^A-Za-z0-9_]|$)` **零命中**（2026-06-14 实证：该正则命中 `Float`/`Float32`/`Float(`、**不命中** `CGFloat(`/`useFloaty`，且当前两文件零命中）；正向 teeth：注入 `let z: Float = 0` 时该正则**必须命中**（证非空转）。文件级审计（CGFloat 允许）"
  - "**外观不变 value-equivalence 测（替代 render golden）**：默认 RadarCamera().scale==0.25（|Δ|≤1e-9）；跨 logZoom 采样断言 camera.scale==pow(2,logZoom) ∧ camera.isFar==(scale<0.6)[旧阈值等效] ∧ nodeDrag 反演因子==1/scale——即 RadarViews 直接读的全部相机标量（:279/294/310/314/319/328/341/351/357/368/215）逐一与今天相等 → **任一给定 z 处 + 默认取景的渲染输出不变**（机械背书，非口头断言）。注：clamp 0.1–2.0→0.01–256 是 ADR-016 有意扩缩放包络（缩放手势可达更深 z = 新增能力、**非回归**）；故是「逐 z 读标量等效 + 默认取景等同」，非「全局渲染不变」"
  - "相机变换 golden（**本卡新建、首写守卫**）：fixtures/snapshots/p1_camera_transform.golden.txt 为本卡**新 committed 基线**（一组 (world,z,renderOrigin)→screen + scale/isFar 表）；复用 RadarModelTests 既有 RADAR_GOLDEN_WRITE 首写守卫（首次生成即 XCTFail，禁自我祝福），committed 后重生逐字节相等"
  - "场景 golden 不变测：fixtures/snapshots/p1_radar_scene.golden.txt 与 a1_09_mixed_scene.golden.txt **逐字节不变**（本卡不碰布局/scene 派生）。注：A1_51b 之后这两个 golden 会被有意重生为新基线——本卡的「不变」相对 A1_51b 尚未运行"
verified_external_facts:
  - fact: "tldraw 相机模型 Camera{x,y,z}（(x,y)=视口左上的 page 坐标，z=缩放因子 z=1→100%），只经 screenToPage/pageToScreen 转换；缩放走 log 空间（存 logZoom，z=pow(2,logZoom)，logerp 平滑）；zoom-to-cursor 闭式 camera.x += pointer.x*(1/oldZ − 1/newZ)；floating-origin screen=(world−renderOrigin)*z+offset。jitter 病根 = 任何 Float/Float32 进世界/变换数学（IEEE-754 单精度 ~7 位有效数字、超 ~8.4M 单位丢小数）；64-bit macOS 上 CGFloat 即 Double。"
    source: "tldraw 源码/文档（Camera/coordinate 模型）+ IEEE-754 单精度分析；workflow wf_1de05afa research:infinite-zoom（见 research/R1_infinite_zoom_memo.md §7）"
    verified_on: "2026-06-14"
  - fact: "Float-audit 正则 `(^|[^A-Za-z0-9_])Float(32)?([^A-Za-z0-9_]|$)`：本机实证（2026-06-14）命中 `let z: Float`/`Float(x)`/`Float32`、不命中 `CGFloat(row)`/`CGFloat(idx)`/`var s: CGFloat`/`useFloaty`；对 RadarModel.swift + RadarViews.swift 全文件零命中（二者今日只用 Double/CGFloat）。无 `\\b`（BSD/GNU grep 可移植）。"
    source: "本机 grep -E 实证 /tmp/floattest.txt + RadarModel/RadarViews（2026-06-14）"
    verified_on: "2026-06-14"
ux_touchpoints: >
  galaxy(Radar) 经 视图菜单（A1_30）进入。本卡换相机内核但**外观不变**（由 value-equivalence 谓词机械背书：
  默认取景 z==0.25、缩放/平移/拖拽读出标量逐一等效）；无新增用户可见变化、无视觉签字。失败兜底：相机 NaN/越界
  → clamp 饱和（fail-safe，不黑屏、不跑飞）。
gate: "bash scripts/shipgate.sh p1"

# 代码思路

## app/Sources/TuringOS/RadarModel.swift（RadarCamera：新内核 + value-equivalent 旧读面）
- 内核 `{x:Double, y:Double, logZoom:Double}`；`var z: Double { pow(2, logZoom) }`。
- **新增** `pageToScreen/screenToPage`（floating-origin，renderOrigin 入参）、`zoom(by/to:anchor:)` 闭式、logerp。
- **保留 value-equivalent 旧读面**：`var scale: CGFloat { z }`、`var isFar: Bool { z < semanticFarThreshold等效 }`、
  `offset`、`toScreen/toWorld`（非 floating-origin、同今天）、`pan`、`focusing(on:scale:viewport:)`、默认 init logZoom=log2(0.25)。
  RadarViews 的 .scale/.isFar/.toScreen/.toWorld/.zoom/nodeDrag(/scale) 读用**不改值**。
- clamp logZoom 到 [log2(0.01), log2(256)]；`band(_ z:)->Band` 阈值来自 DesignTokens。

## app/Sources/TuringOS/DesignTokens.swift（Motion）
- 加 z-band 阈值 token；zoomRange 扩到 z∈[~0.01,256]；semanticFarThreshold 保留（isFar 等效旧 0.6）。

## app/Sources/TuringOS/RadarViews.swift（仅在必要处适配，零视觉值改动）
- 若 RadarCamera 读面 value-equivalent 则 RadarViews 近乎不改；仅在引入 renderOrigin 渲染路径处适配（A1_51c 才全面用 pageToScreen）。不改任何视觉绘制/常量。

## app/Tests/TuringOSTests/RadarModelTests.swift（编辑：迁出 2 相机测）
- 移除 testCameraMouseAnchoredZoom/testFocusingCentersWorldPoint（旧 clamp 断言）；其余不动。

## app/Tests/TuringOSTests/RadarCameraTests.swift（new）+ fixtures/snapshots/p1_camera_transform.golden.txt（new，首写守卫）
- 相机谓词单测（zoom-to-cursor / 往返+nodeDrag 反演 / log+clamp / floating-origin / Float32 正则+teeth / 外观 value-equivalence）+ 相机变换 golden（RADAR_GOLDEN_WRITE 首写 XCTFail 守卫）。
