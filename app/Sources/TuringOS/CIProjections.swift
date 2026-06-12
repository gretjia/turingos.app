// CIProjections.swift — A1_20: deterministic projection factories for CI observation.
//
// Design contract:
//   • Pure functions — same input always produces byte-identical output.
//   • No git invocations, no network, no model calls, no FileManager writes.
//   • All documents carry non-empty derive_source (P1 predicate).
//   • RepairPromptProjection: deterministic factory (failed check summary +
//     nearest predicate text + worktree scope) → repair_prompt View IR block.
//   • DossierDraftProjection: deterministic factory assembling a dossier_view
//     IR document (clearly labeled 草案/draft; approval_route as display text only).
//   • IntentRouter integration: "ci"/"检查" intent + project context →
//     dossier draft / CI status summary; degrades gracefully when gh unavailable.

import Foundation

// MARK: - RepairPromptProjection

/// Deterministic factory: failed check summary + predicate text + worktree scope
/// → repair_prompt ViewIRDocument.
/// Same inputs → byte-identical output (pure function — no model, no randomness).
public enum RepairPromptProjection {

    /// Build a repair_prompt document from failed check information.
    ///
    /// - Parameters:
    ///   - failedChecks:       Summary of which checks failed.
    ///   - nearestPredicate:   The nearest acceptance predicate from the spec (plain text).
    ///   - worktreeScope:      The worktree scope declaration.
    ///   - failureNodeRef:     Reference to the failure node in the tape (or "draft").
    ///   - deriveSource:       Traceability tag (PR/commit identifiers).
    public static func make(
        failedChecks: [String],
        nearestPredicate: String,
        worktreeScope: String,
        failureNodeRef: String,
        deriveSource: String
    ) -> ViewIRDocument {
        let failedSummary: String
        if failedChecks.isEmpty {
            failedSummary = "（无已知失败的检查）"
        } else {
            failedSummary = failedChecks.map { "- \($0)" }.joined(separator: "\n")
        }

        let suggestedPrompt = """
        【修复建议 — 草案/draft · 仅供参考，不阻塞谓词门】

        失败的 CI 检查：
        \(failedSummary)

        最近谓词：\(nearestPredicate)

        Worktree 范围：\(worktreeScope)

        请在 \(worktreeScope) 范围内修复上述检查失败，保持 diff 在允许路径内，不触碰禁止文件。
        """

        let payload = RepairPromptPayload(
            failureNodeRef: failureNodeRef,
            suggestedPrompt: suggestedPrompt,
            targetWorktree: worktreeScope
        )

        return ViewIRDocument(
            kind: "repair_prompt",
            deriveSource: [deriveSource, "ci_observation:repair_projection"],
            blocks: [.repairPrompt(payload)]
        )
    }
}

// MARK: - DossierDraftProjection

/// Deterministic factory: assembles a dossier_view IR document from
/// CI evidence + spec summary + provenance + risk findings.
///
/// The document is clearly labeled 草案/draft — no verdict is included here
/// (verdicts live exclusively in the Predicate Gate / tape write path,
/// which is NOT part of this atom's scope).
public enum DossierDraftProjection {

    /// Assemble a dossier_view draft document.
    ///
    /// - Parameters:
    ///   - specSummary:       One-sentence spec/intent summary.
    ///   - ciEvidence:        The CIEvidence assembled by CIEvidenceCollector.
    ///   - changedFiles:      List of changed file paths.
    ///   - provenanceLevel:   FULL / REPO_LEVEL / PARTIAL / OUTSIDE_GOVERNANCE.
    ///   - riskFindings:      Advisory findings (NO verdict — advisory only).
    ///   - approvalRouteText: Display text for the approval route (display only —
    ///                        not a machine-evaluated field at this projection layer).
    ///   - prRef:             PR number or identifier for derive_source.
    ///   - commitRef:         Commit SHA for derive_source.
    public static func make(
        specSummary: String,
        ciEvidence: CIEvidence,
        changedFiles: [String],
        provenanceLevel: ProvenanceLevel,
        riskFindings: [RiskFinding],
        approvalRouteText: String,
        prRef: String,
        commitRef: String
    ) -> ViewIRDocument {
        // Derive source cites the PR and commit identifiers for traceability.
        let deriveSource = [
            "ci_observation:pr:\(prRef)",
            "ci_observation:commit:\(commitRef)",
            "dossier_draft_projection"
        ]

        // Summary card: clearly labeled as draft.
        let conclusionDisplay = ciEvidence.conclusion == "success"
            ? "CI 通过（draft 观测）" : "CI 未全通过或数据不足（draft 观测）"
        let changedFilesSummary = changedFiles.isEmpty
            ? "（无）"
            : changedFiles.prefix(5).joined(separator: "\n  ") +
              (changedFiles.count > 5 ? "\n  … 共 \(changedFiles.count) 个文件" : "")

        let body = """
        ⚠️ 草案/DRAFT — 仅供人工审阅，不产生谓词门裁决。

        意图摘要：\(specSummary)
        Commit：\(ciEvidence.commitSha)
        Merge base：\(ciEvidence.mergeBase)
        工作流哈希：\(ciEvidence.workflowFileHash)
        CI 结论：\(conclusionDisplay)
        Runner 类型：\(ciEvidence.runnerType)
        Provenance 级别：\(provenanceLevel.rawValue)
        审批路由（仅展示）：\(approvalRouteText)

        变更文件：
          \(changedFilesSummary)

        Check run IDs：\(ciEvidence.checkRunIds.prefix(5).joined(separator: ", "))
        """

        let summaryCard = SummaryCardPayload(title: "Dossier 草案", body: body)

        // risk_list block: advisory findings only.
        let riskItems = riskFindings.map { finding in
            RiskItem(level: "warn", text: "[\(finding.dimension)] \(finding.note)")
        }

        // dossier_view block: references the draft ID.
        let dossierRef = "draft:ci_obs:pr:\(prRef):commit:\(String(commitRef.prefix(8)))"
        let riskTexts = riskFindings.map { "[\($0.dimension)] \($0.note)" }
        let dossierViewPayload = DossierViewPayload(
            dossierRef: dossierRef,
            riskFindings: riskTexts,
            provenance: provenanceLevel.rawValue,
            signatureNode: 5
        )

        var blocks: [ViewIRBlock] = [
            .summaryCard(summaryCard),
            .dossierView(dossierViewPayload),
        ]
        if !riskItems.isEmpty {
            blocks.append(.riskList(RiskListPayload(items: riskItems)))
        }

        return ViewIRDocument(
            kind: "dossier_draft",
            deriveSource: deriveSource,
            blocks: blocks
        )
    }
}

// MARK: - CIStatusProjection

/// Deterministic factory: CIEvidence → summary_card + evidence_list.
/// Used by the intent router for "ci"/"检查" intents.
public enum CIStatusProjection {

    public static func make(
        ciEvidence: CIEvidence,
        prNumber: Int,
        deriveSource: String
    ) -> ViewIRDocument {
        let conclusionLabel = ciEvidence.conclusion == "success"
            ? "✓ 通过" : (ciEvidence.conclusion == "unavailable" ? "数据不可用" : "× 未全通过")

        let summaryBody = """
        PR #\(prNumber) · Commit：\(String(ciEvidence.commitSha.prefix(8)))
        CI 结论：\(conclusionLabel)
        Runner：\(ciEvidence.runnerType)
        工作流哈希：\(ciEvidence.workflowFileHash)

        ⚠️ 这是 draft 观测投影 — 不产生谓词门裁决。
        """
        let summaryCard = SummaryCardPayload(
            title: "CI 观测摘要（草案）",
            body: summaryBody
        )

        // Evidence list: one item per check run ID.
        let evidenceItems = ciEvidence.checkRunIds
            .filter { $0 != "unavailable" }
            .map { id in
                EvidenceItem(
                    kind: "ci_check",
                    label: "Check run \(id)",
                    ref: "gh:check_run:\(id)"
                )
            }

        var blocks: [ViewIRBlock] = [.summaryCard(summaryCard)]
        if !evidenceItems.isEmpty {
            blocks.append(.evidenceList(EvidenceListPayload(items: evidenceItems)))
        }

        return ViewIRDocument(
            kind: "ci_status",
            deriveSource: [deriveSource, "ci_observation:status_projection"],
            blocks: blocks
        )
    }
}

// MARK: - GH unavailable notice

/// Deterministic template notice when gh CLI is not available.
public enum CIUnavailableNotice {
    public static func make(reason: String = "gh CLI 不可用") -> ViewIRDocument {
        let card = SummaryCardPayload(
            title: "CI 观测不可用",
            body: """
            \(reason)

            CI 检查数据暂无法获取。请确认：
            1. gh CLI 已安装并登录（gh auth status）
            2. 仓库已连接 GitHub
            3. 有查看 PR 的权限

            当前将展示占位投影 — 不产生谓词门裁决。
            """
        )
        return ViewIRDocument(
            kind: "ci_status",
            deriveSource: ["template:ci_unavailable"],
            blocks: [.summaryCard(card)]
        )
    }
}

// MARK: - IntentRouter integration for "ci"/"检查" intents

extension IntentRouter {

    /// Route "ci"/"检查" intents to CI observation projections.
    ///
    /// Returns nil if the input does not match a CI intent (falls through to
    /// the existing routing table in OrbState.swift).
    internal static func routeCIIntent(
        lower: String,
        observationSource: (any RepoObservationSource)?,
        projectContext: String?
    ) -> ViewIRDocument? {
        guard lower.contains("ci") || lower.contains("检查") || lower.contains("check") else {
            return nil
        }

        guard let source = observationSource else {
            return CIUnavailableNotice.make()
        }

        // Try to read current CI status for the first open PR.
        let prs = (try? source.openPRs()) ?? []
        guard let pr = prs.first else {
            return CIUnavailableNotice.make(reason: "无打开的 PR（或 gh CLI 不可用）")
        }

        let evidence = CIEvidenceCollector.assemble(
            from: source,
            prNumber: pr.number,
            headRef: pr.headRefName
        )

        let deriveSource = "\(source.deriveSourceTag):pr:\(pr.number)"
        return CIStatusProjection.make(
            ciEvidence: evidence,
            prNumber: pr.number,
            deriveSource: deriveSource
        )
    }

    /// Build a dossier draft projection from a PR + observation source.
    public static func dossierDraft(
        from source: any RepoObservationSource,
        prNumber: Int,
        headRef: String,
        specSummary: String = "（spec 摘要待填）",
        changedFiles: [String] = [],
        provenanceLevel: ProvenanceLevel = .repoLevel,
        riskFindings: [RiskFinding] = []
    ) -> ViewIRDocument {
        let evidence = CIEvidenceCollector.assemble(
            from: source,
            prNumber: prNumber,
            headRef: headRef
        )
        let commitRef = evidence.commitSha
        let approvalRouteText = provenanceLevel == .partial
            ? "signature_5（partial provenance 强制路由）"
            : "autonomy_contract 候选（需谓词门裁决）"

        return DossierDraftProjection.make(
            specSummary: specSummary,
            ciEvidence: evidence,
            changedFiles: changedFiles,
            provenanceLevel: provenanceLevel,
            riskFindings: riskFindings,
            approvalRouteText: approvalRouteText,
            prRef: "\(prNumber)",
            commitRef: commitRef
        )
    }
}
