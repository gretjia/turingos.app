---
atom: A1_12_whitepaper_v04_operating_flow
phase: "1"
intent: >
  白皮书 v0.4 统稿：以用户手写 v0.3（Apple-native Agentic OS + Facilitator/Meta/
  Architect/Veto/Worker 角色系统 + Software 3.0 UI + Lawful Auto Mode）为基底，
  深读 TuringOS 宪法后补全：(1) 完整 operating flow（Boot / 立法 / 执行 / Meta
  四回路 + 终止态 + stop-loss + 并发 + 异步人类注意通道）；(2) 宪法→产品逐条映射
  （Tape Canonical / Q_t 三元组 / 量化·广播·屏蔽 / 三权分立）；(3) 回收 v0.1 的
  操守五条、三类动作风险地图、逐 agent 覆盖边界（v0.4 单文档取代 v0.1 与 v0.3）。
  v0.3 用户原稿归档入 research/ 作为本次修订的 tape 证据。
allowlist:
  - "WHITEPAPER.md"
  - "research/WHITEPAPER_v0.3_user_draft.md"
max_new_files: 1
predicates:
  - "test -s WHITEPAPER.md && test -s research/WHITEPAPER_v0.3_user_draft.md"
  - "grep -c 'mermaid' WHITEPAPER.md ≥ 2（operating flow 多回路图入稿）"
  - "grep -q 'Art. 0.2' WHITEPAPER.md（宪法映射章节存在）"
  - "grep -q '操守' WHITEPAPER.md（v0.1 操守回收）"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "外部论断不新增——全部沿用 A1_11 已核 claim 库（research/R_agentic_os_sources.md，159 条，44/3/1 对抗复核）；v0.4 凡引外部事实仅限该库内已 verified 条目"
    source: "research/R_agentic_os_sources.md"
    verified_on: "2026-06-11"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. 架构师精读宪法全文（C 级不降档）+ fan-out 四路审计（宪法符合性 / v0.1 回归 /
   flow 完整性 → Sonnet；mermaid 与交叉引用 lint → Haiku），全部带显式 predicate。
2. 架构师本体综合审计结果，设计四回路 operating flow 与三级法律层级
   （系统宪法 / 项目 Init Spec / 任务谓词），撰写 v0.4 全文。
3. 对抗双审（宪法+意图忠实度 critic / 诚实性+内部一致性 critic，C 级），
   Haiku 复 lint 最终 mermaid，修复后收口。
4. shipgate 全绿 → 回执 → PR（白皮书内容属用户 ratification 域，PR 留待用户终审，
   不走 ADR-012 自动合并）。
