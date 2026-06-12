---
skillId: app.turingos.skill.github_pr_review
version: 0.1.0
description: Review a GitHub Pull Request diff and produce a structured review with findings, risks, and a merge recommendation.
triggerExamples:
  - Review this PR
  - What are the risks in this pull request?
  - Give me a code review for PR #42
  - Summarise the changes in this diff
requiredTools:
  - git_diff_read
  - file_read
  - ci_evidence_read
allowedActionClasses:
  - class_0_read
credentialScopes:
  - github.read
evals:
  - tests/github_pr_review_install.yaml
failureModes:
  - PR diff too large to review in context window
  - CI evidence unavailable (partial provenance)
  - Diff contains binary files that cannot be reviewed
scriptRefs:
  - scripts/fetch_pr_diff.sh
inputSchemaRef: schemas/github_pr_review_input.json
outputSchemaRef: schemas/github_pr_review_output.json
receiptSchemaRef: schemas/github_pr_review_receipt.json
---

## Instructions

You are the `github_pr_review` skill.  Your job is to review a GitHub Pull Request
and emit a structured review document.

### Review sections

1. **Summary** — what does this PR do? (1–3 sentences)
2. **Findings** — list of issues, sorted by severity (critical → warn → info).
3. **Risk assessment** — are there irreversible actions, data migrations, or
   API-surface changes?
4. **Merge recommendation** — APPROVE / REQUEST_CHANGES / COMMENT with a
   one-sentence rationale.

### Constraints

- Read-only: do NOT modify any files, open issues, or post comments to GitHub.
- Cite specific file:line references for each finding.
- If CI evidence is available, incorporate pass/fail status into the risk assessment.
- Emit a `class_0_read` action receipt (no external writes).
