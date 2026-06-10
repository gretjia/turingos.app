---
atom: A1_08_attention_home
phase: "1"
intent: >
  Software 3.0 首页（五次裁决重切，取代原 A1_08 星系画布首页定位）：Attention Stack
  三段分诊（等你/进行中/安静，空段折叠）+ Glance 一句话化（一个点 + 一句话 + 仅有事时
  的注意力项列表）。注意力项 = 确定性模板句（同投影⇒同句子）+ 点击直达证据事件；
  全部健康 ⇒ 整屏一句"一切安静"。数据源 = A1_06 分桶投影 + 逐 worktree 异常明细
  （WorktreeDiscovered 最新 payload 折叠）。反模式黑名单进测试（无三计数并排网格）。
allowlist:
  - "app/**"
  - "scripts/shipgate.sh"
  # 2026-06-11 留痕：法证测试下限 MIN_TESTS 随真实测试数增长，常量在 build_app.sh
  # —— 与 A1_07 同款 M5 扩列。
  - "scripts/build_app.sh"
max_new_files: 12
predicates:
  - "bash scripts/build_app.sh"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "异常明细与项目分桶已由 daemon 完整供给（A1_02-A1_06）；分桶 active_sessions/pending_proposals 结构性为 0 直至 P5（A1_06 卡债务 b）——本卡句子模板只陈述有数据支撑的事实，不渲染假活数"
    source: "specs/atoms/A1_06_daemon_multi_repo.md 修订记录"
    verified_on: "2026-06-10"
ux_touchpoints: >
  三定律的第一落地面。句子模板域（P1 只读）：同分支冲突/prunable 孤儿/fingerprint
  失败/daemon 断连/未提交改动现状/一切安静。模板句是确定性投影（非 generated，
  不戴 R3 徽章）；P6+ 引入生成式解读时按 R_GENUI 全套法律升级。
gate: "bash scripts/shipgate.sh p1"
---

# 代码思路

WorktreeLedger（fold WorktreeDiscovered/Removed 最新 payload per worktree，含
project 归属）→ AttentionItem 派生（severity 排序：失败>裁决>断连）+ SentenceTemplates
（确定性，表驱动，单测钉字节）；AttentionStackView 三段（空段折叠）；GlancePopover
重写为一句话形态；"一切安静"空态全屏。测试：句子模板表驱动金标、分诊排序、
空态/折叠逻辑、反模式守卫（视图树无三计数并排结构——以 ViewInspector 或快照断言）。

# S-stage 对抗双审留痕（2026-06-11）

双 Critic（带活探针）+ 清洁上下文 Veto 复核，裁定 10 项；全部修复后 38/38 测试、
shipgate p1 16/16 全绿。逐项裁定 → 修复：

1. **落地屏阻断**（blocker）：默认选中 `.worktreeRadar` 落在 A1_09 占位页，
   atom 交付物不是用户打开看到的东西 → `ContentView.selection` 默认 `.globalOps`。
2. **幻影项目**（blocker）：`project_id ?? "?"` 把违约事件物化成假活动行 →
   Ledger 对缺 id 事件 guard-drop（不物化），新增 testPhantomEventsAreDropped。
3. **同冲突 N 行 = 计数不是分诊**：同 project+branch 的冲突按组聚合为一个裁决项，
   `sameBranchConflict(group:)` 列出全部成员名，evidence 改 `.array`（抽屉分段渲染），
   新增 testSameBranchConflictGroupsToOneItem。
4. **id 字符串考古**：归因集合改由 facts 直接构建，不再反解析 item.id。
5. **灰态回归**（blocker）：connecting/disconnected 必须压灰 glance（绝不在死流
   上戴自信的红/黄/蓝；旧项仍列在栈里）→ derive 的 connection override，
   新增 testConnectionStateOverridesGlance + 排序测试断言改写。
6. **Popover 截断不可见 + a11y 吞条目**：prefix(4) 后补可见溢出句
   `popoverOverflow(hidden:)`；删除把全列表合并成单条 VoiceOver 元素的顶层
   `.accessibilityElement(children:.combine)`，改为逐条目合并。
7. **三处每帧重派生**：menubar 点/popover/home 改读 GlanceStore 上的单一缓存
   `triage`（消费循环每轮派生一次）。
8. **反模式守卫无判别力**：CJK 散文启发式升级为句子文法白名单
   `Sentences.templates` + `matchesTemplate`，守卫测试含负对照（"活跃: 3" 必红）。
9. **shortName 误剥尾段**：仅当尾段确为 8 位 hex digest 才剥（"wt_release_v2"
   保全名），新增 testShortNameOnlyStripsRealDigests。
10. **色彩单通道**：severity 增加 `iconName`（octagon/triangle/bolt），行徽章
    图标+颜色双通道（VISUAL_SEMANTICS rule 3）。

MIN_TESTS 34→38（随真实测试数增长，allowlist 已留痕扩列）。
