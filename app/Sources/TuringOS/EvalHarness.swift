// EvalHarness.swift — Deterministic capability eval harness for A1_28.
//
// BOUNDARY: pure/deterministic.  No IO, no network, no Date, no random,
// no arbitrary exec.  The CandidateRunner is an injected protocol; tests use
// MockCandidateRunner.  The live path uses NotYetAvailableCandidateRunner
// (fail-closed — throws EvalError.candidateExecutionUnavailable).
//
// Constitutional anchors:
//   - WHITEPAPER.md §13.8 / §13.9
//   - This harness EVALUATES; it does NOT activate, persist, or write tape.
//   - Output domain is exactly {pass, fail} — no third value.
//
// MISSING EVAL RULE (fail-closed):
//   If manifest.evals declares install or replay but the corresponding spec is
//   absent from specs[] OR the runner throws, that eval is a FAIL.
//   A manifest that promises evals it cannot run is unqualified.

import Foundation

// MARK: - EvalVerdict

/// Binary verdict for one evaluated spec.
///
/// The output domain is EXACTLY {pass, fail} — no third value.
/// An exhaustive switch over this enum will catch any future additions at compile time.
public enum EvalVerdict: String, Codable, Sendable, Equatable {
    case pass = "pass"
    case fail = "fail"
}

// MARK: - EvalResult

/// Result for a single evaluated `EvalSpec`.
public struct EvalResult: Codable, Sendable, Equatable {
    /// Matches `EvalSpec.id`.
    public let specId:   String
    /// The kind of eval that produced this result.
    public let kind:     EvalKind
    /// Binary verdict — domain = {pass, fail}.
    public let verdict:  EvalVerdict
    /// Human-readable evidence string (non-empty; describes what passed or why it failed).
    public let evidence: String

    public init(specId: String, kind: EvalKind, verdict: EvalVerdict, evidence: String) {
        self.specId   = specId
        self.kind     = kind
        self.verdict  = verdict
        self.evidence = evidence
    }
}

// MARK: - EvalReport

/// Complete eval report for one manifest + spec set run.
///
/// `qualified` == every REQUIRED spec with verdict == .pass.
/// A manifest with any required-fail is NOT qualified.
public struct EvalReport: Codable, Sendable, Equatable {
    /// Per-spec results in the order they were evaluated.
    public let results:   [EvalResult]
    /// True iff every required spec passed.
    public let qualified: Bool

    public init(results: [EvalResult], qualified: Bool) {
        self.results   = results
        self.qualified = qualified
    }
}

// MARK: - EvalHarness

/// Pure, deterministic harness.
///
/// Inject a `CandidateRunner` (mock in tests; `NotYetAvailableCandidateRunner` for live).
/// `run(manifest:specs:runner:)` evaluates each spec and returns an `EvalReport`.
public enum EvalHarness {

    // MARK: - Public entry point

    /// Run all evals and return a report.
    ///
    /// - Parameters:
    ///   - manifest:  The `CapabilityManifest` being evaluated.
    ///   - specs:     The list of `EvalSpec` instances to evaluate.
    ///   - runner:    Injected `CandidateRunner` (pure mock in tests; not-yet-available in live).
    ///   - schemaDir: Base directory for resolving schema paths (only used by schemaConformance evals).
    ///                Defaults to `nil` (path resolved as-is or relative to CWD).
    /// - Returns: An `EvalReport` with per-spec results and an overall `qualified` flag.
    public static func run(
        manifest:  CapabilityManifest,
        specs:     [EvalSpec],
        runner:    CandidateRunner,
        schemaDir: URL? = nil
    ) -> EvalReport {

        // Step 1: evaluate each provided spec.
        var results: [EvalResult] = specs.map { spec in
            evalOne(spec: spec, manifest: manifest, runner: runner, schemaDir: schemaDir)
        }

        // Step 2: MISSING EVAL RULE — fail-closed.
        // If manifest.evals declares install/replay but the corresponding spec
        // is absent from specs[] OR could not run, that is a FAIL.
        let providedKinds = Set(specs.map(\.kind))

        // The manifest schema requires both evals.install and evals.replay.
        // We map them to EvalKind.structural (install) and EvalKind.determinism (replay)
        // as the canonical spec kinds that must be present.
        //
        // Governance note: the harness requires that the install eval be covered by a
        // structural spec (validates the manifest itself) and the replay eval be covered
        // by a determinism spec (proves the runner is stable across calls).  If either
        // is absent, we inject a synthetic FAIL result for the missing coverage.

        let installCovered    = providedKinds.contains(.structural)
        let replayCovered     = providedKinds.contains(.determinism)

        if !installCovered {
            results.append(EvalResult(
                specId:   "synthetic_install_coverage",
                kind:     .structural,
                verdict:  .fail,
                evidence: "manifest.evals.install is declared but no structural EvalSpec was provided — " +
                          "a manifest that promises evals it cannot run is unqualified (fail-closed)"
            ))
        }
        if !replayCovered {
            results.append(EvalResult(
                specId:   "synthetic_replay_coverage",
                kind:     .determinism,
                verdict:  .fail,
                evidence: "manifest.evals.replay is declared but no determinism EvalSpec was provided — " +
                          "a manifest that promises evals it cannot run is unqualified (fail-closed)"
            ))
        }

        // Step 3: qualified iff every REQUIRED spec passed.
        // Synthetic missing-eval results are always required (fail-closed).
        let requiredSpecIds = Set(specs.filter(\.required).map(\.id))
            .union(["synthetic_install_coverage", "synthetic_replay_coverage"])

        let qualifiedResults = results.filter { requiredSpecIds.contains($0.specId) }
        let qualified = qualifiedResults.allSatisfy { $0.verdict == .pass }

        return EvalReport(results: results, qualified: qualified)
    }

    // MARK: - Per-spec evaluator

    private static func evalOne(
        spec:      EvalSpec,
        manifest:  CapabilityManifest,
        runner:    CandidateRunner,
        schemaDir: URL?
    ) -> EvalResult {
        switch spec.kind {

        // ---------------------------------------------------------------
        // structural: ManifestValidator must report .valid
        // ---------------------------------------------------------------
        case .structural:
            guard case .structural = spec.params else {
                return EvalResult(
                    specId:   spec.id,
                    kind:     .structural,
                    verdict:  .fail,
                    evidence: "EvalSpec.params mismatch: expected .structural (no payload) for structural eval"
                )
            }
            return evalStructural(spec: spec, manifest: manifest)

        // ---------------------------------------------------------------
        // determinism: runner called twice; pass iff byte-equal output
        // ---------------------------------------------------------------
        case .determinism:
            guard case .determinism(let sample) = spec.params else {
                return EvalResult(
                    specId:   spec.id,
                    kind:     .determinism,
                    verdict:  .fail,
                    evidence: "EvalSpec.params mismatch: expected .determinism(inputSample:)"
                )
            }
            return evalDeterminism(spec: spec, sample: sample, runner: runner)

        // ---------------------------------------------------------------
        // schemaConformance: candidate output must contain required keys
        // ---------------------------------------------------------------
        case .schemaConformance:
            guard case .schemaConformance(let schemaId, let schemaPath, let output) = spec.params else {
                return EvalResult(
                    specId:   spec.id,
                    kind:     .schemaConformance,
                    verdict:  .fail,
                    evidence: "EvalSpec.params mismatch: expected .schemaConformance(...)"
                )
            }
            return evalSchemaConformance(
                spec:      spec,
                schemaId:  schemaId,
                schemaPath: schemaPath,
                output:    output,
                schemaDir: schemaDir
            )

        // ---------------------------------------------------------------
        // golden: candidate output must byte-equal the golden reference
        // ---------------------------------------------------------------
        case .golden:
            guard case .golden(let goldenBytes, let output) = spec.params else {
                return EvalResult(
                    specId:   spec.id,
                    kind:     .golden,
                    verdict:  .fail,
                    evidence: "EvalSpec.params mismatch: expected .golden(...)"
                )
            }
            return evalGolden(spec: spec, goldenBytes: goldenBytes, output: output)
        }
    }

    // MARK: - structural

    private static func evalStructural(spec: EvalSpec, manifest: CapabilityManifest) -> EvalResult {
        // Re-encode the manifest to JSON and run ManifestValidator on the bytes.
        // This is a round-trip check: encode → validate.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let manifestData = try? encoder.encode(manifest) else {
            return EvalResult(
                specId:   spec.id,
                kind:     .structural,
                verdict:  .fail,
                evidence: "failed to re-encode CapabilityManifest to JSON for structural eval"
            )
        }

        let validator = ManifestValidator()
        let result    = validator.validate(manifestData)

        switch result {
        case .valid:
            return EvalResult(
                specId:   spec.id,
                kind:     .structural,
                verdict:  .pass,
                evidence: "ManifestValidator reported .valid for manifest id=\(manifest.id)"
            )
        case .invalid(let errors):
            let desc = errors.map(\.description).joined(separator: "; ")
            return EvalResult(
                specId:   spec.id,
                kind:     .structural,
                verdict:  .fail,
                evidence: "ManifestValidator reported .invalid: \(desc)"
            )
        }
    }

    // MARK: - determinism

    private static func evalDeterminism(
        spec:    EvalSpec,
        sample:  Data,
        runner:  CandidateRunner
    ) -> EvalResult {
        let output1: Data
        let output2: Data

        do {
            output1 = try runner.produce(forSample: sample)
        } catch {
            return EvalResult(
                specId:   spec.id,
                kind:     .determinism,
                verdict:  .fail,
                evidence: "runner.produce threw on first call: \(error)"
            )
        }

        do {
            output2 = try runner.produce(forSample: sample)
        } catch {
            return EvalResult(
                specId:   spec.id,
                kind:     .determinism,
                verdict:  .fail,
                evidence: "runner.produce threw on second call: \(error)"
            )
        }

        if output1 == output2 {
            return EvalResult(
                specId:   spec.id,
                kind:     .determinism,
                verdict:  .pass,
                evidence: "runner produced byte-equal output on two calls (\(output1.count) bytes)"
            )
        } else {
            return EvalResult(
                specId:   spec.id,
                kind:     .determinism,
                verdict:  .fail,
                evidence: "runner output drifted between calls: " +
                          "call1=\(output1.count) bytes, call2=\(output2.count) bytes — NOT byte-equal"
            )
        }
    }

    // MARK: - schemaConformance

    private static func evalSchemaConformance(
        spec:       EvalSpec,
        schemaId:   String,
        schemaPath: String,
        output:     Data,
        schemaDir:  URL?
    ) -> EvalResult {
        // Resolve schema path.
        let schemaURL: URL
        if let base = schemaDir {
            schemaURL = base.appendingPathComponent(schemaPath)
        } else {
            schemaURL = URL(fileURLWithPath: schemaPath)
        }

        // Load schema JSON.
        guard let schemaData = try? Data(contentsOf: schemaURL),
              let schemaJSON = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any],
              let required   = schemaJSON["required"] as? [String]
        else {
            return EvalResult(
                specId:   spec.id,
                kind:     .schemaConformance,
                verdict:  .fail,
                evidence: "could not load or parse schema at path '\(schemaURL.path)' (id=\(schemaId))"
            )
        }

        // Parse candidate output.
        guard let outputJSON = try? JSONSerialization.jsonObject(with: output) as? [String: Any] else {
            return EvalResult(
                specId:   spec.id,
                kind:     .schemaConformance,
                verdict:  .fail,
                evidence: "candidate output is not a parseable JSON object (schema id=\(schemaId))"
            )
        }

        // Check required keys.
        let missingKeys = required.filter { outputJSON[$0] == nil }
        if missingKeys.isEmpty {
            return EvalResult(
                specId:   spec.id,
                kind:     .schemaConformance,
                verdict:  .pass,
                evidence: "candidate output contains all \(required.count) required keys for schema \(schemaId)"
            )
        } else {
            return EvalResult(
                specId:   spec.id,
                kind:     .schemaConformance,
                verdict:  .fail,
                evidence: "candidate output missing required keys for schema \(schemaId): \(missingKeys.sorted().joined(separator: ", "))"
            )
        }
    }

    // MARK: - golden

    private static func evalGolden(
        spec:        EvalSpec,
        goldenBytes: Data,
        output:      Data
    ) -> EvalResult {
        if output == goldenBytes {
            return EvalResult(
                specId:   spec.id,
                kind:     .golden,
                verdict:  .pass,
                evidence: "candidate output is byte-equal to golden reference (\(goldenBytes.count) bytes)"
            )
        } else {
            return EvalResult(
                specId:   spec.id,
                kind:     .golden,
                verdict:  .fail,
                evidence: "candidate output differs from golden: " +
                          "output=\(output.count) bytes, golden=\(goldenBytes.count) bytes — NOT byte-equal"
            )
        }
    }
}
