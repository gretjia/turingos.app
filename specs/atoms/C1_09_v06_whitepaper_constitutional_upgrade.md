---
atom: C1_09_v06_whitepaper_constitutional_upgrade
phase: "1"
intent: >
  Upgrade WHITEPAPER.md from v0.5 positioning document to a v0.6
  constitutional-level design document aligned line-by-line with
  research/R_v06_directive.md, ADR-019, and constitution/constitution.md,
  then record an explicit clean-context constitution audit.
allowlist:
  - "specs/atoms/C1_09_v06_whitepaper_constitutional_upgrade.md"
  - "specs/atoms/CURRENT"
  - "specs/atoms/receipts/C1_09_v06_whitepaper_constitutional_upgrade.receipt"
  - "WHITEPAPER.md"
  - "research/WHITEPAPER_v06_constitution_audit.md"
max_new_files: 3
predicates:
  - "test \"$(head -1 WHITEPAPER.md)\" = '# Turing Agentic OS 白皮书 v0.6'"
  - "grep -q 'Two-Scale Sovereign Kernel' WHITEPAPER.md"
  - "grep -q 'Micro ChainTape' WHITEPAPER.md"
  - "grep -q 'Macro artifacts are not Micro nodes' WHITEPAPER.md"
  - "test \"$(grep -c '^```mermaid' WHITEPAPER.md)\" -ge 5"
  - "grep -q 'Flowchart Interface Contract' WHITEPAPER.md"
  - "grep -q 'SystemConstitutionAccepted' WHITEPAPER.md"
  - "grep -q 'MacroArtifactAnchor' WHITEPAPER.md"
  - "grep -q 'CONSTITUTIONAL PRODUCT CHARTER FOR turingos.app v0.6' WHITEPAPER.md"
  - "grep -q 'HEAD_t^micro' WHITEPAPER.md"
  - "grep -q 'MacroMergeAuthorization' WHITEPAPER.md"
  - "grep -q 'ExternalActionAuthorization' WHITEPAPER.md"
  - "grep -q 'receipt matches MacroMergeAuthorization' WHITEPAPER.md"
  - "grep -q 'MacroMergeReceiptMismatch' WHITEPAPER.md"
  - "grep -q 'Additional internal event types used inside loops' WHITEPAPER.md"
  - "grep -q 'Phase E gate forces Path B unless a human sudo constitutional amendment explicitly lowers the fidelity requirement' WHITEPAPER.md"
  - "grep -q 'The detailed certification audit MUST be maintained' WHITEPAPER.md"
  - "grep -q 'HALT_CONSTITUTIONAL_PENDING' WHITEPAPER.md"
  - "grep -q 'No irreversible Macro action' WHITEPAPER.md"
  - "! grep -q 'H4 -->|\"批准\"| EXE' WHITEPAPER.md"
  - "! grep -q 'POSTANCHOR --> GC' WHITEPAPER.md"
  - "! grep -q 'Phase E 默认逼近 Path B' WHITEPAPER.md"
  - "grep -q 'Incident Review' research/WHITEPAPER_v06_constitution_audit.md"
  - "grep -q 'Final Recursive Constitutional Audit Repairs' research/WHITEPAPER_v06_constitution_audit.md"
  - "grep -q 'Line-to-Constitution Audit' research/WHITEPAPER_v06_constitution_audit.md"
  - "bash scripts/shipgate.sh p1"
verified_external_facts: []
ux_touchpoints: >
  document-only. No UI behavior changes; no constitution edits.
gate: "bash scripts/shipgate.sh p1"
---

# Implementation Sketch

Rewrite `WHITEPAPER.md` as v0.6, retaining the constitutional design philosophy
while making the two-scale boundary load-bearing. Add an audit artifact mapping
whitepaper lines/sections to constitution articles, directive invariants, and
ADR-019. Do not edit `constitution/constitution.md`.
