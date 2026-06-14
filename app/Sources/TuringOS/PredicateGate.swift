// PredicateGate.swift — A1_44: 回路2 hard gate (∏p).
//
// Runs a project's OWN trusted predicate (swift build / build_app.sh / a scoped
// test) against a worktree and reduces to {PASS,FAIL} + an evidence hash. This
// EVALUATES the repo's trusted gate over the resulting tree; it does NOT execute
// untrusted agent code in-process (the agent ran externally in the worktree —
// WHITEPAPER §13.8/§13.9, CandidateRunner boundary).
//
// LAWS:
//   - verdict domain is EXACTLY {PASS, FAIL} (shipgate #4 + predicate_result
//     .schema.json). Subjective opinions are NOT verdicts (M6: RiskFinding is a
//     separate track, not here).
//   - FAIL-CLOSED: no predicate configured → throw, never a silent PASS.
//   - evidence_hash = sha256 over (tag, exit, stdout, stderr) — CryptoKit, same
//     shape as ApprovalCardContent.

import Foundation
import CryptoKit

// MARK: - PredicateSpec (commands-as-data)

public struct PredicateSpec: Sendable, Equatable {
    public let tag: String          // [a-z0-9_] slug — flows into predicate_id
    public let executable: String   // absolute path, e.g. /bin/bash, /usr/bin/swift
    public let arguments: [String]

    public init(tag: String, executable: String, arguments: [String]) {
        self.tag = tag
        self.executable = executable
        self.arguments = arguments
    }

    /// `swift build` in the worktree (compiles — cheap, real).
    public static func swiftBuild() -> PredicateSpec {
        PredicateSpec(tag: "swift_build", executable: "/usr/bin/swift", arguments: ["build"])
    }

    /// A repo bash gate, e.g. scripts/build_app.sh / scripts/shipgate.sh <phase>.
    public static func bashScript(tag: String, scriptRelPath: String, args: [String] = []) -> PredicateSpec {
        PredicateSpec(tag: tag, executable: "/bin/bash", arguments: [scriptRelPath] + args)
    }
}

// MARK: - PredicateResult (Codable, keys aligned to predicate_result.schema.json)

public struct PredicateResult: Codable, Equatable, Sendable {
    public enum Verdict: String, Codable, Sendable { case pass = "PASS", fail = "FAIL" }

    public let predicateId: String
    public let schemaVersion: String
    public let verdict: Verdict
    public let evidenceHash: String
    public let target: String

    enum CodingKeys: String, CodingKey {
        case predicateId = "predicate_id"
        case schemaVersion = "schema_version"
        case verdict
        case evidenceHash = "evidence_hash"
        case target
    }

    public init(predicateId: String, verdict: Verdict, evidenceHash: String, target: String) {
        self.predicateId = predicateId
        self.schemaVersion = "tos.app.predicate.v0"
        self.verdict = verdict
        self.evidenceHash = evidenceHash
        self.target = target
    }
}

// MARK: - Errors

public enum PredicateGateError: Error, Equatable, Sendable {
    /// No predicate configured for the target — FAIL-CLOSED (never silent PASS).
    case noPredicateConfigured(target: String)
    case runnerFailed(reason: String)
}

// MARK: - Command runner seam

public protocol CommandRunner: Sendable {
    func run(executable: String, arguments: [String], cwd: URL) throws -> (Int32, String, String)
}

/// Real runner: cwd=worktree, hermetic-ish env, concurrent pipe drain + timeout
/// + SIGTERM→SIGKILL (A1_38 lesson; a build/test emits large output).
public struct LiveCommandRunner: CommandRunner, Sendable {
    public static let timeoutSeconds = 600 // a full build/test can be minutes

    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func set(_ d: Data) { lock.lock(); data = d; lock.unlock() }
        func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
    }

    public init() {}

    public func run(executable: String, arguments: [String], cwd: URL) throws -> (Int32, String, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        p.currentDirectoryURL = cwd
        let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe

        let outBox = DataBox(); let errBox = DataBox()
        let group = DispatchGroup()
        let q = DispatchQueue(label: "app.turingos.predicate.io", attributes: .concurrent)
        let done = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in done.signal() }

        try p.run()
        group.enter(); q.async { outBox.set(outPipe.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        group.enter(); q.async { errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        if done.wait(timeout: .now() + .seconds(Self.timeoutSeconds)) == .timedOut {
            p.terminate()
            if done.wait(timeout: .now() + .seconds(2)) == .timedOut { kill(p.processIdentifier, SIGKILL); done.wait() }
        }
        group.wait()
        return (p.terminationStatus,
                String(data: outBox.get(), encoding: .utf8) ?? "",
                String(data: errBox.get(), encoding: .utf8) ?? "")
    }
}

// MARK: - Gate

public enum PredicateGate {
    /// Evaluate a worktree against its project predicate. Synchronous + blocking
    /// (a real build/test) — callers MUST dispatch off the main thread.
    public static func evaluate(
        worktree: URL,
        target: String,
        predicate: PredicateSpec?,
        runner: CommandRunner = LiveCommandRunner()
    ) throws -> PredicateResult {
        // FAIL-CLOSED: an unconfigured predicate is never a silent pass.
        guard let predicate else {
            throw PredicateGateError.noPredicateConfigured(target: target)
        }
        let (code, out, err) = try runner.run(
            executable: predicate.executable, arguments: predicate.arguments, cwd: worktree)
        let verdict: PredicateResult.Verdict = (code == 0) ? .pass : .fail

        let material = "\(predicate.tag)\n\(code)\n\(out)\n\(err)"
        let hex = SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
        let evidenceHash = "sha256:" + hex
        let predicateId = "prd_" + slug(predicate.tag) + "_" + String(hex.prefix(8))

        return PredicateResult(
            predicateId: predicateId, verdict: verdict, evidenceHash: evidenceHash, target: target)
    }

    /// Reduce to the predicate_id charset [a-z0-9_].
    static func slug(_ s: String) -> String {
        let mapped = s.lowercased().map { c -> Character in
            (c.isASCII && (c.isLowercase || c.isNumber)) ? c : "_"
        }
        let out = String(mapped)
        return out.isEmpty ? "x" : out
    }
}
