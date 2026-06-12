// TuringSkill.swift — Turing Skill model (A1_29).
//
// CONSTITUTIONAL BOUNDARY (WHITEPAPER.md §13.9):
//   "Turing Skill = SKILL.md (instructions + scripts + schemas) + 权限 + 动作类 +
//    回执 schema + replay 规则 + evals + failure_modes"
//
//   "Skill 激活是状态迁移，必须入带" — activation writes a tape node.
//   The runtime tape (ChainTape) is not yet present (P1.9 lane).
//
// SkillStatus has EXACTLY TWO cases:
//   • draft              — being authored / not yet submitted for activation
//   • awaitingActivation — sealed, submitted; waiting for tape-gated activation ceremony
//
// There is DELIBERATELY no `activated` case.  Activation is a kernel-side tape
// event (skill_activated kind, via the ratification gate) and requires the runtime
// tape which is not yet available.  Recording it here would violate the upstream
// contract iron law ("外壳不复制 canonical state logic").
// Type-level enforcement: CaseIterable test asserts .allCases.count == 2.
// Pattern mirrors A1_18 SpecStatus (draft / awaitingRatification, no ratified case).

import CryptoKit
import Foundation

// MARK: - SkillStatus

/// Lifecycle of a TuringSkill draft.
///
/// Two cases only — see constitutional comment at top of file.
/// `activated` is absent: activation is a tape event, not a model field.
public enum SkillStatus: String, Codable, CaseIterable, Sendable, Equatable {
    /// Author is drafting / skill not yet sealed for activation.
    case draft

    /// Skill sealed and awaiting kernel activation ceremony (tape-gated).
    /// Kernel writes the skill_activated tape node — this type never records that.
    case awaitingActivation = "awaiting_activation"
}

// MARK: - TuringSkill

/// Turing Skill — SKILL.md core + Turing law shell.
///
/// ## Law shell fields (WHITEPAPER.md §13.9)
/// - `allowedActionClasses` — reuses `ActionClass` from A1_21 CapabilityManifest.
/// - `credentialScopes` — list of credential scope identifiers (tape stores only hashes).
/// - `receiptSchemaRef`, `inputSchemaRef`, `outputSchemaRef` — path references to schema files.
/// - `evals` — paths to eval suites.
/// - `failureModes` — known failure mode descriptions.
/// - `scriptRefs` — paths to scripts; NEVER executed by this type (law shell only).
///
/// ## Lifecycle boundary
/// This struct is PURE DATA — draft domain only.  It has no activate/run/install API.
/// Lifecycle operations write TapeNodes (skill_activated / skill_deactivated)
/// which require the runtime tape (P1.9 lane, not yet available).
///
/// ## skillHash
/// SHA-256 over a canonical JSON encoding of all *content* fields.
/// `status` is excluded (lifecycle metadata, not content).
/// Same content with different status → same hash.
/// Content change → different hash.
/// Pattern mirrors SpecPackage.specHash (A1_18).
public struct TuringSkill: Codable, Sendable, Equatable {

    // MARK: - Schema version constant

    public static let schemaVersion = "tos.app.skill.v1"

    // MARK: - Identity

    /// Schema version — const "tos.app.skill.v1".
    public let schemaVersion: String

    /// Unique skill identifier (reverse-DNS form recommended, e.g. "app.turingos.skill.markdown_to_doc").
    public let skillId: String

    /// Semantic version string (e.g. "0.1.0").
    public let version: String

    // MARK: - Core SKILL.md fields

    /// One-line description of what the skill does.
    public let description: String

    /// Example trigger phrases that invoke this skill (non-empty recommended).
    public let triggerExamples: [String]

    /// MCP tool IDs or capability IDs this skill requires.
    public let requiredTools: [String]

    /// Markdown instructions body (SKILL.md L2 content).
    public let instructions: String

    /// Path references to scripts bundled with this skill.
    /// CRITICAL: these are path strings ONLY.  No code in this module reads
    /// or executes them.  Script execution requires the runtime (P1.9 lane).
    public let scriptRefs: [String]

    // MARK: - Turing law shell

    /// Action classes this skill is allowed to perform (reuses A1_21 ActionClass).
    /// Fail-closed: if empty, SkillValidator treats the skill as class_3 (most restrictive).
    public let allowedActionClasses: [ActionClass]

    /// Credential scope identifiers this skill may request.
    /// The tape stores only `credential_scope_hash` — plaintext never appears on tape.
    public let credentialScopes: [String]

    /// Optional path reference to the input JSON schema.
    public let inputSchemaRef: String?

    /// Optional path reference to the output JSON schema.
    public let outputSchemaRef: String?

    /// Optional path reference to the receipt JSON schema (action receipt format).
    public let receiptSchemaRef: String?

    /// Paths to eval suites (run at install + replay time).
    public let evals: [String]

    /// Known failure mode descriptions (for human review + Live S3.0 loop).
    public let failureModes: [String]

    // MARK: - Status (excluded from hash)

    /// Lifecycle status.  See constitutional comment: NO `activated` case.
    public var status: SkillStatus

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case schemaVersion      = "schema_version"
        case skillId            = "skill_id"
        case version
        case description
        case triggerExamples    = "trigger_examples"
        case requiredTools      = "required_tools"
        case instructions
        case scriptRefs         = "script_refs"
        case allowedActionClasses = "allowed_action_classes"
        case credentialScopes   = "credential_scopes"
        case inputSchemaRef     = "input_schema_ref"
        case outputSchemaRef    = "output_schema_ref"
        case receiptSchemaRef   = "receipt_schema_ref"
        case evals
        case failureModes       = "failure_modes"
        case status
    }

    // MARK: - Initialiser

    public init(
        skillId: String,
        version: String,
        description: String,
        triggerExamples: [String] = [],
        requiredTools: [String] = [],
        instructions: String = "",
        scriptRefs: [String] = [],
        allowedActionClasses: [ActionClass],
        credentialScopes: [String] = [],
        inputSchemaRef: String? = nil,
        outputSchemaRef: String? = nil,
        receiptSchemaRef: String? = nil,
        evals: [String] = [],
        failureModes: [String] = [],
        status: SkillStatus = .draft
    ) {
        self.schemaVersion        = TuringSkill.schemaVersion
        self.skillId              = skillId
        self.version              = version
        self.description          = description
        self.triggerExamples      = triggerExamples
        self.requiredTools        = requiredTools
        self.instructions         = instructions
        self.scriptRefs           = scriptRefs
        self.allowedActionClasses = allowedActionClasses
        self.credentialScopes     = credentialScopes
        self.inputSchemaRef       = inputSchemaRef
        self.outputSchemaRef      = outputSchemaRef
        self.receiptSchemaRef     = receiptSchemaRef
        self.evals                = evals
        self.failureModes         = failureModes
        self.status               = status
    }

    // MARK: - skillHash

    /// SHA-256 over canonical JSON encoding of content fields (sortedKeys).
    ///
    /// `status` is excluded — status changes do NOT change the hash.
    /// Any content field change DOES change the hash.
    ///
    /// Pattern mirrors SpecPackage.specHash (A1_18): same derivation discipline,
    /// same exclusion of lifecycle metadata.
    public var skillHash: String {
        struct ContentOnly: Codable {
            let skillId: String
            let version: String
            let description: String
            let triggerExamples: [String]
            let requiredTools: [String]
            let instructions: String
            let scriptRefs: [String]
            let allowedActionClasses: [String]
            let credentialScopes: [String]
            let inputSchemaRef: String?
            let outputSchemaRef: String?
            let receiptSchemaRef: String?
            let evals: [String]
            let failureModes: [String]

            enum CodingKeys: String, CodingKey {
                case skillId              = "skill_id"
                case version
                case description
                case triggerExamples      = "trigger_examples"
                case requiredTools        = "required_tools"
                case instructions
                case scriptRefs           = "script_refs"
                case allowedActionClasses = "allowed_action_classes"
                case credentialScopes     = "credential_scopes"
                case inputSchemaRef       = "input_schema_ref"
                case outputSchemaRef      = "output_schema_ref"
                case receiptSchemaRef     = "receipt_schema_ref"
                case evals
                case failureModes         = "failure_modes"
            }
        }
        let content = ContentOnly(
            skillId:              skillId,
            version:              version,
            description:          description,
            triggerExamples:      triggerExamples,
            requiredTools:        requiredTools,
            instructions:         instructions,
            scriptRefs:           scriptRefs,
            allowedActionClasses: allowedActionClasses.map(\.rawValue).sorted(),
            credentialScopes:     credentialScopes,
            inputSchemaRef:       inputSchemaRef,
            outputSchemaRef:      outputSchemaRef,
            receiptSchemaRef:     receiptSchemaRef,
            evals:                evals,
            failureModes:         failureModes
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(content) else { return "sha256:error" }
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
