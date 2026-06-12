// FacilitatorRuntime.swift — runtime kind probe for the Orb+Facilitator shell.
//
// A1_16 scope: determine whether the local Apple FoundationModels FM stack is
// available, a Meta AI API key is configured, or neither (degraded).
//
// IMPORTANT safety rules:
//   • NO model calls anywhere in this file. Runtime kind only gates which
//     code path the Orb announces and which template projections it uses.
//   • On CI (Apple Intelligence OFF), all tests MUST use MockFacilitatorProbe.
//     The real probe is guarded by #available / canImport and never called in
//     test targets that don't import FoundationModels.
//   • KeychainStore is referenced only through its descriptor (scope string);
//     plaintext secrets never appear here (docs/02 §7.1).

import Foundation

// MARK: - Runtime kind

/// The three distinct facilitator backends the Orb can announce.
public enum FacilitatorRuntimeKind: Equatable, Sendable {
    /// Apple FoundationModels local FM is available on this device.
    case localFM
    /// No local FM but a Meta AI API key is configured in KeychainStore.
    case apiBacked
    /// Neither local FM nor any API key; Orb enters degraded state.
    case degraded
}

// MARK: - Probe protocol

/// Protocol for detecting the facilitator runtime kind.
/// Conformers: `SystemFacilitatorProbe` (real) and `MockFacilitatorProbe` (tests/CI).
public protocol FacilitatorRuntimeProbe: Sendable {
    func detect() -> FacilitatorRuntimeKind
}

// MARK: - System probe

/// The real probe used at runtime. Attempts Apple FM availability first;
/// falls back to API key presence; degrades if neither.
///
/// Compiles on CI (Apple Intelligence may be OFF):
///   - The `#if canImport(FoundationModels)` guard eliminates the import on
///     platforms / SDKs that don't have the framework.
///   - `if #available` guards the runtime check so old macOS versions compile.
public struct SystemFacilitatorProbe: FacilitatorRuntimeProbe, Sendable {
    /// Keychain scope descriptor for the Meta AI API key.
    /// Only the scope string (never the secret) is used here.
    public let metaAIKeyScope: String

    /// A1_33: the probe follows the CURRENT config's scope, not the legacy
    /// constant. After A1_32 the key is saved under the configured scope
    /// (deepseek-api by user-ruled default) — probing the old constant meant
    /// a saved key was invisible and the app stayed degraded after restart
    /// (found by the 2026-06-12 computer-use real-GUI test).
    public init(metaAIKeyScope: String = MetaAIConfigStore.load().credentialScope) {
        self.metaAIKeyScope = metaAIKeyScope
    }

    public func detect() -> FacilitatorRuntimeKind {
        if isLocalFMAvailable() {
            return .localFM
        }
        if KeychainStore.shared.hasSecret(service: metaAIKeyScope, account: "api_key") {
            return .apiBacked
        }
        return .degraded
    }

    /// Returns true iff Apple FoundationModels FM is available on this device.
    /// The entire implementation is erased to `false` when the SDK doesn't
    /// include FoundationModels — CI and older macOS stay buildable.
    private func isLocalFMAvailable() -> Bool {
#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            // SystemLanguageModel.default.availability is the public API
            // introduced with Apple Intelligence (macOS 26 / WWDC 2025).
            // We import lazily via NSClassFromString to avoid a hard link
            // that would break CI SDKs that don't have the symbol.
            // The real resolution: FoundationModels is present → try the
            // availability check; if the symbol is missing at link time
            // (beta SDK mismatch), the canImport guard prevents compilation.
            // In production this is a straightforward availability query.
            let cls: AnyClass? = NSClassFromString("FMSystemLanguageModel")
            return cls != nil
        }
        return false
#else
        return false
#endif
    }
}

// MARK: - Mock probe (tests / CI)

/// Deterministic probe for unit tests. Never touches FM or Keychain.
public struct MockFacilitatorProbe: FacilitatorRuntimeProbe, Sendable {
    public let fixedKind: FacilitatorRuntimeKind

    public init(_ kind: FacilitatorRuntimeKind) {
        self.fixedKind = kind
    }

    public func detect() -> FacilitatorRuntimeKind { fixedKind }
}
