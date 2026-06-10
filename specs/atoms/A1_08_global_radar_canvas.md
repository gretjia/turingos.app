---
atom: A1_08_global_radar_canvas
phase: "1"
intent: >
  V6 Global Workspace Radar 的 SwiftUI 化（设计北极星落地）：星云/主轴/Bezier 连线
  Canvas 绘制 + 节点卡 overlay（可达性树保留）；pan/zoom（鼠标位锚定缩放 0.1-2.0）；
  语义缩放 <0.6 压缩态=默认初始视角（V6 规范 §7.2 隐藏清单逐条）；节点拖拽每帧
  updateEdges；五节点形态（Truth/Active/Merged/Conflict/Orphan）绑 daemon 真实流
  （A1_03 订阅 + A1_06 分桶投影）；Glance popover 三计数。golden 快照 + 可达性
  0/1 谓词进 shipgate。布局状态=本地偏好不上 tape。
allowlist:
  - "app/**"
  - "scripts/shipgate.sh"
  - "fixtures/snapshots/**"
max_new_files: 16
predicates:
  - "bash scripts/build_app.sh"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "色彩法源 = TRUST_STATES × VISUAL_SEMANTICS（含 2026-06-10 项目辨识色第 5-7 条）；V6 示例数据为 illustration，禁止复刻"
    source: "design/V6_RECONCILIATION.md §1"
    verified_on: "2026-06-10"
ux_touchpoints: >
  这就是 Glance+Radar 两时刻的主表面：压缩态一眼全局健康度；放大=单项目操作；
  conflict ⚠ 浮标/orphan 虚线/FSEvents blue 脉冲（hint_only 永不转 green）全部
  按对账表；Agent Chip 在 P1 以 occupant 推断态渲染（gray inferred 标注）。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

RadarScene：Canvas 画星云(blur 椭圆)/轨道(扫光动画 TimelineView)/Bezier 边；
节点卡 SwiftUI 视图 overlay 定位（transform 共享 pan/zoom state）；语义缩放=
scale 阈值切 ViewState（far/near），far 隐藏清单按 V6 §7.2；手势：DragGesture pan、
MagnifyGesture/scrollWheel zoom（鼠标锚点数学同 V6 §7.1）；数据：EventEnvelope 流
fold 成 per-project 节点表（worktree_id 稳定键），布局引擎初始按主轴时间线排布、
用户拖拽偏移持久化 UserDefaults。golden：固定 fixture 流渲染截图比对（双渲染一致）。
