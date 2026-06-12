// TemplateProjections.swift — deterministic factory producing ViewIRDocument
// WITHOUT any model invocation (docs/02 §5 降级模式 / §5.2 确定性模板).
//
// Contract:
//   • Pure functions — same input always produces byte-identical output.
//   • No AI, no model calls, no network I/O.
//   • All documents carry non-empty derive_source (P1 predicate).
//   • Used for: L1-L3 降级, unit tests, boot-path scaffolding.
//
// Three required factories (minimum per spec):
//   • morningRitual(from:)         — structured counts → morning_ritual doc
//   • projectPicker(from:)         — [name/path] → project_picker doc
//   • degradedNotice(reason:)      — error string → summary_card degraded doc

import Foundation

public enum TemplateProjections {

    // MARK: - Morning ritual

    /// Builds a morning_ritual ViewIRDocument from structured tape counts.
    /// derive_source always points to the tape range (not a model session).
    public static func morningRitual(
        date: String,
        tapeRange: String,
        done: Int, staged: Int, needsApproval: Int, blocked: Int, failed: Int,
        doneRefs: [String] = [],
        stagedRefs: [String] = [],
        needsApprovalRefs: [String] = [],
        blockedRefs: [String] = [],
        failedRefs: [String] = []
    ) -> ViewIRDocument {
        let buckets: [MorningBucket] = [
            MorningBucket(label: "done",           count: done,          refs: doneRefs),
            MorningBucket(label: "staged",         count: staged,        refs: stagedRefs),
            MorningBucket(label: "needs_approval", count: needsApproval, refs: needsApprovalRefs),
            MorningBucket(label: "blocked",        count: blocked,       refs: blockedRefs),
            MorningBucket(label: "failed",         count: failed,        refs: failedRefs),
        ]
        let ritual = MorningRitualPayload(date: date, tapeRange: tapeRange, buckets: buckets)
        let total = done + staged + needsApproval + blocked + failed
        let summary = SummaryCardPayload(
            title: "今日摘要",
            body: "\(total) 项工作已归并：完成 \(done)，暂存 \(staged)，待审批 \(needsApproval)，阻塞 \(blocked)，失败 \(failed)。",
            tapeRef: tapeRange
        )
        return ViewIRDocument(
            kind: "morning_ritual",
            deriveSource: ["tape:\(tapeRange)"],
            blocks: [.morningRitual(ritual), .summaryCard(summary)]
        )
    }

    // MARK: - Project picker

    /// Builds a project_picker ViewIRDocument from an array of (name, path) pairs.
    /// derive_source points to fixture_event_stream (boot-path scaffold).
    public static func projectPicker(
        from projects: [(name: String, path: String)],
        deriveSource: [String] = ["fixture_event_stream:boot"]
    ) -> ViewIRDocument {
        let entries = projects.map { proj in
            // Stable project_id: "proj_" + last path component, lowercase, sanitised.
            let rawId = URL(fileURLWithPath: proj.path).lastPathComponent
            let safeId = rawId
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9_]", with: "_", options: .regularExpression)
            return ProjectEntry(
                projectId: "proj_\(safeId)",
                name: proj.name,
                readiness: "ready",
                trustState: "observed_unsigned"
            )
        }
        return ViewIRDocument(
            kind: "project_init",
            deriveSource: deriveSource.isEmpty ? ["fixture_event_stream:boot"] : deriveSource,
            blocks: [.projectPicker(ProjectPickerPayload(projects: entries))]
        )
    }

    // MARK: - Degraded notice

    /// Builds a degraded-state ViewIRDocument from a deterministic reason string.
    /// No AI content. Orb enters `degraded` state when this is rendered (§5.2).
    public static func degradedNotice(reason: String) -> ViewIRDocument {
        let card = SummaryCardPayload(
            title: "系统降级",
            body: "TuringOS 当前处于降级模式。原因：\(reason)\n\n投影层已降级为确定性模板；事实不丢失。"
        )
        return ViewIRDocument(
            kind: "general",
            deriveSource: ["fixture_event_stream:degraded"],
            blocks: [.summaryCard(card)]
        )
    }
}
