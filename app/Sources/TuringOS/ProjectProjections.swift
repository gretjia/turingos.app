// ProjectProjections.swift — A1_17: project discovery + read-only git state projection.
//
// Design contract:
//   • Pure functions — same input always produces byte-identical output.
//   • No git invocations, no FileManager writes, no model calls, no network.
//   • All documents carry non-empty derive_source (P1 predicate).
//   • CatalogSource protocol: testable injection point for RepoCatalog access
//     (mirrors the FacilitatorRuntimeProbe injection pattern from A1_16).
//   • projectState is STRICTLY read-only: accepts value-type snapshots only.

import Foundation

// MARK: - CatalogSource protocol

/// Injectable access to the project catalog (real or mock).
/// Conformers: SystemCatalogSource (real) and MockCatalogSource (tests).
public protocol CatalogSource: Sendable {
    /// Return the current list of catalog items (snapshot; may be empty).
    func items() -> [CatalogItem]
    /// Derive-source identifier for this source (e.g. "catalog:local_scan").
    var deriveSourceTag: String { get }
}

// MARK: - System catalog source

/// Real catalog source: discovers local clones + merges with an optional
/// GitHub listing held by the caller (token lives in Keychain; source is
/// injected as already-fetched repos so this layer stays sync + read-only).
public struct SystemCatalogSource: CatalogSource, Sendable {
    private let githubRepos: [GitHubRepo]

    public init(githubRepos: [GitHubRepo] = []) {
        self.githubRepos = githubRepos
    }

    public func items() -> [CatalogItem] {
        let local = RepoCatalog.discoverLocal()
        return RepoCatalog.merge(gitHub: githubRepos, local: local)
    }

    public var deriveSourceTag: String { "catalog:local_scan" }
}

// MARK: - Mock catalog source (tests)

/// Deterministic source for unit tests — no disk access.
public struct MockCatalogSource: CatalogSource, Sendable {
    private let fixedItems: [CatalogItem]
    public let deriveSourceTag: String

    public init(items: [CatalogItem], tag: String = "catalog:mock") {
        self.fixedItems = items
        self.deriveSourceTag = tag
    }

    public func items() -> [CatalogItem] { fixedItems }
}

// MARK: - ProjectProjections (pure factory namespace)

public enum ProjectProjections {

    // MARK: - projectPicker

    /// Deterministic factory: catalog entries → project_picker ViewIRDocument.
    /// Empty catalog → guidance summary_card (no picker block — avoid an
    /// empty list that implies "zero projects exist" rather than "not set up yet").
    public static func projectPicker(
        from source: any CatalogSource
    ) -> ViewIRDocument {
        let entries = source.items()
        let tag = source.deriveSourceTag
        if entries.isEmpty {
            return emptyPickerGuidance(deriveSource: tag)
        }
        return pickerDocument(entries: entries, deriveSource: tag)
    }

    /// Overload accepting a pre-fetched [CatalogItem] list directly (lets
    /// callers who already hold the items skip the protocol indirection).
    public static func projectPicker(
        entries: [CatalogItem],
        deriveSource: String
    ) -> ViewIRDocument {
        if entries.isEmpty {
            return emptyPickerGuidance(deriveSource: deriveSource)
        }
        return pickerDocument(entries: entries, deriveSource: deriveSource)
    }

    private static func pickerDocument(
        entries: [CatalogItem],
        deriveSource: String
    ) -> ViewIRDocument {
        let projects = entries.map { item in
            ProjectEntry(
                projectId: item.id,
                name: item.displayName,
                readiness: item.localPath != nil ? "ready" : "not_init",
                trustState: "observed_unsigned"
            )
        }
        return ViewIRDocument(
            kind: "project_init",
            deriveSource: [deriveSource],
            blocks: [.projectPicker(ProjectPickerPayload(projects: projects))]
        )
    }

    private static func emptyPickerGuidance(deriveSource: String) -> ViewIRDocument {
        let card = SummaryCardPayload(
            title: "尚无项目",
            body: "尚无项目——说「连接项目」开始"
        )
        return ViewIRDocument(
            kind: "project_init",
            deriveSource: [deriveSource],
            blocks: [.summaryCard(card)]
        )
    }

    // MARK: - projectState

    /// Deterministic read-only projection of one project's git state.
    ///
    /// Inputs are value-type snapshots (WorktreeLedger + RadarScene) — no
    /// mutable references, no writes, no side effects.
    ///
    /// Produces:
    ///   • summary_card  — project name, branch summary, counts
    ///   • worktree_map  — one WorktreeEntry per worktree in the project
    ///   • evidence_list — only when attention items (failed/conflict/orphan) exist
    public static func projectState(
        projectId: String,
        displayName: String,
        ledger: WorktreeLedger,
        radarScene: RadarScene,
        deriveSource: String
    ) -> ViewIRDocument {
        // Collect all worktrees for this project from the ledger (value type).
        let worktreeFacts = ledger.worktrees.values
            .filter { $0.projectId == projectId }
            .sorted { $0.worktreeId < $1.worktreeId }

        // Counts.
        let worktreeCount = worktreeFacts.count
        let attentionFacts = worktreeFacts.filter {
            $0.fingerprintError != nil || $0.sameBranchConflict || $0.prunable
        }
        let needsAttentionCount = attentionFacts.count

        // Branch summary: collect distinct non-nil branch names.
        let branches = worktreeFacts.compactMap(\.branch).removingDuplicates()
        let branchSummary: String
        switch branches.count {
        case 0:  branchSummary = "（无分支信息）"
        case 1:  branchSummary = branches[0]
        default: branchSummary = "\(branches[0]) 等 \(branches.count) 个分支"
        }

        // Summary card body.
        let attentionNote = needsAttentionCount > 0
            ? "，其中 \(needsAttentionCount) 个需要关注"
            : ""
        let body = """
        分支：\(branchSummary)
        Worktree：\(worktreeCount) 个\(attentionNote)
        """

        let summaryCard = SummaryCardPayload(title: displayName, body: body)

        // Worktree map: one entry per worktree, status derived from fact form.
        let worktreeEntries = worktreeFacts.map { fact -> WorktreeEntry in
            let form = RadarNode.Form.classify(fact)
            let status: String
            switch form {
            case .failed:   status = "halted"
            case .conflict: status = "pending_approval"
            case .orphan:   status = "halted"
            case .active:   status = "running"
            case .quiet:    status = "done"
            }
            return WorktreeEntry(
                worktreeId: fact.worktreeId,
                headSha: fact.head,
                status: status,
                trustState: "observed_unsigned",
                provenance: "REPO_LEVEL"
            )
        }

        let worktreeMapBlock = WorktreeMapPayload(worktrees: worktreeEntries)

        // Evidence list: only when there are attention items (laws 2+3 —
        // showing an evidence block for a clean project is noise).
        var blocks: [ViewIRBlock] = [
            .summaryCard(summaryCard),
            .worktreeMap(worktreeMapBlock),
        ]

        if !attentionFacts.isEmpty {
            let evidenceItems = attentionFacts.map { fact -> EvidenceItem in
                let form = RadarNode.Form.classify(fact)
                let label: String
                switch form {
                case .failed:
                    label = "\(fact.worktreeId)：\(fact.fingerprintError ?? "读不出状态")"
                case .conflict:
                    label = "\(fact.worktreeId)：同分支冲突（\(fact.branch ?? "未知分支")）"
                case .orphan:
                    label = "\(fact.worktreeId)：孤儿 worktree，可清理"
                default:
                    label = fact.worktreeId
                }
                return EvidenceItem(
                    kind: "worktree_state",
                    label: label,
                    ref: "ledger:worktree:\(fact.worktreeId)"
                )
            }
            blocks.append(.evidenceList(EvidenceListPayload(items: evidenceItems)))
        }

        return ViewIRDocument(
            kind: "project_state",
            deriveSource: [deriveSource],
            blocks: blocks
        )
    }
}

// MARK: - Array dedup helper (local; mirrors OrbState's private extension)

private extension Array where Element: Equatable {
    func removingDuplicates() -> [Element] {
        var seen = [Element]()
        for e in self where !seen.contains(e) { seen.append(e) }
        return seen
    }
}
