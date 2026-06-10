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
