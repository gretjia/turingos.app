// MetaAIConfig.swift — Meta AI endpoint configuration model for A1_16.
//
// Persisted via UserDefaults (following Workspace.swift simple-persistence
// idiom). NO secrets are stored here — only the Keychain scope descriptor
// reference. The actual API key lives exclusively in KeychainStore.
//
// Security discipline (docs/02 §7.1 / white paper §9 / §13.7):
//   • `credentialScope` is a scope descriptor (e.g. "meta_ai_api_key").
//   • No field in this struct carries a plaintext secret.
//   • JSON encoding of this type MUST NOT contain the secret — tests assert this.

import Foundation

// MARK: - Provider kind

/// The API protocol the endpoint speaks.
public enum MetaAIProviderKind: String, Codable, CaseIterable, Equatable, Sendable {
    /// OpenAI-compatible REST API (chat/completions endpoint).
    case openaiCompatible = "openai_compatible"
    /// Anthropic Messages API format.
    case anthropicMessages = "anthropic_messages"
    /// Meta's native Llama API format.
    case native = "native"
}

// MARK: - Config model

/// Configuration for a Meta AI (or compatible) endpoint.
/// Stored in UserDefaults; no secrets anywhere in this struct.
public struct MetaAIConfig: Codable, Equatable, Sendable {
    /// The API protocol the endpoint speaks.
    public var providerKind: MetaAIProviderKind
    /// Optional custom endpoint URL (nil = provider default).
    public var endpointURL: URL?
    /// Keychain scope descriptor — the ONLY reference to credentials.
    /// The actual key is in KeychainStore.shared, never here.
    public var credentialScope: String
    /// Human-readable display name for the UI card.
    public var displayName: String

    public static let defaultCredentialScope = "meta_ai_api_key"

    /// A1_32: user-ruled default (2026-06-12) — Meta AI runs on DeepSeek
    /// deepseek-v4-pro via the OpenAI-compatible wire. credentialScope is
    /// DeepSeekPresets.credentialScope so the scope shown on the config card
    /// is byte-identical to the scope the ModelGateway resolves (closes the
    /// A1_31 integration seam: UI saved under meta_ai_api_key while the
    /// gateway read deepseek-api).
    public static func deepSeekDefault() -> MetaAIConfig {
        MetaAIConfig(
            providerKind: .openaiCompatible,
            endpointURL: DeepSeekPresets.endpoint,
            credentialScope: DeepSeekPresets.credentialScope,
            displayName: "Meta AI (DeepSeek v4 Pro)"
        )
    }

    public init(
        providerKind: MetaAIProviderKind = .openaiCompatible,
        endpointURL: URL? = nil,
        credentialScope: String = MetaAIConfig.defaultCredentialScope,
        displayName: String = "Meta AI"
    ) {
        self.providerKind = providerKind
        self.endpointURL = endpointURL
        self.credentialScope = credentialScope
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case providerKind = "provider_kind"
        case endpointURL = "endpoint_url"
        case credentialScope = "credential_scope"
        case displayName = "display_name"
    }
}

// MARK: - Persistence

/// Simple UserDefaults-backed persistence for MetaAIConfig.
/// Follows the Workspace.swift idiom: encoder/decoder with sortedKeys.
public enum MetaAIConfigStore {
    private static let key = "turingos.meta_ai_config"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private static let decoder = JSONDecoder()

    /// Loads the saved config, or returns the user-ruled DeepSeek default
    /// (A1_32) if none exists. Previously-saved configs are untouched.
    public static func load() -> MetaAIConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? decoder.decode(MetaAIConfig.self, from: data) else {
            return MetaAIConfig.deepSeekDefault()
        }
        return config
    }

    /// Persists the config. Credential scope reference is stored; never the key.
    public static func save(_ config: MetaAIConfig) {
        guard let data = try? encoder.encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Removes the stored config (resets to defaults).
    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
