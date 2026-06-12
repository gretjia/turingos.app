// EvalReportProjection.swift — Project an EvalReport to a ViewIRDocument (A1_28).
//
// BOUNDARY: pure projection — no IO, no network, no Date, no random.
//
// Uses EXISTING ViewIR blocks ONLY (ViewIR.swift UNCHANGED):
//   - risk_list  (RiskListPayload / RiskItem) for failed eval results.
//   - summary_card (SummaryCardPayload) for the overall qualified verdict.
//
// derive_source always non-empty: cites manifest id + "eval_harness:v1".

import Foundation

// MARK: - EvalReportProjection

/// Projects an `EvalReport` to a `ViewIRDocument` using existing ViewIR blocks.
///
/// Projection rules:
///   - One `risk_list` block listing every FAILED `EvalResult`.
///     Each item level is "warn" for non-required failures, "critical" for required.
///     If there are no failures, the risk_list block is omitted.
///   - One `summary_card` block with the qualified verdict and a count summary.
///   - `derive_source` = `["manifest:\(manifestId)", "eval_harness:v1"]` — always non-empty.
///
/// ViewIR.swift is NOT modified.
public enum EvalReportProjection {

    /// Project the given report to a `ViewIRDocument`.
    ///
    /// - Parameters:
    ///   - report:     The `EvalReport` to project.
    ///   - manifestId: The `CapabilityManifest.id` (for `derive_source`).
    /// - Returns: A `ViewIRDocument` using only existing ViewIR block types.
    public static func project(report: EvalReport, manifestId: String) -> ViewIRDocument {
        var blocks: [ViewIRBlock] = []

        // --- risk_list: failed evals ---
        let failedResults = report.results.filter { $0.verdict == .fail }
        if !failedResults.isEmpty {
            let riskItems: [RiskItem] = failedResults.map { result in
                // level: "critical" if this spec id is in the required set (qualified gate);
                // "warn" for informational (non-required) failures.
                // We infer required status from whether its failure would affect qualified:
                // if the report is unqualified AND this is a fail, it may be required.
                // Since EvalReport does not re-expose the required flag per result,
                // we use a conservative heuristic: any fail = "warn" unless the report
                // is unqualified (then fails that contributed to disqualification = "critical").
                // We mark all fails as "critical" when the report is unqualified — this is
                // the correct fail-closed posture: when in doubt, surface at critical severity.
                let level = report.qualified ? "warn" : "critical"
                return RiskItem(
                    level:     level,
                    text:      "[\(result.kind.rawValue)] \(result.specId): \(result.evidence)",
                    riskClass: "eval_failure"
                )
            }
            blocks.append(.riskList(RiskListPayload(items: riskItems)))
        }

        // --- summary_card: qualified verdict ---
        let verdictLabel = report.qualified ? "QUALIFIED" : "NOT QUALIFIED"
        let passCount    = report.results.filter { $0.verdict == .pass }.count
        let failCount    = failedResults.count
        let total        = report.results.count

        let body = """
        Verdict: \(verdictLabel)
        Evals: \(passCount) pass / \(failCount) fail / \(total) total
        Manifest: \(manifestId)
        Harness: eval_harness:v1
        """

        blocks.append(.summaryCard(SummaryCardPayload(
            title: "Capability Eval Report — \(verdictLabel)",
            body:  body
        )))

        // derive_source: cites manifest id + eval_harness version — always non-empty.
        let deriveSource = ["manifest:\(manifestId)", "eval_harness:v1"]

        return ViewIRDocument(
            schemaVersion: viewIRSchemaVersion,
            kind:          "eval_report",
            deriveSource:  deriveSource,
            blocks:        blocks
        )
    }
}
