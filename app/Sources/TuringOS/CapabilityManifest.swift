// CapabilityManifest.swift — Codable model for capability_manifest.schema.json (A1_21).
//
// BOUNDARY (WHITEPAPER.md §13.8 / docs/01_KERNEL_CONTRACTS.md I4):
//   Pure validation/classification library.  No lifecycle (install/update/remove)
//   — those write tape nodes which require the runtime tape (P1.9 lane, not yet available).
//   No registry persistence.  No network.
//
// vendor_tier NOTE (schema description verbatim):
//   "verified = publisher identity attested by registry signature, NOT a quality endorsement;
//    community and local carry no attestation."
//
// Fail-closed invariant (schema description / I4):
//   An instance with missing or invalid action_classes MUST be treated as class_3 or denied.
//   The system never assumes a lower-privilege default from an incomplete manifest.

import Foundation

// MARK: - CapabilityKind

/// Maps to the `kind` enum in capability_manifest.schema.json.
public enum CapabilityKind: String, Codable, CaseIterable, Sendable, Equatable {
    case tool              = "tool"
    case skill             = "skill"
    case connector         = "connector"
    case modelProvider     = "model_provider"
    case agentAdapter      = "agent_adapter"
    case viewRenderer      = "view_renderer"
    case executionProfile  = "execution_profile"
}

// MARK: - VendorTier

/// Maps to the `vendor_tier` enum in capability_manifest.schema.json.
///
/// `verified` means publisher identity is attested by a registry signature —
/// it is NOT a quality endorsement.  `community` and `local` carry no attestation.
public enum VendorTier: String, Codable, CaseIterable, Sendable, Equatable {
    case verified  = "verified"
    case community = "community"
    case local     = "local"
}

// MARK: - ActionClass

/// Maps to the `action_classes.default` enum in capability_manifest.schema.json.
///
/// Corresponds to §10 action classification table (WHITEPAPER.md):
///   class_0_read               — zero class: read-only, no side effects
///   class_1_reversible_local   — one class: reversible local actions
///   class_2_remote_draft       — two class: remote draft (staged, not committed)
///   class_3_irreversible_external — three class: irreversible external actions
///
/// Fail-closed invariant: an absent or invalid `default` means fail-closed →
/// treat as `class_3_irreversible_external` or deny (I4, §13.8).
public enum ActionClass: String, Codable, CaseIterable, Sendable, Equatable, Comparable {
    case class0Read                 = "class_0_read"
    case class1ReversibleLocal      = "class_1_reversible_local"
    case class2RemoteDraft          = "class_2_remote_draft"
    case class3IrreversibleExternal = "class_3_irreversible_external"

    /// Numeric level (0–3) matching the §10 table.
    public var level: Int {
        switch self {
        case .class0Read:                 return 0
        case .class1ReversibleLocal:      return 1
        case .class2RemoteDraft:          return 2
        case .class3IrreversibleExternal: return 3
        }
    }

    public static func < (lhs: ActionClass, rhs: ActionClass) -> Bool {
        lhs.level < rhs.level
    }
}

// MARK: - ActionClasses

/// Maps to the `action_classes` object in capability_manifest.schema.json.
///
/// `escalation` is the per-operation override map; values are signature node numbers (1–8).
/// Consumers that cannot parse escalation MUST deny (schema description).
public struct ActionClasses: Codable, Sendable, Equatable {
    /// The default action class for all operations of this capability.
    public let `default`: ActionClass
    /// Optional per-operation escalation map: operation_name → signature_node (1–8).
    public let escalation: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case `default` = "default"
        case escalation
    }

    public init(default defaultClass: ActionClass, escalation: [String: Int]? = nil) {
        self.default    = defaultClass
        self.escalation = escalation
    }
}

// MARK: - Provenance

/// Maps to the `provenance` object in capability_manifest.schema.json.
public struct ManifestProvenance: Codable, Sendable, Equatable {
    /// Whether the capability emits action receipts (required field).
    public let actionReceipt: Bool
    /// Whether the capability supports replay (required field).
    public let replay: Bool

    enum CodingKeys: String, CodingKey {
        case actionReceipt = "action_receipt"
        case replay
    }

    public init(actionReceipt: Bool, replay: Bool) {
        self.actionReceipt = actionReceipt
        self.replay        = replay
    }
}

// MARK: - Evals

/// Maps to the `evals` object in capability_manifest.schema.json.
public struct ManifestEvals: Codable, Sendable, Equatable {
    /// Install-time eval command/path.
    public let install: String
    /// Replay eval command/path.
    public let replay: String

    public init(install: String, replay: String) {
        self.install = install
        self.replay  = replay
    }
}

// MARK: - CapabilityManifest

/// Codable model mirroring capability_manifest.schema.json exactly.
///
/// ## Constitutional anchors
/// - WHITEPAPER.md §13.8 — Install ≠ trust; fail-closed on missing action_classes
/// - docs/01_KERNEL_CONTRACTS.md I4 — fail-closed invariant
/// - contracts/capability_manifest.schema.json — machine law (schema wins on conflict)
///
/// ## Lifecycle boundary
/// This struct is PURE DATA.  It has no install/update/remove API.
/// Lifecycle operations write TapeNodes (ToolInstall / ToolUpdate / ToolRemove)
/// which require the runtime tape (P1.9 lane, not yet available).
public struct CapabilityManifest: Codable, Sendable, Equatable {

    // MARK: Required fields (from schema "required" array)

    /// Schema version — const "tos.app.capability_manifest.v0".
    public let schemaVersion: String

    /// Unique capability identifier (e.g. "com.example.github.pr").
    public let id: String

    /// Kind of capability.
    public let kind: CapabilityKind

    /// Semantic version string.
    public let version: String

    /// Vendor tier — identity attestation, NOT quality endorsement.
    public let vendorTier: VendorTier

    /// Action class declaration — the fail-closed key field.
    public let actionClasses: ActionClasses

    /// Permissions object (filesystem domain / network domain / credential scopes).
    public let permissions: [String: AnyCodable]

    /// Credential scopes object.
    public let credentialScopes: [String: AnyCodable]

    /// Provenance flags.
    public let provenance: ManifestProvenance

    /// Evals (install + replay paths).
    public let evals: ManifestEvals

    /// Audit node declarations.
    public let auditNodes: [String: AnyCodable]

    // MARK: Optional fields

    /// Sandbox configuration (optional, e.g. container_lane).
    public let sandbox: [String: AnyCodable]?

    /// Path to the SKILL.md file for skill-kind capabilities (optional).
    public let skillMdPath: String?

    // MARK: CodingKeys

    enum CodingKeys: String, CodingKey {
        case schemaVersion    = "schema_version"
        case id
        case kind
        case version
        case vendorTier       = "vendor_tier"
        case actionClasses    = "action_classes"
        case permissions
        case credentialScopes = "credential_scopes"
        case provenance
        case evals
        case auditNodes       = "audit_nodes"
        case sandbox
        case skillMdPath      = "skill_md_path"
    }

    // MARK: Initialiser

    public init(
        id: String,
        kind: CapabilityKind,
        version: String,
        vendorTier: VendorTier,
        actionClasses: ActionClasses,
        permissions: [String: AnyCodable] = [:],
        credentialScopes: [String: AnyCodable] = [:],
        provenance: ManifestProvenance,
        evals: ManifestEvals,
        auditNodes: [String: AnyCodable] = [:],
        sandbox: [String: AnyCodable]? = nil,
        skillMdPath: String? = nil
    ) {
        self.schemaVersion    = "tos.app.capability_manifest.v0"
        self.id               = id
        self.kind             = kind
        self.version          = version
        self.vendorTier       = vendorTier
        self.actionClasses    = actionClasses
        self.permissions      = permissions
        self.credentialScopes = credentialScopes
        self.provenance       = provenance
        self.evals            = evals
        self.auditNodes       = auditNodes
        self.sandbox          = sandbox
        self.skillMdPath      = skillMdPath
    }
}

// MARK: - AnyCodable helper

/// Minimal type-erased Codable wrapper for open-schema objects (permissions / audit_nodes / etc.).
/// Supports JSON value types: null, bool, int, double, string, array, object.
///
/// Uses an explicit `AnyCodableStorage` enum instead of `Any?` so that the type
/// satisfies Swift 6 `Sendable` (Any is not Sendable).
public enum AnyCodableStorage: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableStorage])
    case object([String: AnyCodableStorage])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                                           { self = .null }
        else if let b = try? c.decode(Bool.self)                   { self = .bool(b) }
        else if let i = try? c.decode(Int.self)                    { self = .int(i) }
        else if let d = try? c.decode(Double.self)                 { self = .double(d) }
        else if let s = try? c.decode(String.self)                 { self = .string(s) }
        else if let a = try? c.decode([AnyCodableStorage].self)    { self = .array(a) }
        else if let o = try? c.decode([String: AnyCodableStorage].self) { self = .object(o) }
        else                                                       { self = .null }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:           try c.encodeNil()
        case .bool(let b):    try c.encode(b)
        case .int(let i):     try c.encode(i)
        case .double(let d):  try c.encode(d)
        case .string(let s):  try c.encode(s)
        case .array(let a):   try c.encode(a)
        case .object(let o):  try c.encode(o)
        }
    }
}

/// Alias so call sites can use `AnyCodable` as the dictionary value type.
public typealias AnyCodable = AnyCodableStorage
