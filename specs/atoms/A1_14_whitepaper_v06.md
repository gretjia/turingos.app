---
atom: A1_14_whitepaper_v06
phase: "1"
intent: >
  白皮书 v0.5 → v0.6 "Two-Scale Sovereign Kernel Correction"。按用户 2026-06-15 终裁指令
  + Veto-AI PASS（research/R_v06_directive.md），把 TuringOS 内部微观 ChainTape（主权微观
  账本）与用户项目 GitHub 宏观执行链路（PR/CI/merge）分层，消解 §4.3/§8/§13.4/§14.4/§18
  的同源尺度错配。核心定理：Internal ChainTape is the sovereign micro-ledger; GitHub is the
  macro execution substrate; a commit/PR/merge is not a node, it is a macro artifact
  crystallized from many micro nodes and anchored back into ChainTape as provenance.
  落实 B1–B5（尺度/橡皮颠倒/签名漏门/图间契约/批准完整性）+ M1–M8。Phase A 范围：只改
  WHITEPAPER.md + 归档指令 + ADR-019（two-scale ruling）+ 递归审计装置；不动 contracts、
  不动产品代码（Phase B 契约包 / Phase C 实现重排各自后置、走 ratification）。
allowlist:
  - "WHITEPAPER.md"
  - "ADR.md"
  - "research/**"
  - "scripts/predicates/**"
  - "specs/atoms/**"
max_new_files: 6
predicates:
  - "bash scripts/shipgate.sh p1"
  - "bash scripts/predicates/audit_whitepaper_v06.sh"
verified_external_facts: []
ux_touchpoints: >
  none — 顶层 spec 修订；但它是后续所有实现 atom（minimal sovereign kernel、protocol
  gateway、external adapters）的法理蓝本，错则全错。
gate: "bash scripts/shipgate.sh p1 && bash scripts/predicates/audit_whitepaper_v06.sh"
---

# 代码思路

按 `research/R_v06_directive.md` 的逐节清单（29 行）做 surgical edit，不做整篇 rewrite：
保留正确的部分，只改指令标红处。次序 = 先脊（§4.1/§4.2/§4.3/§8/§7.0.1/§11/§19）后枝
（§0/§1/§5/§6/§13/§14/§18 措辞）。

递归审计 = 12 条不变量（指令 §七）：
- 机械可 grep 项（1/2/5/6/10/11）由 `scripts/predicates/audit_whitepaper_v06.sh` 自动检查；
- 语义项（3/4/7/8/9/12）由独立 clean-context agent 审；
- 循环修到 12/12 PASS 才过闸（drift 防护）。

Phase B（契约包：tape_node scale/node_kind 字段、approval_card/signed_decision/
init_spec_package/budget_autonomy_contract/project_ready/macro_artifact_anchor schema、
provenance 四级 enum、12 类 flow_edge_event registry）与 Phase C（minimal sovereign
kernel 前移）各自另立 atom，走 Veto + compatibility + 签名 #7 / ratification。
