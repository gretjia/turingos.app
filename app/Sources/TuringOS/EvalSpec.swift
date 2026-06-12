// EvalSpec.swift — Eval specification model for A1_28 capability eval harness.
//
// BOUNDARY: pure data — no IO, no network, no Date, no random.
//
// Constitutional anchors:
//   - WHITEPAPER.md §13.8 / §13.9 — eval harness evaluates candidate capability
//     deterministically, returns a report; does NOT activate, persist, or write tape.
//
// Each EvalSpec describes one evaluation to run against a candidate CapabilityManifest.
// EvalKind selects the evaluation strategy; params carry the typed payload.

import Foundation

// MARK: - EvalKind

/// Discriminates which evaluation strategy is applied.
///
/// | Kind                | Description                                                          |
/// |---------------------|----------------------------------------------------------------------|
/// | structural          | ManifestValidator must report `.valid` — no extra params needed.    |
/// | determinism         | Runner called twice on the same sample; pass iff byte-equal output. |
/// | schemaConformance   | Candidate output must contain the declared schema's required keys.   |
/// | golden              | Candidate output must byte-equal the golden reference bytes.         |
public enum EvalKind: String, Codable, CaseIterable, Sendable, Equatable {
    case structural        = "structural"
    case determinism       = "determinism"
    case schemaConformance = "schema_conformance"
    case golden            = "golden"
}

// MARK: - EvalParams

/// Typed per-kind parameter payload.
///
/// - `structural` requires no params (uses ManifestValidator internally).
/// - `determinism` needs one input sample to call the runner twice.
/// - `schemaConformance` needs a schema id/path and the candidate output to check.
/// - `golden` needs the golden reference bytes and the candidate output to compare.
public enum EvalParams: Codable, Sendable, Equatable {

    /// No extra params — ManifestValidator is the evaluator.
    case structural

    /// An input sample (opaque bytes) to present to the runner twice.
    case determinism(inputSample: Data)

    /// Schema identifier (the `$id` of the contract schema) and candidate output bytes.
    /// The harness checks that every required key of the named schema appears in the
    /// candidate output JSON.  `schemaId` is used as the evidence label; `schemaPath`
    /// is the filesystem path the harness will load the schema from.
    case schemaConformance(schemaId: String, schemaPath: String, candidateOutput: Data)

    /// Golden reference bytes and candidate output to compare byte-for-byte.
    case golden(goldenBytes: Data, candidateOutput: Data)

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case kind
        case inputSample      = "input_sample"
        case schemaId         = "schema_id"
        case schemaPath       = "schema_path"
        case candidateOutput  = "candidate_output"
        case goldenBytes      = "golden_bytes"
    }

    public init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(EvalKind.self, forKey: .kind)
        switch kind {
        case .structural:
            self = .structural
        case .determinism:
            let sample = try c.decode(Data.self, forKey: .inputSample)
            self = .determinism(inputSample: sample)
        case .schemaConformance:
            let sid    = try c.decode(String.self, forKey: .schemaId)
            let spath  = try c.decode(String.self, forKey: .schemaPath)
            let output = try c.decode(Data.self, forKey: .candidateOutput)
            self = .schemaConformance(schemaId: sid, schemaPath: spath, candidateOutput: output)
        case .golden:
            let gold   = try c.decode(Data.self, forKey: .goldenBytes)
            let output = try c.decode(Data.self, forKey: .candidateOutput)
            self = .golden(goldenBytes: gold, candidateOutput: output)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .structural:
            try c.encode(EvalKind.structural, forKey: .kind)
        case .determinism(let sample):
            try c.encode(EvalKind.determinism, forKey: .kind)
            try c.encode(sample, forKey: .inputSample)
        case .schemaConformance(let sid, let spath, let output):
            try c.encode(EvalKind.schemaConformance, forKey: .kind)
            try c.encode(sid, forKey: .schemaId)
            try c.encode(spath, forKey: .schemaPath)
            try c.encode(output, forKey: .candidateOutput)
        case .golden(let gold, let output):
            try c.encode(EvalKind.golden, forKey: .kind)
            try c.encode(gold, forKey: .goldenBytes)
            try c.encode(output, forKey: .candidateOutput)
        }
    }
}

// MARK: - EvalSpec

/// One evaluation specification.
///
/// - `id`: unique identifier for this eval within a run (used in `EvalResult.specId`).
/// - `kind`: selects the evaluation strategy.
/// - `required`: when `true`, a `fail` verdict blocks the `qualified` flag on `EvalReport`.
/// - `params`: typed payload, discriminated by `kind`.
public struct EvalSpec: Codable, Sendable, Equatable {
    public let id:       String
    public let kind:     EvalKind
    public let required: Bool
    public let params:   EvalParams

    public init(id: String, kind: EvalKind, required: Bool, params: EvalParams) {
        self.id       = id
        self.kind     = kind
        self.required = required
        self.params   = params
    }
}
