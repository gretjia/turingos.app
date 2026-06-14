// Swift projection of contracts/event_stream.schema.json (tos.app.event.v0).
// The JSON schema is the law; this mirrors daemon/src/events.rs. Contract
// conformance is enforced by tests that replay every committed fixture -
// the same repo-law replay the Rust side runs, so the two language mirrors
// cannot drift silently (cross-language conservation via shared fixtures).
//
// Strictness asymmetry is DELIBERATE (S-stage finding, ratified here): the
// Rust PRODUCER mirror is deny_unknown_fields (tightness enforced where
// envelopes are born); this CONSUMER mirror tolerates additive unknown
// fields so the app survives daemon minor-version field additions without
// a lockstep release. Value/count drift is still caught by the shared
// fixtures; only consumer-side looseness is intentionally open.

import Foundation

public let eventSchemaVersion = "tos.app.event.v0"

public struct EventEnvelope: Codable, Sendable, Equatable {
    public let eventId: String
    public let seq: UInt64
    public let ts: String
    public let schemaVersion: String
    public let kind: EventKind
    public let source: EventSource
    public let trustState: TrustState
    public let payload: JSONValue

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case seq, ts
        case schemaVersion = "schema_version"
        case kind, source
        case trustState = "trust_state"
        case payload
    }
}

public enum EventKind: String, Codable, Sendable, CaseIterable {
    case projectRegistered = "ProjectRegistered"
    case worktreeDiscovered = "WorktreeDiscovered"
    case worktreeRemoved = "WorktreeRemoved"
    case fileChanged = "FileChanged"
    case diffSnapshot = "DiffSnapshot"
    case proposalCandidate = "ProposalCandidate"
    case proposalSubmitted = "ProposalSubmitted"
    case proposalRejected = "ProposalRejected"
    case proposalAccepted = "ProposalAccepted"
    case predicateResult = "PredicateResult"
    case vetoVerdict = "VetoVerdict"
    case agentManifestRegistered = "AgentManifestRegistered"
    case agentSessionStarted = "AgentSessionStarted"
    case agentSessionEnded = "AgentSessionEnded"
    case signatureVerified = "SignatureVerified"
    case signatureRejected = "SignatureRejected"
    case ratificationProposed = "RatificationProposed"
    case ratificationCeremonyOpened = "RatificationCeremonyOpened"
    case ratificationSigned = "RatificationSigned"
    case ratificationTagCreated = "RatificationTagCreated"
    case marketTxObserved = "MarketTxObserved"
    case reconciliationCompleted = "ReconciliationCompleted"
    case branchObserved = "BranchObserved"
    case branchRemoved = "BranchRemoved"
}

public enum EventSource: String, Codable, Sendable {
    case git, fsevents, human, daemon, fixture, github
    case claudeHook = "claude_hook"
    case codexAppserver = "codex_appserver"
}

public enum TrustState: String, Codable, Sendable {
    case observedUnsigned = "observed_unsigned"
    case manifestMissing = "manifest_missing"
    case manifestRegistered = "manifest_registered"
    case signatureValid = "signature_valid"
    case signatureInvalid = "signature_invalid"
    case signerUnregistered = "signer_unregistered"
    case signerRevoked = "signer_revoked"
    case capabilityMissing = "capability_missing"
    case humanAdopted = "human_adopted"
    case humanRootSigned = "human_root_signed"
    case legacyPreRule = "legacy_pre_rule"
}

/// Arbitrary JSON payload (schema keeps payload an open object).
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }
}
