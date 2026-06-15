// A1_08: the Software 3.0 home's data spine (五次裁决三定律落地).
//
// WorktreeLedger folds the event stream into "latest visible state per
// worktree + per project"; AttentionTriage derives from it the ONLY thing
// the home screen says: a severity-ordered stack of SENTENCES, each
// drillable to its evidence payload. Sentences are deterministic template
// projections (same ledger ⇒ same bytes - pinned by golden tests); they
// are NOT generated text, so no R3 badge applies until P6 wires R_GENUI.

import Foundation

// MARK: - Ledger (fold of the stream's latest visible facts)

public struct WorktreeFact: Equatable, Sendable {
    public let projectId: String
    public let worktreeId: String
    public let branch: String?
    public let dirty: Bool
    public let prunable: Bool
    public let sameBranchConflict: Bool
    public let fingerprintError: String?
    public let path: String?
    public let head: String?
    public let locked: Bool
    public let detached: Bool
    /// The raw payload - the evidence the sentence drills down to.
    public let evidence: JSONValue

    public init(
        projectId: String, worktreeId: String, branch: String? = nil,
        dirty: Bool = false, prunable: Bool = false,
        sameBranchConflict: Bool = false, fingerprintError: String? = nil,
        path: String? = nil, head: String? = nil,
        locked: Bool = false, detached: Bool = false,
        evidence: JSONValue
    ) {
        self.projectId = projectId
        self.worktreeId = worktreeId
        self.branch = branch
        self.dirty = dirty
        self.prunable = prunable
        self.sameBranchConflict = sameBranchConflict
        self.fingerprintError = fingerprintError
        self.path = path
        self.head = head
        self.locked = locked
        self.detached = detached
        self.evidence = evidence
    }
}

public struct ProjectFact: Equatable, Sendable {
    public let projectId: String
    public let local: Bool
    /// Registered checkout path - the radar's anchor witness: the worktree
    /// whose own path equals it IS the primary checkout (fact-coupling,
    /// never a branch-name heuristic).
    public let path: String?
}

/// A1_49/A1_51b: one observed branch (local git or GitHub, per provenance).
/// A1_51b adds ahead/behind/mergeStatus/mergeBase/containedInDefault from the
/// A1_50 BranchObserved wire fields; safe defaults keep old fold sites intact.
public struct BranchFact: Equatable, Sendable {
    public let projectId: String
    public let branchRef: String
    public let headSha: String?
    public let isDefault: Bool
    public let mergedIntoDefault: Bool
    /// "local_git" | "github_api" | "both" - the honesty field (network-attested
    /// facts are labelled, never silently equated with locally-verified ones).
    public let provenance: String
    // A1_51b fields (A1_50 wire payload; 0/"unknown"/nil/false when absent):
    public let ahead: Int
    public let behind: Int
    /// "identical" | "ahead" | "behind" | "diverged" | "unknown"
    public let mergeStatus: String
    /// SHA of the common merge-base with the default branch; nil when unknown.
    public let mergeBase: String?
    /// True when the branch head is reachable from the default branch HEAD.
    public let containedInDefault: Bool

    public init(
        projectId: String, branchRef: String, headSha: String? = nil,
        isDefault: Bool = false, mergedIntoDefault: Bool = false,
        provenance: String = "unknown",
        ahead: Int = 0, behind: Int = 0,
        mergeStatus: String = "unknown", mergeBase: String? = nil,
        containedInDefault: Bool = false
    ) {
        self.projectId = projectId
        self.branchRef = branchRef
        self.headSha = headSha
        self.isDefault = isDefault
        self.mergedIntoDefault = mergedIntoDefault
        self.provenance = provenance
        self.ahead = ahead
        self.behind = behind
        self.mergeStatus = mergeStatus
        self.mergeBase = mergeBase
        self.containedInDefault = containedInDefault
    }
}

/// A1_51b: one observed commit (from CommitObserved, supplied by A1_52).
/// Append-only: no CommitRemoved event exists; lifecycle is branch-scoped
/// (branchRemoved cascades a cleanup of that branch_ref's commits).
public struct CommitFact: Equatable, Sendable {
    public let projectId: String
    public let commitSha: String
    public let parentShas: [String]
    public let branchRef: String
    public let author: String
    public let ts: String
    public let summary: String

    public init(
        projectId: String, commitSha: String, parentShas: [String],
        branchRef: String, author: String, ts: String, summary: String
    ) {
        self.projectId = projectId
        self.commitSha = commitSha
        self.parentShas = parentShas
        self.branchRef = branchRef
        self.author = author
        self.ts = ts
        self.summary = summary
    }
}

public struct WorktreeLedger: Equatable, Sendable {
    public private(set) var worktrees: [String: WorktreeFact] = [:] // worktree_id -> latest
    public private(set) var projects: [String: ProjectFact] = [:] // project_id -> latest
    /// A1_49: branch facts keyed "project_id\0branch_ref" (NUL: git forbids it
    /// in refs, so the key can never collide).
    public private(set) var branches: [String: BranchFact] = [:]
    /// A1_51b: commit facts keyed "project_id\0commit_sha". Append-only in the
    /// stream; branchRemoved cascades a cleanup (commit lifecycle = branch-scoped).
    public private(set) var commits: [String: CommitFact] = [:]

    public init() {}

    private static func branchKey(_ projectId: String, _ branchRef: String) -> String {
        "\(projectId)\u{0}\(branchRef)"
    }

    private static func commitKey(_ projectId: String, _ commitSha: String) -> String {
        "\(projectId)\u{0}\(commitSha)"
    }

    public mutating func apply(_ event: EventEnvelope) {
        switch event.kind {
        case .projectRegistered:
            if let id = event.payload["project_id"]?.stringValue {
                projects[id] = ProjectFact(
                    projectId: id,
                    local: event.payload["local"]?.boolValue ?? false,
                    // Registry daemon emits "path"; the committed fixture
                    // era used canonical_path/root_path - accept all three.
                    path: event.payload["path"]?.stringValue
                        ?? event.payload["canonical_path"]?.stringValue
                        ?? event.payload["root_path"]?.stringValue
                )
            }
        case .worktreeDiscovered:
            // Contract-violating events (missing ids) are DROPPED, never
            // materialized - a phantom "?" project would be fake activity
            // (S-stage blocker; the card promises no fake live numbers).
            guard let id = event.payload["worktree_id"]?.stringValue,
                  let projectId = event.payload["project_id"]?.stringValue else { return }
            worktrees[id] = WorktreeFact(
                projectId: projectId,
                worktreeId: id,
                branch: event.payload["branch"]?.stringValue,
                dirty: event.payload["dirty"]?.boolValue ?? false,
                prunable: event.payload["prunable"]?.boolValue ?? false,
                sameBranchConflict: event.payload["same_branch_conflict"]?.boolValue ?? false,
                fingerprintError: event.payload["fingerprint_error"]?.stringValue,
                path: event.payload["path"]?.stringValue,
                head: event.payload["head"]?.stringValue,
                locked: event.payload["locked"]?.boolValue ?? false,
                detached: event.payload["detached"]?.boolValue ?? false,
                evidence: event.payload
            )
        case .worktreeRemoved:
            if let id = event.payload["worktree_id"]?.stringValue {
                worktrees.removeValue(forKey: id)
            }
        case .branchObserved:
            guard let pid = event.payload["project_id"]?.stringValue,
                  let ref = event.payload["branch_ref"]?.stringValue else { return }
            // A1_51b: extract new wire fields with safe defaults so older
            // fixtures (without ahead/behind/etc.) keep folding correctly.
            let mergeBaseRaw = event.payload["merge_base"]?.stringValue ?? ""
            branches[Self.branchKey(pid, ref)] = BranchFact(
                projectId: pid,
                branchRef: ref,
                headSha: event.payload["head_sha"]?.stringValue,
                isDefault: event.payload["is_default"]?.boolValue ?? false,
                mergedIntoDefault: event.payload["merged_into_default"]?.boolValue ?? false,
                provenance: event.payload["provenance"]?.stringValue ?? "unknown",
                ahead: event.payload["ahead"]?.numberValue.map(Int.init) ?? 0,
                behind: event.payload["behind"]?.numberValue.map(Int.init) ?? 0,
                mergeStatus: event.payload["merge_status"]?.stringValue ?? "unknown",
                mergeBase: mergeBaseRaw.isEmpty ? nil : mergeBaseRaw,
                containedInDefault: event.payload["contained_in_default"]?.boolValue ?? false
            )
        case .branchRemoved:
            guard let pid = event.payload["project_id"]?.stringValue,
                  let ref = event.payload["branch_ref"]?.stringValue else { return }
            branches.removeValue(forKey: Self.branchKey(pid, ref))
            // A1_51b: cascade - prune commits whose branch_ref matches this
            // removed branch (commit lifecycle is branch-scoped; no CommitRemoved event).
            commits = commits.filter { _, fact in
                !(fact.projectId == pid && fact.branchRef == ref)
            }
        case .commitObserved:
            // A1_51b: fold CommitObserved (supplied by A1_52). Missing
            // required fields are DROPPED - no phantom commits.
            guard let pid = event.payload["project_id"]?.stringValue,
                  let sha = event.payload["commit_sha"]?.stringValue,
                  let ref = event.payload["branch_ref"]?.stringValue else { return }
            let parentShas: [String]
            if case .array(let arr) = event.payload["parent_shas"] {
                parentShas = arr.compactMap { $0.stringValue }
            } else {
                parentShas = []
            }
            commits[Self.commitKey(pid, sha)] = CommitFact(
                projectId: pid,
                commitSha: sha,
                parentShas: parentShas,
                branchRef: ref,
                author: event.payload["author"]?.stringValue ?? "",
                ts: event.payload["ts"]?.stringValue ?? "",
                summary: event.payload["summary"]?.stringValue ?? ""
            )
        default:
            break
        }
    }

    public static func fold(_ events: some Sequence<EventEnvelope>) -> WorktreeLedger {
        var ledger = WorktreeLedger()
        for event in events { ledger.apply(event) }
        return ledger
    }
}

// MARK: - Triage (law 1: the screen answers ONE question)

public enum AttentionSeverity: Int, Comparable, Sendable {
    case failure = 0 // 有失败证据 (red)
    case decision = 1 // 等你裁决 (yellow)
    case disconnect = 2 // 未对账 (gray)

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var semantic: Tokens.Semantic {
        switch self {
        case .failure: .red
        case .decision: .yellow
        case .disconnect: .gray
        }
    }

    /// Icon leg of the dual-channel badge (VISUAL_SEMANTICS rule 3).
    public var iconName: String {
        switch self {
        case .failure: "xmark.octagon.fill"
        case .decision: "exclamationmark.triangle.fill"
        case .disconnect: "bolt.horizontal.circle"
        }
    }
}

/// Structured attribution for an attention item - the radar fly-to reads
/// THIS, never parses item ids back apart (the A1_08 S-stage lesson).
public struct AttentionTarget: Equatable, Sendable {
    public let projectId: String
    public let worktreeIds: [String]
}

/// One "needs you" item: a sentence + its evidence (law 2).
public struct AttentionItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let severity: AttentionSeverity
    public let sentence: String
    public let evidence: JSONValue?
    /// nil when the item has no spatial home (e.g. the disconnect notice).
    public let target: AttentionTarget?
}

/// One ambient "working" row: a project with uncommitted motion.
public struct WorkingRow: Identifiable, Equatable, Sendable {
    public var id: String { projectId }
    public let projectId: String
    public let sentence: String
}

/// The whole home, derived: three sections + the one glance sentence.
public struct AttentionTriage: Equatable, Sendable {
    public let needsYou: [AttentionItem]
    public let working: [WorkingRow]
    public let quietSentence: String? // nil when the quiet section is empty
    public let glanceSentence: String
    public let glanceSemantic: Tokens.Semantic

    public static func derive(
        ledger: WorktreeLedger,
        connection: ConnectionState
    ) -> AttentionTriage {
        var items: [AttentionItem] = []

        if case .disconnected(let reason) = connection {
            items.append(AttentionItem(
                id: "disconnect",
                severity: .disconnect,
                sentence: Sentences.disconnected(reason: reason),
                evidence: nil,
                target: nil
            ))
        }

        // One same-branch conflict == ONE decision (S-stage risk: N
        // byte-identical rows for one conflict is counting, not triage).
        var conflictGroups: [String: [WorktreeFact]] = [:]
        for fact in ledger.worktrees.values.sorted(by: { $0.worktreeId < $1.worktreeId }) {
            if let error = fact.fingerprintError {
                items.append(AttentionItem(
                    id: "fp:\(fact.worktreeId)",
                    severity: .failure,
                    sentence: Sentences.fingerprintFailure(fact: fact, error: error),
                    evidence: fact.evidence,
                    target: AttentionTarget(
                        projectId: fact.projectId, worktreeIds: [fact.worktreeId])
                ))
            }
            if fact.sameBranchConflict {
                // NUL separator: git forbids NUL and empty ref names, so
                // this key can never collide with a real project/branch
                // pair (a nil branch must not merge with one named "?").
                let key = "\(fact.projectId)\u{0}\(fact.branch ?? "")"
                conflictGroups[key, default: []].append(fact)
            }
            if fact.prunable {
                items.append(AttentionItem(
                    id: "orphan:\(fact.worktreeId)",
                    severity: .decision,
                    sentence: Sentences.orphan(fact: fact),
                    evidence: fact.evidence,
                    target: AttentionTarget(
                        projectId: fact.projectId, worktreeIds: [fact.worktreeId])
                ))
            }
        }
        for (key, group) in conflictGroups.sorted(by: { $0.key < $1.key }) {
            items.append(AttentionItem(
                id: "conflict:\(key)",
                severity: .decision,
                sentence: Sentences.sameBranchConflict(group: group),
                evidence: .array(group.map(\.evidence)),
                target: AttentionTarget(
                    projectId: group[0].projectId,
                    worktreeIds: group.map(\.worktreeId))
            ))
        }
        items.sort { ($0.severity, $0.id) < ($1.severity, $1.id) }

        // Attribution sets built from FACTS, not parsed back out of item
        // ids (S-stage risk: id-string archaeology broke the moment ids
        // changed shape).
        var attentionWorktrees = Set<String>()
        var attentionProjects = Set<String>()
        for fact in ledger.worktrees.values
        where fact.fingerprintError != nil || fact.sameBranchConflict || fact.prunable {
            attentionWorktrees.insert(fact.worktreeId)
            attentionProjects.insert(fact.projectId)
        }

        // Working: projects with dirty worktrees that need NO decision.
        var dirtyByProject: [String: Int] = [:]
        for fact in ledger.worktrees.values
        where fact.dirty && !attentionWorktrees.contains(fact.worktreeId) {
            dirtyByProject[fact.projectId, default: 0] += 1
        }
        let working = dirtyByProject.sorted { $0.key < $1.key }.map { project, count in
            WorkingRow(projectId: project, sentence: Sentences.working(dirtyCount: count))
        }

        // Quiet: registered projects with nothing above.
        let busy = attentionProjects.union(working.map(\.projectId))
        let quietCount = ledger.projects.keys.filter { !busy.contains($0) }.count
        let quietSentence = quietCount > 0 ? Sentences.quiet(count: quietCount) : nil

        // Glance: one sentence + one level (laws 1+3). Connection state
        // OVERRIDES the dot: anything but .connected means the ledger is
        // not live - gray 未对账, never a confident red/yellow/blue over
        // stale data (S-stage regression fix; the stale items stay listed
        // in the stack under the disconnect notice).
        let glance: (String, Tokens.Semantic)
        switch connection {
        case .connecting:
            glance = (Sentences.reconciling(), .gray)
        case .disconnected(let reason):
            glance = (Sentences.disconnected(reason: reason), .gray)
        case .connected:
            if let worst = items.first {
                glance = (Sentences.glanceNeedsYou(count: items.count), worst.severity.semantic)
            } else if !working.isEmpty {
                glance = (Sentences.glanceWorking(projects: working.count), .blue)
            } else {
                glance = (Sentences.allQuiet(projects: ledger.projects.count), .blue)
            }
        }

        return AttentionTriage(
            needsYou: items,
            working: working,
            quietSentence: quietSentence,
            glanceSentence: glance.0,
            glanceSemantic: glance.1
        )
    }
}

// MARK: - Sentences (law 2: deterministic template projections)

public enum Sentences {
    static func project(_ fact: WorktreeFact) -> String { fact.projectId }

    static func shortName(_ fact: WorktreeFact) -> String {
        // wt_<name>_<digest8> -> name; the digest is plumbing, not
        // language. Only strip the tail when it really is an 8-hex digest
        // (legacy/test ids without one keep their full name).
        let parts = fact.worktreeId.split(separator: "_")
        guard parts.count >= 3, parts.first == "wt",
              let last = parts.last, last.count == 8,
              last.allSatisfy(\.isHexDigit)
        else {
            return fact.worktreeId.hasPrefix("wt_")
                ? String(fact.worktreeId.dropFirst(3))
                : fact.worktreeId
        }
        return parts.dropFirst().dropLast().joined(separator: "_")
    }

    public static func fingerprintFailure(fact: WorktreeFact, error: String) -> String {
        "「\(project(fact))」的 \(shortName(fact)) 读不出状态：\(error)"
    }

    public static func sameBranchConflict(group: [WorktreeFact]) -> String {
        let first = group[0]
        let branch = first.branch ?? "同一分支"
        let names = group.map(shortName).joined(separator: "、")
        return "「\(project(first))」的 \(branch) 被 \(group.count) 个 worktree（\(names)）同时检出，等你裁决"
    }

    public static func orphan(fact: WorktreeFact) -> String {
        "「\(project(fact))」有一个孤儿 worktree（\(shortName(fact))），可以清理"
    }

    public static func disconnected(reason: String) -> String {
        "daemon 断连——\(reason)"
    }

    public static func reconciling() -> String {
        "正在对账…"
    }

    public static func popoverOverflow(hidden: Int) -> String {
        "还有 \(hidden) 件，去主窗看全部"
    }

    /// The sentence grammar whitelist (mechanical anti-pattern guard): a
    /// user-facing surface string MUST match one of these templates. A
    /// "活跃: 3"-style metric label matches none of them and turns the
    /// guard red - far stronger than the prose heuristic it replaces.
    public static let templates: [String] = [
        #"^「.+」的 .+ 读不出状态：.+$"#,
        #"^「.+」的 .+ 被 \d+ 个 worktree（.+）同时检出，等你裁决$"#,
        #"^「.+」有一个孤儿 worktree（.+），可以清理$"#,
        #"^daemon 断连——.+$"#,
        #"^正在对账…$"#,
        #"^\d+ 个 worktree 有未提交改动$"#,
        #"^其余 \d+ 个项目一切安静$"#,
        #"^一切安静，\d+ 个项目在看管中$"#,
        #"^还没有看管任何项目$"#,
        #"^\d+ 件事等你$"#,
        #"^\d+ 个项目有动静，无需介入$"#,
        #"^还有 \d+ 件，去主窗看全部$"#,
    ]

    public static func matchesTemplate(_ sentence: String) -> Bool {
        templates.contains { sentence.range(of: $0, options: .regularExpression) != nil }
    }

    public static func working(dirtyCount: Int) -> String {
        "\(dirtyCount) 个 worktree 有未提交改动"
    }

    public static func quiet(count: Int) -> String {
        "其余 \(count) 个项目一切安静"
    }

    public static func allQuiet(projects: Int) -> String {
        projects > 0 ? "一切安静，\(projects) 个项目在看管中" : "还没有看管任何项目"
    }

    public static func glanceNeedsYou(count: Int) -> String {
        "\(count) 件事等你"
    }

    public static func glanceWorking(projects: Int) -> String {
        "\(projects) 个项目有动静，无需介入"
    }
}
