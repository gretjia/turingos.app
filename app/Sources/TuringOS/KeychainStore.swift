// KeychainStore.swift — minimal Security-framework wrapper for A1_16.
//
// Laws enforced here (docs/02 §7.1 / white paper §9 / §13.7):
//   • The secret VALUE is never printed, logged, or embedded in any ViewIR
//     document or template projection.
//   • Store returns a scope descriptor string (e.g. "meta_ai_api_key") —
//     only that descriptor may appear in UI/state.
//   • All public API uses `service` (scope descriptor) + `account` — callers
//     never receive the raw secret back through any public surface that could
//     accidentally appear in logs.
//
// Thread-safety: all operations are synchronous and safe to call from any
// thread. Security.framework calls are inherently thread-safe.

import Foundation
import Security

// MARK: - Error type

public enum KeychainError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case encodingFailure
    case itemNotFound
    case unavailable
}

// MARK: - KeychainStore

/// Minimal generic-password Keychain wrapper.
/// Returns only a scope descriptor string — no secret is ever surfaced to
/// callers through public API that could end up in View IR / logs.
public final class KeychainStore: @unchecked Sendable {
    public static let shared = KeychainStore()

    public init() {}

    // MARK: - Save

    /// Saves (or overwrites) a secret for the given service+account pair.
    /// The returned value is the service descriptor — not the secret.
    @discardableResult
    public func save(service: String, account: String, secret: String) throws -> String {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.encodingFailure
        }
        // Try update first; if not found, add.
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        // Return descriptor only — NEVER the secret.
        return service
    }

    // MARK: - Load (internal; exposed via hasSecret for external callers)

    /// Loads a secret for the given service+account.
    /// Throws `KeychainError.itemNotFound` when absent.
    /// NOTE: The return value is the raw secret data — this method is
    /// intentionally internal so callers can't accidentally log it.
    func loadRaw(service: String, account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedStatus(errSecInternalError)
            }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Public load: callers get the secret as a String for use ONLY in
    /// secure in-memory contexts (e.g., building an Authorization header).
    /// Never pass this value to View IR, logs, or any observable state.
    public func load(service: String, account: String) throws -> String {
        let data = try loadRaw(service: service, account: account)
        guard let s = String(data: data, encoding: .utf8) else {
            throw KeychainError.encodingFailure
        }
        return s
    }

    // MARK: - Delete

    /// Deletes the Keychain item for the given service+account.
    /// Returns the service descriptor.
    @discardableResult
    public func delete(service: String, account: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
        return service
    }

    // MARK: - Existence check (safe for probes)

    /// Returns true iff a Keychain item exists for the given service+account.
    /// No secret value is returned — safe for use in probes and UI state.
    public func hasSecret(service: String, account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: false,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
