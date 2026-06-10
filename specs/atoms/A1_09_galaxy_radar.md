---
atom: A1_09_galaxy_radar
phase: "1"
intent: >
  星系空间视图（五次裁决：从首页降格为**探索性下钻**，材质语言沿用 V6，信息层级按
  Software 3.0 三定律重构）：星云/主轴/Bezier 连线 Canvas + 节点 overlay；
  **节点默认只有标题 + 状态辉光**，选中聚焦才展开（分支/指纹/证据抽屉）；
  pan/zoom（鼠标位锚定 0.1-2.0）+ 语义缩放；从 Attention Stack 点入注意力项
  直接飞到对应节点并聚焦。五节点形态绑 daemon 真实流。golden 快照 + 可达性
  0/1 谓词进 shipgate。布局状态=本地偏好不上 tape。反模式黑名单适用
  （默认态节点不得渲染多行数据卡）。
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
