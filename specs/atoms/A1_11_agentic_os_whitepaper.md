---
atom: A1_11_agentic_os_whitepaper
phase: "1"
intent: >
  Turing Agentic OS 白皮书双交付（用户裁决 2026-06-11：战略转向 macOS 个人 agent
  治理层——同意/可见性/审计/可撤销，协作式 MCP 网关，draft-by-default，Touch ID
  批准仪式）。交付 WHITEPAPER.md（愿景+治理模型+三类动作+Apple 集成+覆盖边界
  诚实声明）与 FEASIBILITY.md（每条论断标 verified/unverified，含来源 URL 与
  日期）。调研双线：Apple 平台可行性（Foundation Models / Containerization /
  App Sandbox / Touch ID+SE / Developer ID 公证分发 / 可见性接入方式与 OS 级
  途径的批准门槛）+ Agent 生态（OpenClaw / Hermes 架构・采用度・安全记录；
  OpenClaw / Hermes / Claude Code / Codex 的第三方 MCP 网关可行性与覆盖边界）。
  设计操守不可动摇：只治理自愿接入的 agent、不可逆动作只能 draft-by-default、
  批准记录含"批准时看到了什么"、覆盖边界如实披露。
allowlist:
  - "WHITEPAPER.md"
  - "FEASIBILITY.md"
  - "research/R_agentic_os_sources.md"
max_new_files: 3
predicates:
  - "test -s WHITEPAPER.md && test -s FEASIBILITY.md"
  - "grep -c 'verified' FEASIBILITY.md 输出 > 20（每条论断带标注）"
  - "bash scripts/shipgate.sh p1"
verified_external_facts:
  - fact: "调研即本卡主体，外部事实全部经 WebSearch/WebFetch 实证后入 FEASIBILITY.md 并逐条标注 verified/partially-verified/unverified + 来源 + 日期"
    source: "本卡工序"
    verified_on: "2026-06-11"
gate: "bash scripts/shipgate.sh p1"
---

# 工序

1. 双 workflow 并行调研（Apple 平台线 + Agent 生态线），每线多角度 fan-out +
   load-bearing 论断对抗复核（refute 票决）。
2. 架构师本体撰写两份文档（C 级写作不降档），论断只引用调研产出的 claim 库。
3. 对抗双审（诚实性 critic 对照 claim 库逐条核对 FEASIBILITY 标注；结构/语言
   critic 审 WHITEPAPER 过度承诺），修复后 Sonnet 核验。
4. shipgate 全绿（注意 #5 市场断言禁语、#10 死链）→ 回执 → PR。
