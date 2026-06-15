---
atom: A1_57_detail_card_popover_content
phase: "1"
depends_on: ["A1_55_galaxy_lod_render_fix"]
adr: "(吸收原 A1_58;DESIGN 三定律 语言优先/安静即成功;ADR-017 §C 诚实分支态)"
intent: >
  真机反馈 #5(用户多次提出):点击最小节点弹出的细节卡**横跨整屏**,且内容(状态/分支/HEAD)**对人类无意义**。
  本卡是 #5 的**完整修复**,吸收原 A1_57(popover 宽度)+ A1_58(按 kind 内容)为一颗(同一用户面、紧耦合,
  分开会留"popover 但内容仍无意义"的半修)。

  **根因(实锤,已读码)**:
  - 占满屏:`RadarNodeCard` 经 `nodeOverlay` 的 `.position(screenPosition)` 渲染 → 提议**全父宽**;选中态 `card`
    含贪婪 `Spacer(minLength:12)` + `.frame(minWidth: selected ? 180)` 无 maxWidth、无 `.fixedSize` → 撑满画布。
  - 内容无意义:`NodeCardContent.derive` 对**所有 kind** 派生同一套通用行(状态=form.label / 分支 / HEAD / 锁),
    且 branch/commit 节点 form 硬编码 `.quiet` → "状态" 恒显无意义的"安静";丢弃了 RadarNode 上已有的
    ahead/behind/mergeStatus/containedInDefault 等富信息。

  **修复**:
  - **A1_57 部分(popover,不占满屏)**:细节脱离 inline,改为锚定节点的**自尺寸 `.popover`**(`isPresented` =
    selected && 非 far;关闭即 onDismiss 取消选中)。inline 节点恒为**小 title chip**(`.fixedSize`,绝不撑宽)。
    popover 内容 `.frame(width: 260)` 有界,长值换行,且不遮挡邻节点(结构上不可能撑满)。
  - **A1_58 部分(按 kind 有意义内容,Software 3.0 语言优先)**:`NodeCardContent` 加 `headline: String?`
    (引导句),`derive` 按 `node.kind` 分派:
    - **branch**:headline = 合并/机会框定 —— isAnchor→"主干 · 默认分支";containedInDefault→"已在主线可达
      (≠ 已并入内容)";ahead>0&behind==0→"{ahead} 个 commit 待并入 — 未收割的机会";diverged→"分叉中:
      领先{ahead}/落后{behind}";else→"与主线一致"。行:分歧 ↑{ahead} ↓{behind} + HEAD。**绝不假绿、绝不
      声称 merged**(mergedIntoDefault 恒 false 不用;containedInDefault 仅可达性 + 免责)。
    - **commit**:headline "提交节点";行 commit(sha8)+ 所在分支(短名)。
    - **worktree**:headline = form.label(失败/冲突/孤儿/有未提交改动/安静 —— 对 worktree 本就有意义);
      行 分支/HEAD/锁(保留旧有意义信息)。

  **不动**:scene/positions/canonicalDump/契约/daemon(NodeCardContent 是视图层,不入 canonicalDump → golden 不变)。
  不新增 RadarNode 字段(只用已有字段)→ 无 golden 重生。
allowlist:
  - "app/Sources/TuringOS/RadarViews.swift"
  - "app/Sources/TuringOS/RadarModel.swift"
  - "app/Tests/TuringOSTests/RadarModelTests.swift"
  - "specs/atoms/A1_57_detail_card_popover_content.md"
  - "specs/atoms/NUMBERING.md"
  - "specs/atoms/CURRENT"
max_new_files: 0
predicates:
  - "bash scripts/shipgate.sh p1 全绿(16 门;过门前 pkill GUI app + 'turingosd serve' + 删 lock)"
  - "golden 不变:NodeCardContent 是视图层、不入 canonicalDump;不新增 RadarNode 字段 → fixtures/snapshots golden 逐字节不变(gate 12 绿)"
  - "**按 kind 内容测(机械)**:branch 节点 ahead=3/behind=0/containedInDefault=false → derive 出"未收割的机会"headline(不含"安静");commit 节点 → 含 sha8 行;worktree 节点 → headline 含 form.label。更新 testDefaultNodeIsTitleAndGlowOnly(selected 有 detail=headline||rows)+ testSelectedCardContentSpeaksDetailToAssistiveTech(按 kind:worktree 含 form.label,branch 含 ↑/机会/主线,commit 含 sha)以反映新模型"
  - "无回归:swift build+test 绿;far→无 title/无 detail、unselected→title only、selected→popover(grep 确认 detail 在 .popover 内,inline 仍为小 chip 且 .fixedSize)"
  - "**真机 UX 验证(我 computer-use)**:点击最小节点 → 细节是**锚定节点的有界 popover**(宽度远小于窗宽、贴合内容、不遮邻节点),非整屏长条;branch 节点 popover 首行是合并/机会句(非"安静"),commit 显 sha,worktree 显 dirty/locked/分支。前后对比截屏 /tmp/galaxy_evidence/card_*.png。"
verified_external_facts:
  - "BranchFact.mergeStatus 取值 = ahead/behind/identical/diverged/unknown(daemon branch_poller.rs:298 MergeStatus enum)— verified_on 2026-06-15"
ux_touchpoints: >
  节点细节卡不再占满屏(锚定节点的有界 popover);内容按 kind 有意义(branch 合并/机会框定、commit sha 身份、
  worktree dirty/锁)。真机点击截屏签字为完工硬条件。
gate: "bash scripts/shipgate.sh p1"

# 代码思路
## RadarModel.swift — NodeCardContent
- 加 `public let headline: String?`;== 与 accessibilityValue 纳入 headline。
- `derive` far→空;!selected→title only(headline nil);selected→ switch node.kind 分派 deriveBranch/Commit/Worktree(见上)。
## RadarViews.swift — RadarNodeCard
- body 渲染 chip(farDot | titleChip,后者 `.fixedSize()` 小卡)+ `.popover(isPresented: selected&&showsTitle, onDismiss→取消选中){ detailPopover }`。
- detailPopover:title 头 + headline 句 + detailRows + 查看证据;`.frame(width:260)` 有界。
- nodeOverlay 调用加 `onDismiss: { selectedNodeId = nil }`。
## RadarModelTests.swift
- 更新 2 处旧测到新模型 + 加按 kind 断言。
## 验证：shipgate p1 + golden 不变 + 真机 popover 截屏。
