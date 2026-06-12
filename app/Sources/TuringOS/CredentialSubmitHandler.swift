// CredentialSubmitHandler.swift — testable save path for credential_field (A1_32).
//
// CONSTITUTIONAL ANCHORS (docs/02 §7.1 / white paper §9 / §13.7):
//   • The secret flows ONLY: SecureField → this handler → injected saver
//     (production saver = KeychainStore.shared.save). Never logged, never
//     stored on the handler, never echoed back to any view state.
//   • account is fixed to "api_key" — the same account DeepSeekPresets
//     documents for KeychainStore.load (A1_31), so save and load agree.
//   • Tests inject a recording saver; the real Keychain is never touched
//     in CI (same discipline as FacilitatorRuntime's MockFacilitatorProbe).

import Foundation

// MARK: - CredentialSubmitHandler

/// Pure-logic submit handler for CredentialFieldView.
///
/// Holds an injected `saver` closure so the save path is unit-testable
/// without the real Keychain. The handler never retains the secret.
public struct CredentialSubmitHandler: Sendable {

    /// (service, account, secret) -> scope descriptor (echo of service).
    public typealias Saver = @Sendable (String, String, String) throws -> String

    /// Fixed account name — must match DeepSeekPresets' documented usage
    /// (KeychainStore.load(service: credentialScope, account: "api_key")).
    public static let account = "api_key"

    private let saver: Saver

    public init(saver: @escaping Saver) {
        self.saver = saver
    }

    /// Production handler: writes through to the shared Keychain store.
    public static func keychain() -> CredentialSubmitHandler {
        CredentialSubmitHandler { service, account, secret in
            try KeychainStore.shared.save(service: service, account: account, secret: secret)
        }
    }

    /// Submits the secret for the given scope.
    ///
    /// - Returns: `.success(scope)` after the saver persisted the secret;
    ///            `.failure` for empty input (saver not called) or saver error.
    /// - Note: the caller MUST clear its field binding on success — the
    ///   handler cannot (and must not) hold the secret to do it.
    public func submit(scope: String, secret: String) -> Result<String, CredentialSubmitError> {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptySecret)
        }
        guard !scope.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.emptyScope)
        }
        do {
            let descriptor = try saver(scope, Self.account, trimmed)
            return .success(descriptor)
        } catch {
            return .failure(.saverFailed(String(describing: error)))
        }
    }
}

// MARK: - CredentialSubmitError

public enum CredentialSubmitError: Error, Equatable, Sendable {
    /// Empty input — saver is NOT called.
    case emptySecret
    /// Scope descriptor missing — saver is NOT called.
    case emptyScope
    /// Underlying saver (Keychain) threw; description only, never the secret.
    case saverFailed(String)
}
