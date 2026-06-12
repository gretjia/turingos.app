---
atom: A1_13_whitepaper_v05_protocol_native
phase: "1"
intent: >
  白皮书 v0.5：依用户 8 条评审 + GPT 对谈（原文归档入 research/）完成定位升级——
  Apple-native + protocol-native。新增/改写：Agentic 协议层（MCP 核心 / A2A 适配 /
  MCP Apps 优先观察 / View IR 统一投影 + 批准卡第一方渲染铁律）；Capability
  Registry（白盒能力注册表，Install≠trust，manifest+权限+动作类+eval+入带，未声明
  类别 fail-closed）；Model Gateway（OpenAI-compatible / Anthropic Messages /
  Apple FM 本地 / 外部 agent 委托面四类，订阅≠API 计费事实修正，ModelCall 入带）；
  Skill Library（Turing Skill = 法律外壳化的 SKILL.md，12 类初始库）；Live
  Software 3.0 回路（=回路 3 扩展：失败聚类→候选白盒工件→Veto→eval→签名→入带；
  自我迭代对象是白盒脚手架非黑盒自变异；adapter 产物永不获谓词门权威）；Hostile
  Host 安全模型（Tier1 Mac 本地签名 / Tier2 外部 Sudo-Anchor，威胁阶梯 T0-T3，
  不夸大 SE 的 WYSIWYS）；Canvas Projection（Freeform 诚实降级）；外部 Agent
  Adapter Contract（Git-first）。GPT 外部论断全部经四路调研实证后才入稿（含其对
  用户的 4 处纠正本身）。
allowlist:
  - "WHITEPAPER.md"
  - "FEASIBILITY.md"
  - "research/R_v05_protocol_live_sources.md"
  - "research/REVIEW_v04_user_gpt_dialogue.md"
max_new_files: 2
predicates:
  - "grep -q 'protocol-native' WHITEPAPER.md（定位升级入稿）"
  - "grep -q 'Capability Registry' WHITEPAPER.md && grep -q 'Hostile Host' WHITEPAPER.md"
  - "grep -q 'Part IV' FEASIBILITY.md（v0.5 调研论断附录）"
  - "test -s research/R_v05_protocol_live_sources.md && test -s research/REVIEW_v04_user_gpt_dialogue.md"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "v0.5 新增外部论断全部出自本卡四路调研产出 research/R_v05_protocol_live_sources.md（逐条 verified/partially-verified/refuted/unverified + URL + 日期）；A1_11 既有论断沿用其 claim 库"
    source: "research/R_v05_protocol_live_sources.md"
    verified_on: "2026-06-12"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. 用户评审 + GPT 对谈原文归档（tape 纪律）；四路 Sonnet 调研 fan-out（协议层 /
   模型接入经济学 / Live Software 与 Apple adapter 训练 / Freeform 与 hostile-host
   先例），每路带 claim schema 与对抗性核验指令。
2. 架构师本体（C 级不降档）：甄别调研结论 → 在 v0.4 上手术式改写 v0.5（不重写全文）；
   GPT 方案的超越点：批准卡第一方渲染铁律、ModelCall 入带与 Art. 0.2 张力的诚实解、
   Live loop 与回路 3 合一、chipTAN/硬件钱包先例引入 Tier2 论证、路线图单梯合并。
3. 对抗双审（C 级：宪法+意图忠实度 / 诚实性+一致性，强制 readVerification）+
   Haiku lint，修复后收口。
4. shipgate 全绿 → 回执 → 更新 PR #26 为 v0.5（白皮书属用户 ratification 域，
   不自动合并）。
