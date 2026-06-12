// CandidateRunner.swift — Candidate runner protocol and mock/stub for A1_28.
//
// BOUNDARY: pure protocol + pure Swift mock.  NO Process, NO Shell, NO exec,
// NO arbitrary third-party code execution.
//
// Constitutional anchors:
//   - WHITEPAPER.md §13.8 / §13.9 — the harness evaluates; it does NOT execute
//     untrusted code.  Live capability execution arrives with sandbox/runtime
//     (out of scope for this atom).
//
// The LIVE runner is intentionally NOT implemented here.  Providing it now would
// mean executing untrusted code without the sandbox/runtime layer.
// `NotYetAvailableCandidateRunner` is the fail-closed default for the live path.
//
// Tests use `MockCandidateRunner` which is pure Swift and fully deterministic.

import Foundation

// MARK: - EvalError

/// Errors the harness or runner may surface.
public enum EvalError: Error, Sendable, Equatable {
    /// The live runner is not yet available in this atom.
    /// Live capability execution requires the sandbox/runtime layer (P1.9 lane).
    case candidateExecutionUnavailable

    /// The runner produced an unexpected error.
    case runnerFailed(reason: String)
}

// MARK: - CandidateRunner

/// Protocol representing the thing under test.
///
/// - The harness calls `produce(forSample:)` once or twice (for determinism evals).
/// - Implementations MUST be pure and MUST NOT shell out or exec untrusted code.
/// - The live implementation is out of scope for A1_28 — see `NotYetAvailableCandidateRunner`.
public protocol CandidateRunner: Sendable {
    /// Produce output for the given input sample.
    ///
    /// - Parameter sample: Opaque input bytes (e.g. a JSON-encoded request).
    /// - Returns: Output bytes.
    /// - Throws: `EvalError` or any other error describing the failure.
    func produce(forSample sample: Data) throws -> Data
}

// MARK: - MockCandidateRunner

/// A pure Swift mock for use in tests.  Deterministic and controllable.
///
/// Behavior:
///   - `.stableOutput(data)`:  every call returns `data` unchanged.
///   - `.driftingOutput`:      each call returns a fresh UUID byte sequence → byte-unequal.
///   - `.alwaysThrows`:        throws `EvalError.runnerFailed(reason:)` on every call.
public final class MockCandidateRunner: CandidateRunner, @unchecked Sendable {

    public enum Behavior {
        /// Always returns the same bytes regardless of input.
        case stableOutput(Data)
        /// Returns a different byte sequence each call (drifting — for determinism-fail tests).
        case driftingOutput
        /// Always throws `EvalError.runnerFailed`.
        case alwaysThrows
    }

    private let behavior: Behavior
    /// Counter used to produce distinct outputs in the `driftingOutput` path.
    /// Mutated only on calling thread (tests are synchronous).
    private var callCount: Int = 0

    public init(behavior: Behavior) {
        self.behavior = behavior
    }

    public func produce(forSample sample: Data) throws -> Data {
        switch behavior {
        case .stableOutput(let data):
            return data
        case .driftingOutput:
            // Each call returns callCount-prefixed bytes — always different.
            callCount += 1
            var result = withUnsafeBytes(of: callCount) { Data($0) }
            result.append(sample)
            return result
        case .alwaysThrows:
            throw EvalError.runnerFailed(reason: "mock configured to always throw")
        }
    }
}

// MARK: - NotYetAvailableCandidateRunner

/// Fail-closed default for the live capability execution path.
///
/// This is the default live runner for A1_28.  It unconditionally throws
/// `EvalError.candidateExecutionUnavailable` because:
///
///   1. Live capability execution requires the sandbox/runtime layer (P1.9).
///   2. Implementing a real exec path here would mean executing untrusted code
///      without the constitutional guardrails that live in the sandbox lane.
///   3. Fail-closed is the correct default: a harness that cannot run a required
///      eval must FAIL, not silently pass.
///
/// When the sandbox/runtime layer is available, a real `LiveCandidateRunner` will
/// replace this — that is explicitly out of scope for the current atom.
public struct NotYetAvailableCandidateRunner: CandidateRunner {
    public init() {}

    /// Always throws `EvalError.candidateExecutionUnavailable`.
    public func produce(forSample sample: Data) throws -> Data {
        throw EvalError.candidateExecutionUnavailable
    }
}
