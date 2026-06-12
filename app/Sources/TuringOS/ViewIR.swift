// ViewIR.swift — Swift mirror of contracts/view_ir.schema.json (tos.app.view_ir.v0).
//
// Model-facing output contract: models produce View IR ONLY, never executable
// HTML/JS (execution ruling red line 1; docs/02_SOFTWARE_3_UI_PRD.md §3.1).
// Unknown block types decode to `.unknown` — forward-compat: decoding MUST
// NEVER throw on an unrecognised type and MUST NEVER interpret any payload
// as markup or script.
//
// The Swift decoder is the strict layer; the schema is the contract surface.

import Foundation

// MARK: - View IR document

/// Top-level View IR document produced by Facilitator AI or Meta AI.
/// `derive_source` is mandatory: every displayed projection must be traceable
/// (tape discipline — docs/02 §1.3 / §8 predicate P1).
public struct ViewIRDocument: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let kind: String
    public let deriveSource: [String]
    public let blocks: [ViewIRBlock]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case kind
        case deriveSource = "derive_source"
        case blocks
    }

    public init(
        schemaVersion: String = viewIRSchemaVersion,
        kind: String,
        deriveSource: [String],
        blocks: [ViewIRBlock]
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.deriveSource = deriveSource
        self.blocks = blocks
    }
}

/// Canonical schema version constant for View IR v0.
public let viewIRSchemaVersion = "tos.app.view_ir.v0"

// MARK: - Block enum

/// One block inside a ViewIRDocument.
/// Decoding: unknown `type` values decode to `.unknown(rawType:)` — NEVER throw.
/// Payload in `.unknown` MUST NOT be interpreted as markup or script by any renderer.
public enum ViewIRBlock: Sendable, Equatable {
    case summaryCard(SummaryCardPayload)
    case riskList(RiskListPayload)
    /// approval_request: the ONLY rendering path is ApprovalCard (§3.3 渲染铁律).
    case approvalRequest(ApprovalRequestPayload)
    case diffView(DiffViewPayload)
    case evidenceList(EvidenceListPayload)
    case projectPicker(ProjectPickerPayload)
    case specDraft(SpecDraftPayload)
    case budgetCard(BudgetCardPayload)
    case worktreeMap(WorktreeMapPayload)
    case repairPrompt(RepairPromptPayload)
    case dossierView(DossierViewPayload)
    case morningRitual(MorningRitualPayload)
    case intentSuggestions(IntentSuggestionsPayload)
    /// credential_field: MUST render via macOS SecureField only (§7.1 / §3.3 渲染铁律).
    case credentialField(CredentialFieldPayload)
    /// Forward-compatibility sentinel: unrecognised type — render as inert notice,
    /// never interpret rawType or the raw JSON as executable content.
    case unknown(rawType: String)
}

// MARK: - Codable for ViewIRBlock

extension ViewIRBlock: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type_ = try container.decode(String.self, forKey: .type)
        // Re-open a full keyed container for payload fields.
        let payload = try decoder.container(keyedBy: BlockPayloadKey.self)
        switch type_ {
        case "summary_card":
            self = .summaryCard(try SummaryCardPayload(from: decoder))
        case "risk_list":
            self = .riskList(try RiskListPayload(from: decoder))
        case "approval_request":
            self = .approvalRequest(try ApprovalRequestPayload(from: decoder))
        case "diff_view":
            self = .diffView(try DiffViewPayload(from: decoder))
        case "evidence_list":
            self = .evidenceList(try EvidenceListPayload(from: decoder))
        case "project_picker":
            self = .projectPicker(try ProjectPickerPayload(from: decoder))
        case "spec_draft":
            self = .specDraft(try SpecDraftPayload(from: decoder))
        case "budget_card":
            self = .budgetCard(try BudgetCardPayload(from: decoder))
        case "worktree_map":
            self = .worktreeMap(try WorktreeMapPayload(from: decoder))
        case "repair_prompt":
            self = .repairPrompt(try RepairPromptPayload(from: decoder))
        case "dossier_view":
            self = .dossierView(try DossierViewPayload(from: decoder))
        case "morning_ritual":
            self = .morningRitual(try MorningRitualPayload(from: decoder))
        case "intent_suggestions":
            self = .intentSuggestions(try IntentSuggestionsPayload(from: decoder))
        case "credential_field":
            self = .credentialField(try CredentialFieldPayload(from: decoder))
        default:
            // Forward-compat: unknown type decodes to inert sentinel.
            // rawType is stored for the renderer to display a notice;
            // it is NEVER interpreted as markup or script.
            _ = payload
            self = .unknown(rawType: type_)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .summaryCard(let p):        try p.encode(to: encoder)
        case .riskList(let p):           try p.encode(to: encoder)
        case .approvalRequest(let p):    try p.encode(to: encoder)
        case .diffView(let p):           try p.encode(to: encoder)
        case .evidenceList(let p):       try p.encode(to: encoder)
        case .projectPicker(let p):      try p.encode(to: encoder)
        case .specDraft(let p):          try p.encode(to: encoder)
        case .budgetCard(let p):         try p.encode(to: encoder)
        case .worktreeMap(let p):        try p.encode(to: encoder)
        case .repairPrompt(let p):       try p.encode(to: encoder)
        case .dossierView(let p):        try p.encode(to: encoder)
        case .morningRitual(let p):      try p.encode(to: encoder)
        case .intentSuggestions(let p):  try p.encode(to: encoder)
        case .credentialField(let p):    try p.encode(to: encoder)
        case .unknown(let rawType):
            var c = encoder.container(keyedBy: BlockPayloadKey.self)
            try c.encode(rawType, forKey: .type)
        }
    }
}

/// Shared coding key for the `type` discriminator and all payload fields.
enum BlockPayloadKey: String, CodingKey {
    case type
    case title, body, tape_ref
    case items
    case envelope_ref
    case diff_ref, worktree_id, provenance
    case projects
    case spec_ref, sections, signature_node
    case budget_ref, consumed, limit
    case worktrees
    case failure_node_ref, suggested_prompt, target_worktree
    case dossier_ref, risk_findings
    case date, tape_range, buckets
    case suggestions
    case field_id, label, credential_scope
}

// MARK: - Payload structs

/// `summary_card` — title + Markdown body (no embedded HTML).
public struct SummaryCardPayload: Codable, Equatable, Sendable {
    public let type: String
    public let title: String
    public let body: String
    public let tapeRef: String?

    enum CodingKeys: String, CodingKey {
        case type, title, body
        case tapeRef = "tape_ref"
    }

    public init(title: String, body: String, tapeRef: String? = nil) {
        self.type = "summary_card"
        self.title = title
        self.body = body
        self.tapeRef = tapeRef
    }
}

/// One item in a risk_list block.
public struct RiskItem: Codable, Equatable, Sendable {
    /// Severity level: info / warn / critical → maps to blue / yellow / red.
    public let level: String
    public let text: String
    public let riskClass: String?

    enum CodingKeys: String, CodingKey {
        case level, text
        case riskClass = "risk_class"
    }

    public init(level: String, text: String, riskClass: String? = nil) {
        self.level = level
        self.text = text
        self.riskClass = riskClass
    }
}

/// `risk_list` — ordered risk findings with semantic severity.
public struct RiskListPayload: Codable, Equatable, Sendable {
    public let type: String
    public let items: [RiskItem]
    public let tapeRef: String?

    enum CodingKeys: String, CodingKey {
        case type, items
        case tapeRef = "tape_ref"
    }

    public init(items: [RiskItem], tapeRef: String? = nil) {
        self.type = "risk_list"
        self.items = items
        self.tapeRef = tapeRef
    }
}

/// `approval_request` — references an ApprovalEnvelope in the kernel.
/// RENDERING IRON LAW: this block type MUST ONLY be rendered by ApprovalCard.
/// No generic fallback may render it (docs/02 §3.3 渲染铁律 / P4).
public struct ApprovalRequestPayload: Codable, Equatable, Sendable {
    public let type: String
    /// References ApprovalEnvelope.envelope_id; renderer fetches the full
    /// envelope from the kernel and validates visible_card_hash (red line 2).
    public let envelopeRef: String

    enum CodingKeys: String, CodingKey {
        case type
        case envelopeRef = "envelope_ref"
    }

    public init(envelopeRef: String) {
        self.type = "approval_request"
        self.envelopeRef = envelopeRef
    }
}

/// `diff_view` — references a git diff or tape diff hash with provenance level.
public struct DiffViewPayload: Codable, Equatable, Sendable {
    public let type: String
    public let diffRef: String
    public let worktreeId: String
    /// Provenance: FULL / REPO_LEVEL / PARTIAL / OUTSIDE_GOVERNANCE (§7.2).
    public let provenance: String

    enum CodingKeys: String, CodingKey {
        case type
        case diffRef = "diff_ref"
        case worktreeId = "worktree_id"
        case provenance
    }

    public init(diffRef: String, worktreeId: String, provenance: String) {
        self.type = "diff_view"
        self.diffRef = diffRef
        self.worktreeId = worktreeId
        self.provenance = provenance
    }
}

/// One item in an evidence_list block.
public struct EvidenceItem: Codable, Equatable, Sendable {
    /// kind: ci_check / predicate_result / model_call_ref / tape_node_ref
    public let kind: String
    public let label: String
    public let ref: String

    public init(kind: String, label: String, ref: String) {
        self.kind = kind
        self.label = label
        self.ref = ref
    }
}

/// `evidence_list` — verifiable evidence items (docs/02 §3.3).
public struct EvidenceListPayload: Codable, Equatable, Sendable {
    public let type: String
    public let items: [EvidenceItem]

    enum CodingKeys: String, CodingKey { case type, items }

    public init(items: [EvidenceItem]) {
        self.type = "evidence_list"
        self.items = items
    }
}

/// One entry in a project_picker block.
public struct ProjectEntry: Codable, Equatable, Sendable {
    public let projectId: String
    public let name: String
    /// readiness: ready / retro_init_needed / not_init
    public let readiness: String
    /// trust_state from docs/TRUST_STATES.md — renderer maps to TrustState enum.
    public let trustState: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case name, readiness
        case trustState = "trust_state"
    }

    public init(projectId: String, name: String, readiness: String, trustState: String) {
        self.projectId = projectId
        self.name = name
        self.readiness = readiness
        self.trustState = trustState
    }
}

/// `project_picker` — list of projects with readiness and trust state.
public struct ProjectPickerPayload: Codable, Equatable, Sendable {
    public let type: String
    public let projects: [ProjectEntry]

    enum CodingKeys: String, CodingKey { case type, projects }

    public init(projects: [ProjectEntry]) {
        self.type = "project_picker"
        self.projects = projects
    }
}

/// One section ref in a spec_draft block.
public struct SpecSection: Codable, Equatable, Sendable {
    public let ref: String
    public let title: String?

    public init(ref: String, title: String? = nil) {
        self.ref = ref
        self.title = title
    }
}

/// `spec_draft` — Init Spec authoring surface (docs/02 §3.3).
public struct SpecDraftPayload: Codable, Equatable, Sendable {
    public let type: String
    public let specRef: String
    public let sections: [SpecSection]
    /// Signature node (1 = Init Spec).
    public let signatureNode: Int

    enum CodingKeys: String, CodingKey {
        case type
        case specRef = "spec_ref"
        case sections
        case signatureNode = "signature_node"
    }

    public init(specRef: String, sections: [SpecSection], signatureNode: Int) {
        self.type = "spec_draft"
        self.specRef = specRef
        self.sections = sections
        self.signatureNode = signatureNode
    }
}

/// Budget consumption/limit snapshot.
public struct BudgetCounts: Codable, Equatable, Sendable {
    public let tokens: Int?
    public let costUsd: Double?
    public let ciCycles: Int?
    public let wallClockS: Double?

    enum CodingKeys: String, CodingKey {
        case tokens
        case costUsd = "cost_usd"
        case ciCycles = "ci_cycles"
        case wallClockS = "wall_clock_s"
    }

    public init(
        tokens: Int? = nil, costUsd: Double? = nil,
        ciCycles: Int? = nil, wallClockS: Double? = nil
    ) {
        self.tokens = tokens
        self.costUsd = costUsd
        self.ciCycles = ciCycles
        self.wallClockS = wallClockS
    }
}

/// `budget_card` — live budget tracker (signature_node=2).
public struct BudgetCardPayload: Codable, Equatable, Sendable {
    public let type: String
    public let budgetRef: String
    public let consumed: BudgetCounts
    public let limit: BudgetCounts
    /// Signature node 2 (budget approval).
    public let signatureNode: Int

    enum CodingKeys: String, CodingKey {
        case type
        case budgetRef = "budget_ref"
        case consumed, limit
        case signatureNode = "signature_node"
    }

    public init(budgetRef: String, consumed: BudgetCounts, limit: BudgetCounts, signatureNode: Int = 2) {
        self.type = "budget_card"
        self.budgetRef = budgetRef
        self.consumed = consumed
        self.limit = limit
        self.signatureNode = signatureNode
    }
}

/// One worktree entry in a worktree_map block.
public struct WorktreeEntry: Codable, Equatable, Sendable {
    public let worktreeId: String
    public let headSha: String?
    /// status: running / halted / pending_approval / done
    public let status: String
    public let trustState: String
    public let provenance: String?

    enum CodingKeys: String, CodingKey {
        case worktreeId = "worktree_id"
        case headSha = "head_sha"
        case status
        case trustState = "trust_state"
        case provenance
    }

    public init(
        worktreeId: String, headSha: String? = nil,
        status: String, trustState: String, provenance: String? = nil
    ) {
        self.worktreeId = worktreeId
        self.headSha = headSha
        self.status = status
        self.trustState = trustState
        self.provenance = provenance
    }
}

/// `worktree_map` — active worktree topology.
public struct WorktreeMapPayload: Codable, Equatable, Sendable {
    public let type: String
    public let worktrees: [WorktreeEntry]

    enum CodingKeys: String, CodingKey { case type, worktrees }

    public init(worktrees: [WorktreeEntry]) {
        self.type = "worktree_map"
        self.worktrees = worktrees
    }
}

/// `repair_prompt` — CI failure repair suggestion (broadcast-blocked; §3.3).
public struct RepairPromptPayload: Codable, Equatable, Sendable {
    public let type: String
    public let failureNodeRef: String
    /// Plain text — never evaluated as code or markup.
    public let suggestedPrompt: String
    /// Precise injection target worktree (no broadcast; white paper §4.5 II.1).
    public let targetWorktree: String

    enum CodingKeys: String, CodingKey {
        case type
        case failureNodeRef = "failure_node_ref"
        case suggestedPrompt = "suggested_prompt"
        case targetWorktree = "target_worktree"
    }

    public init(failureNodeRef: String, suggestedPrompt: String, targetWorktree: String) {
        self.type = "repair_prompt"
        self.failureNodeRef = failureNodeRef
        self.suggestedPrompt = suggestedPrompt
        self.targetWorktree = targetWorktree
    }
}

/// `dossier_view` — Merge Dossier presentation (signature_node=5).
public struct DossierViewPayload: Codable, Equatable, Sendable {
    public let type: String
    public let dossierRef: String
    /// Subjective risk findings; they do NOT carry a verdict (§3.3 note).
    public let riskFindings: [String]
    /// Provenance: FULL / REPO_LEVEL / PARTIAL / OUTSIDE_GOVERNANCE.
    public let provenance: String
    /// Signature node 5 (approve merge/publish).
    public let signatureNode: Int

    enum CodingKeys: String, CodingKey {
        case type
        case dossierRef = "dossier_ref"
        case riskFindings = "risk_findings"
        case provenance
        case signatureNode = "signature_node"
    }

    public init(
        dossierRef: String, riskFindings: [String],
        provenance: String, signatureNode: Int = 5
    ) {
        self.type = "dossier_view"
        self.dossierRef = dossierRef
        self.riskFindings = riskFindings
        self.provenance = provenance
        self.signatureNode = signatureNode
    }
}

/// One bucket in a morning_ritual block.
public struct MorningBucket: Codable, Equatable, Sendable {
    /// label: done / staged / needs_approval / blocked / failed
    public let label: String
    public let count: Int
    public let refs: [String]

    public init(label: String, count: Int, refs: [String]) {
        self.label = label
        self.count = count
        self.refs = refs
    }
}

/// `morning_ritual` — deterministic tape reduce over a day's work (§3.3).
/// derive_source MUST point to tape (not a model session).
public struct MorningRitualPayload: Codable, Equatable, Sendable {
    public let type: String
    /// ISO 8601 date.
    public let date: String
    public let tapeRange: String
    /// Five buckets: done / staged / needs_approval / blocked / failed.
    public let buckets: [MorningBucket]

    enum CodingKeys: String, CodingKey {
        case type, date
        case tapeRange = "tape_range"
        case buckets
    }

    public init(date: String, tapeRange: String, buckets: [MorningBucket]) {
        self.type = "morning_ritual"
        self.date = date
        self.tapeRange = tapeRange
        self.buckets = buckets
    }
}

/// One suggestion in an intent_suggestions block.
public struct IntentSuggestion: Codable, Equatable, Sendable {
    public let label: String
    public let intentText: String
    public let contextTag: String?

    enum CodingKeys: String, CodingKey {
        case label
        case intentText = "intent_text"
        case contextTag = "context_tag"
    }

    public init(label: String, intentText: String, contextTag: String? = nil) {
        self.label = label
        self.intentText = intentText
        self.contextTag = contextTag
    }
}

/// `intent_suggestions` — kernel-state-driven intent surface (§4.1, not a static menu).
public struct IntentSuggestionsPayload: Codable, Equatable, Sendable {
    public let type: String
    public let suggestions: [IntentSuggestion]

    enum CodingKeys: String, CodingKey { case type, suggestions }

    public init(suggestions: [IntentSuggestion]) {
        self.type = "intent_suggestions"
        self.suggestions = suggestions
    }
}

/// `credential_field` — secure credential input surface (§7.1 / §3.3 渲染铁律).
/// RENDERING IRON LAW: MUST be rendered via macOS SecureField (isSecure=true).
/// Plaintext default values are forbidden. Facilitator context MUST NOT
/// contain credential plaintext (white paper §9 / §13.7).
public struct CredentialFieldPayload: Codable, Equatable, Sendable {
    public let type: String
    public let fieldId: String
    public let label: String
    public let credentialScope: String

    enum CodingKeys: String, CodingKey {
        case type
        case fieldId = "field_id"
        case label
        case credentialScope = "credential_scope"
    }

    public init(fieldId: String, label: String, credentialScope: String) {
        self.type = "credential_field"
        self.fieldId = fieldId
        self.label = label
        self.credentialScope = credentialScope
    }
}
