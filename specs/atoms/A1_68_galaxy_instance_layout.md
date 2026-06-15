---
atom: A1_68_galaxy_instance_layout
phase: "1"
depends_on: ["A1_67_quit_demodalize"]
adr: "(ADR-016 Metal 实例化层;无新裁决)"
intent: >
  真机反馈 #4:galaxy 宏观档出现两块**实心硬边**蓝/品红大色块(铺满半屏,遮住项目标签)。
  根因实锤(真机 bisection + NSLog 探针):**Swift↔MSL InstanceData 结构体内存布局不一致**。
  - MSL `InstanceData { float2 center; float4 color; float size; uint kind; }`:`float4` 强制 16 字节对齐
    → color@16、size@32、kind@36、**stride 48**。
  - Swift `GalaxyInstanceData` 紧凑打包(centerX@0…kind@28、**stride 32**)。
  着色器按 MSL 的 48-stride 索引 `instances[id]`,而 Swift 按 32-stride 写入 → 每个实例错位读取:
  `inst.size` 读到的是**相邻实例的 centerX**(NDC 值 ~−1..1)→ 巨型四边形;颜色读到错位字节
  → 蓝/品红。探针实证:Swift 侧 size 全为 0.0067–0.02(正确、微小)、位置全在左/上,但屏幕右侧却
  铺出硬边色块 —— 正是 stride 错位的签名。此 bug 自 A1_51c 潜伏,A1_56 回执曾误判为「screencapture
  跨 space 合成伪影」(本次用 `screencapture -l` 直抓 backing store + 关 Metal 实例 bisection 实锤为真)。

  **修复(最小、根因级)**:把 Swift `GalaxyInstanceData` 改用 `SIMD2<Float>`/`SIMD4<Float>`,其对齐
  规则与 MSL float2/float4 一致 → center@0、color@16、size@32、kind@36、stride 48,与 MSL 逐字节吻合。
  着色器(MSL)本就是正确布局,不动;仅改 Swift 结构体 + 4 处构造点。另加一条着色器侧防御 clamp
  (`size` 钳到 [0,0.6])限制任何未来布局漂移的爆炸半径。
  **机械护栏**:新增布局断言测试(MemoryLayout stride==48 / offset(color)==16 / offset(size)==32 /
  offset(kind)==36),把 Swift↔MSL 契约钉死,杜绝回归。

  **不做(本卡范围外)**:nebula 是正确的(柔和 0.18 椭圆,即标签后的暗晕,非色块);#1 树布局(A1_63)、
  #5 细节卡(A1_57/A1_58)、全屏(A1_60)各自单原子。
allowlist:
  - "app/Sources/TuringOS/GalaxyRenderer.swift"
  - "app/Tests/TuringOSTests/RadarLODTests.swift"
  - "specs/atoms/A1_68_galaxy_instance_layout.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock)"
  - "**布局断言测试(机械 {PASS,FAIL})**:MemoryLayout<GalaxyInstanceData>.stride == 48;offset(of: \\.color)==16;offset(of: \\.size)==32;offset(of: \\.kind)==36 —— 与 MSL InstanceData 逐字节一致;FAIL 即 Swift↔MSL 契约破裂(本 bug 的精确护栏)"
  - "golden 不变:本卡只动 Metal 实例缓冲布局(GPU 私有),不碰 scene/positions/canonicalDump/契约/daemon → 所有 fixtures/snapshots golden 逐字节不变"
  - "无回归:swift build+test 绿;着色器仍编译(makeLibrary 不报错);RadarLODTests.testMacOS27SymbolIsolation 仍绿(未引入 27-only 符号)"
  - "**真机 UX 验证(我 computer-use,backing-store 直抓)**:进 galaxy 宏观档 → **无任何实心蓝/品红色块**铺屏;项目标签 + 柔和 nebula + 小聚合光点正常;再缩进 node/detail 档确认无残留色块。前后对比存证 /tmp/galaxy_evidence/cb_*.png。"
verified_external_facts:
  - "Metal MSL 结构体 float4 成员强制 16 字节对齐 → InstanceData{float2,float4,float,uint} stride=48(非 Swift 紧凑 32);Swift SIMD2<Float>/SIMD4<Float> 采用相同对齐 → 布局吻合 — 真机 bisection+NSLog 探针实证 verified_on 2026-06-15"
ux_touchpoints: >
  galaxy 宏观档不再被巨型错位四边形(蓝/品红色块)污染;聚合光点/标签/nebula 干净可读。真机 backing-store 截屏签字为完工硬条件。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
## GalaxyRenderer.swift
- `struct GalaxyInstanceData`(去掉 private 以便布局测试可见;@testable 不暴露 private):
  `var center: SIMD2<Float>` / `var color: SIMD4<Float>` / `var size: Float` / `var kind: UInt32`。
- 4 处构造点(star grid / aggregate glyph / node dot / edge)改用 `center: SIMD2<Float>(x,y)`、`color: SIMD4<Float>(r,g,b,a)`。
- MSL `galaxy_vertex`:`float s = clamp(inst.size, 0.0, 0.6); pos = inst.center + in.localPos * s;`(防御钳;正常内容 size≤~0.5 不受影响)。
## RadarLODTests.swift
- `testGalaxyInstanceDataMatchesMSLLayout`:断言 stride/offsets == MSL(48/16/32/36)。
## 验证
- 机械:shipgate p1 + 布局断言 + golden 逐字节不变。
- 真机:computer-use 宏观档 backing-store 截屏无色块;node/detail 无残留。
