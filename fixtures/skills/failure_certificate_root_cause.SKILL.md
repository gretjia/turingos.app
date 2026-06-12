---
skillId: app.turingos.skill.failure_certificate_root_cause
version: 0.1.0
description: Analyse a CI/agent failure and produce a structured root-cause certificate with a corrective action plan.
triggerExamples:
  - Root-cause this CI failure
  - Write a failure certificate for the last red build
  - Why did the test suite fail?
  - Analyse the failure node and propose a fix
requiredTools:
  - file_read
  - git_log
  - ci_evidence_read
allowedActionClasses:
  - class_0_read
  - class_1_reversible_local
credentialScopes:
evals:
  - tests/failure_cert_install.yaml
  - tests/failure_cert_replay.yaml
failureModes:
  - Failure log not found or truncated
  - Insufficient context to distinguish root cause from symptom
  - CI evidence collector returns partial data
scriptRefs:
  - scripts/collect_failure_evidence.sh
inputSchemaRef: schemas/failure_cert_input.json
outputSchemaRef: schemas/failure_cert_output.json
receiptSchemaRef: schemas/failure_cert_receipt.json
---

## Instructions

You are the `failure_certificate_root_cause` skill.  Your job is to analyse a recorded
failure (CI failure node, agent error, or test regression) and emit a structured
Failure Certificate.

### Sections of the certificate

1. **Failure summary** — one sentence: what failed, where, when.
2. **Root cause** — distinguish symptom (what broke) from cause (why it broke).
3. **Evidence** — cite specific log lines, test names, error messages, or tape refs.
4. **Corrective action plan** — ordered list of concrete steps to fix the issue.
5. **Recurrence guard** — what predicate or test would catch this class of failure
   in future?

### Constraints

- Read evidence from CI logs and tape; do NOT modify any file.
- Do NOT produce a certificate that lacks a root-cause (symptom-only reports are
  insufficient).
- The corrective action plan must name specific files, tests, or configuration
  changes — not vague advice.
- Emit a `class_0_read` action receipt (no writes performed by this skill).
