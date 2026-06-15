---
atom: A1_71_galaxy_edge_line_render
phase: "1"
depends_on: ["A1_68_galaxy_instance_layout"]
adr: "(ADR-016/017 galaxy 渲染;DESIGN 结构 achromatic 白-alpha)"
intent: >
  真机反馈(2026-06-15,zoom in turingos.app):galaxy 出现一个**大灰色矩形**。实证根因(读代码钉死):
  GalaxyRenderer 的**边(kind 2)被画成正方形而非线**——边实例 `size: lenNDC * 0.5`(GalaxyRenderer.swift:269,
  注释自称"thin elongated"但实现不是),而 vertex shader 把**每个**实例都当**轴对齐正方形**画
  (`pos = center + localPos * s`,:54,完全忽略 kind)。故一条长边 → 边长那么大的灰色正方形(被 clamp 到 0.6 NDC
  = 半屏灰块)。A1_68 修 stride 后此潜伏 bug 忠实渲染出来 → 用户现在看到。与 A1_63a 无关。

  **修复(proper thin oriented line,零丢弃,A1_63b railroad 边复用此原语)**:
  - GalaxyInstanceData 加 `halfVec: SIMD2<Float>`(线=半边向量,node=(0,0))。**恰好落在原 40-48 padding 内 → stride 仍 48**
    (A1_68 layout 不变,仅加 offset 断言)。MSL InstanceData 同加 `float2 half_vec;`。
  - shader 分支:`halfVec` 非零 → 画**沿边定向的细矩形**(localPos.x×halfVec 跨全边,localPos.y×perp×size 为厚度);
    否则维持 node 正方形。size 对边=线厚(小常量 NDC),对 node=正方形半边(不变)。
  - 边实例构造:center=中点、halfVec=半边向量(NDC)、size=细厚度(非 lenNDC*0.5);抽出纯函数 `edgeInstance(...)` 可机械测。
  - 4 个 GalaxyInstanceData 构造点(nebula/node×2/edge)补 halfVec(node 全 (0,0))。
  纯 app 渲染层;**不入 canonicalDump**(GPU 实例,golden 不变)。不动布局(扇形布局仍 A1_63b 替换,本原子只让边是线非方块)。
allowlist:
  - "app/Sources/TuringOS/GalaxyRenderer.swift"
  - "app/Tests/TuringOSTests/RadarLODTests.swift"
  - "specs/atoms/A1_71_galaxy_edge_line_render.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock)。golden 不变(GPU 实例不入 canonicalDump)。"
  - "**布局断言(A1_68 续)**:testGalaxyInstanceDataMatchesMSLLayout —— stride 仍 ==48;offset center0/color16/size32/kind36 不变 + 新增 **halfVec@40**;Swift↔MSL 逐字节吻合(防 A1_68-class desync 复发)。"
  - "**边=线非方块(机械)**:纯 `edgeInstance(from,to,viewport,...)` 测 —— 返回 halfVec == 半边向量(非零、= (to-from)/2 NDC)、size == 细厚度常量(**非 lenNDC*0.5**);长边不再产出大 size。node 实例 halfVec==(0,0)。"
  - "无回归:swift build+test 绿;node/nebula 渲染不变(halfVec=0 → shader 走原正方形分支);clamp(size,0,0.6) 保留。"
  - "**真机 UX 验证**:重建 dist + 重启 app,zoom in turingos.app → **灰色大矩形消失**,边呈细线(连接 branch/commit)。截屏 /tmp/galaxy_evidence/edge_*.png;环境漂移则代偿(布局测 stride/offset 钉死 + edgeInstance 机械测 + 代码 correct-by-construction,用户可亲见)。"
verified_external_facts:
  - "GalaxyRenderer.swift:269 边 size=lenNDC*0.5;shader:54 pos=center+localPos*s 对所有 kind 画正方形(忽略 kind);注释:250 自称 thin elongated 但未实现 — verified_on 2026-06-15(读源)"
  - "GalaxyInstanceData 当前 stride 48,offset center0/color16/size32/kind36;40-48 为对齐 padding(halfVec float2 align8 恰落 40,stride 不变) — verified_on 2026-06-15"
ux_touchpoints: >
  galaxy 节点/详情档的边渲染为细线(非半屏灰方块),连接关系清晰可读。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
## GalaxyRenderer.swift
- MSL `struct InstanceData { float2 center; float4 color; float size; uint kind; float2 half_vec; }`(half_vec@40,stride48)。
- Swift `GalaxyInstanceData` 同加 `var halfVec: SIMD2<Float>`(末位,落 padding)。
- shader galaxy_vertex:`float s=clamp(size,0,0.6); float hlen=length(half_vec); if(hlen>1e-6){ dir=half_vec/hlen; perp=float2(-dir.y,dir.x); pos=center + localPos.x*half_vec + localPos.y*perp*s; } else { pos=center+localPos*s; }`。
- 抽 `static func edgeInstance(fromScreen,toScreen,viewW,viewH,color,alpha) -> GalaxyInstanceData`(center=中点 NDC、halfVec=半边向量 NDC、size=细厚度如 0.0025、kind=2);buildInstances 边循环调用之。
- nebula/node 两处构造补 halfVec: SIMD2(0,0)。
## RadarLODTests.swift
- testGalaxyInstanceDataMatchesMSLLayout 加 offset(of:\.halfVec)==40、stride 仍 48。
- 新 testEdgeInstanceIsThinOrientedLine:edgeInstance 长边 → halfVec≠0 且 = 半边向量、size 小常量(非 lenNDC*0.5)。
