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
  # 2026-06-11 留痕：MIN_TESTS 法证下限随真实测试数增长（38→53），常量在
  # build_app.sh —— 与 A1_07/A1_08 同款 M5 扩列。
  - "scripts/build_app.sh"
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

# 实现裁定（2026-06-11，开工前定稿）

- **诚实形态映射**：P1 只读流无 merge/验证事实 ⇒ **green 保留不用**（测试钉死
  Form.semantic ∌ green）；V6 五形态落地为 anchor（=worktree.path 与注册 path
  词法归一后相等的事实见证，绝不用分支名启发式）/ active(dirty) / conflict
  (same_branch_conflict) / orphan(prunable) / failed(fingerprint_error) + quiet。
- **边只画真耦合**：membership（成员→主轴锚点，同 repo 事实）+ conflictTension
  （同分支组成员，黄粗）。V6 的 merge-back/cross-tag 边等 P2+ 事实到位再回归。
- **委托延期（ux_touchpoints 两项，留痕不豁免）**：Agent Chip occupant 推断态
  需 AgentSessionEnded↔worktree 联动语义（当前 fixture/contract 无实例，不猜）；
  FSEvents hint_only 蓝脉冲需 FileChanged 折叠 + 瞬态衰减机制。两项移交后续
  atom（P5 adapters 前后），本卡 intent 主体（五形态/缩放/飞行/golden/a11y）全交付。

# S-stage 对抗双审留痕（2026-06-11）

双 Critic（law 透镜 + correctness 透镜，活探针含真窗口坐标实测）裁定 6 blocker
（去重后）+ 13 risk；全部修复后 53/53 测试、shipgate p1 16/16 全绿：

1. **断连后星系仍装活**（双 critic 同根裁定）：radar 不读 connection，蓝呼吸/
   扫光在死流上永续 → 新增 RadarMood 纯函数（live/banner，句子走模板白名单），
   非 connected ⇒ 全域 grayscale + 呼吸/扫光停 + 可见 banner；旧事实仍可读
   （标注而非隐藏）。测试 testMoodSuppressesActivityOverDeadStream。
2. **windowToLocal 差标题栏高度**（critic 活探针真窗口实证）：contentLayoutRect
   与 geo.global 系不重合 → 删坐标重算，MonitorView 自身 isFlipped + AppKit
   convert() 视图内转换 + bounds 自检 + hitTest nil 惰性化。
3. **形态优先级吞张力边**：conflictGroups 按 form==.conflict 过滤，fingerprint
   失败成员掉边 → RadarNode 携带 sameBranchConflict 事实，边按事实派生，形态
   chrome 保持优先级。测试 testConflictTensionSurvivesFingerprintFailure。
4. **手势取消态腐化**：panLast/magnifyLast/nodeDragLast 手工状态在取消时不复位，
   下一次手势瞬移且坏偏移持久化 UserDefaults → 全部改 @GestureState（取消自动
   复位）+ displayCamera 渲染时合成，提交只在 onEnded。
5. **a11y 摸不到下钻**（law 2）：children:.ignore 吞掉 查看证据 与明细 →
   NodeCardContent.accessibilityValue + accessibilityActions{查看证据}（仅当
   showsEvidenceAction）。测试 testSelectedCardContentSpeaksDetailToAssistiveTech。
6. **断连行假 fly-to 动作**：无条件 accessibilityAction 在 target==nil 时静默
   no-op → 条件化（仅 onFlyTo 存在时枚举）。

Risk 处置：golden 判别力不足（fixture 无 path/冲突事实）→ 新增合成混合场景
golden a1_09_mixed_scene.golden.txt 字节钉死五形态+锚点+双边（fixtures/snapshots/
在 allowlist 内，不动 event_streams）；偏移仅 onAppear 加载 → onChange(scene)
增量合并；路径词法归一（trailing slash/`.`）进锚点见证 + 测试；扫光 30fps 在
非 live 时暂停（含省电）；camera 动画与 Canvas 去同步 → 改瞬时定位。
**登记债务**：camera 补间动画（Animatable 化）；锚点 symlink/unicode 等价需
daemon 侧 canonical 事实；逐 envelope 全场景重派生（重放风暴，与 triage 同模式）；
NSEvent monitor 在 window-dealloc-without-detach 极端路径的泄漏；多 anchor
退化场（git 不可能两 worktree 同 path，仅理论）。
**旁证**：repo 根部 audit_data/（critic_A_signer/machine_sweep/mutants，
01:34 仍在写）= R1.9 审计 runbook 的并行会话活体数据，本 atom 不触碰不提交。
