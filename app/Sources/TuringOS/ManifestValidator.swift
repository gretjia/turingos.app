// ManifestValidator.swift — Structural validator for CapabilityManifest (A1_21).
//
// BOUNDARY: pure validation library.  No lifecycle, no persistence, no network.
//
// Design principle: the required-field list is loaded from the real schema file at init
// so the validator has a single source of truth (no hardcoded duplicate list).
// If the schema file cannot be read, we fall back to the embedded constant — but we
// document this fallback loudly; the test suite verifies the live load path.

import Foundation

// MARK: - ValidationError

/// Structured error describing exactly which field failed and why.
public struct ValidationError: Sendable, Equatable, CustomStringConvertible {
    public let field:   String
    public let reason:  String

    public init(field: String, reason: String) {
        self.field  = field
        self.reason = reason
    }

    public var description: String { "\(field): \(reason)" }
}

// MARK: - ValidationResult

/// Result of `ManifestValidator.validate(_:)`.
public enum ValidationResult: Sendable {
    /// The manifest parsed and passed all structural checks.
    case valid(CapabilityManifest)
    /// One or more structural violations found.
    case invalid([ValidationError])
}

// MARK: - ManifestValidator

/// Validates raw JSON `Data` against capability_manifest.schema.json.
///
/// ## Checks performed (structural-subset, mirrors contracts validator):
///   1. JSON is parseable
///   2. Every field in the schema's `required` array is present in the raw JSON
///   3. `kind` is a member of the `CapabilityKind` enum
///   4. `vendor_tier` is a member of the `VendorTier` enum
///   5. `action_classes.default` is a member of the `ActionClass` enum
///   6. `schema_version` equals the const `"tos.app.capability_manifest.v0"`
///   7. `provenance.action_receipt` and `provenance.replay` are booleans
///
/// The required-field list is loaded from the schema file at initialisation.
/// If the schema file is unavailable, a hardcoded fallback list is used and
/// `requiredFieldsSource` reports `.fallback`.
public final class ManifestValidator: Sendable {

    // MARK: - Schema constant

    /// The canonical schema_version const.
    public static let schemaVersionConst = "tos.app.capability_manifest.v0"

    // MARK: - Required-field source

    public enum RequiredFieldsSource: Sendable, Equatable {
        /// Loaded live from the schema file at `schemaFileURL`.
        case schemaFile(URL)
        /// Could not load schema file; using embedded fallback.
        case fallback
    }

    // MARK: - Properties

    /// Where the required-fields list came from.
    public let requiredFieldsSource: RequiredFieldsSource

    /// The required-field names as parsed from the schema (or fallback).
    public let requiredFields: Set<String>

    // MARK: - Fallback constant (must stay in sync with schema manually)

    /// Fallback list exactly matching contracts/capability_manifest.schema.json "required".
    /// Exists ONLY as a build-time guard; the live path (schemaFile) is the authority.
    static let fallbackRequiredFields: Set<String> = [
        "schema_version",
        "id",
        "kind",
        "version",
        "vendor_tier",
        "action_classes",
        "permissions",
        "credential_scopes",
        "provenance",
        "evals",
        "audit_nodes",
    ]

    // MARK: - Init

    /// Designated initialiser.
    ///
    /// - Parameter schemaFileURL: URL of `contracts/capability_manifest.schema.json`.
    ///   If `nil`, uses the well-known repo-relative path resolved from the bundle or
    ///   the process working directory.
    public init(schemaFileURL: URL? = nil) {
        let url = schemaFileURL ?? ManifestValidator.resolveDefaultSchemaURL()
        if let u = url, let (fields, source) = ManifestValidator.loadRequiredFields(from: u, fileURL: u) {
            self.requiredFields       = fields
            self.requiredFieldsSource = source
        } else {
            self.requiredFields       = ManifestValidator.fallbackRequiredFields
            self.requiredFieldsSource = .fallback
        }
    }

    // MARK: - Schema URL resolution

    private static func resolveDefaultSchemaURL() -> URL? {
        // 1. Bundle resource (for test targets that copy it)
        if let bundleURL = Bundle.main.url(forResource: "capability_manifest", withExtension: "schema.json") {
            return bundleURL
        }
        // 2. Relative to the process working directory (developer / CI invocation)
        //    swift test is invoked from app/ — so two levels up then into contracts/
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates: [URL] = [
            cwd.appendingPathComponent("contracts/capability_manifest.schema.json"),
            cwd.appendingPathComponent("../contracts/capability_manifest.schema.json"),
            cwd.appendingPathComponent("../../contracts/capability_manifest.schema.json"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func loadRequiredFields(from url: URL, fileURL: URL) -> (Set<String>, RequiredFieldsSource)? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let required = json["required"] as? [String]
        else { return nil }
        return (Set(required), .schemaFile(fileURL))
    }

    // MARK: - Validate

    /// Validate raw JSON bytes representing a capability manifest.
    ///
    /// - Parameter jsonData: Raw UTF-8 JSON bytes.
    /// - Returns: `.valid(CapabilityManifest)` or `.invalid([ValidationError])`.
    public func validate(_ jsonData: Data) -> ValidationResult {
        var errors: [ValidationError] = []

        // --- Step 1: parseable JSON ---
        guard let rawJSON = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return .invalid([ValidationError(field: "$", reason: "not parseable JSON object")])
        }

        // --- Step 2: required fields present (single source of truth: requiredFields) ---
        for field in requiredFields.sorted() {
            if rawJSON[field] == nil {
                errors.append(ValidationError(field: field, reason: "required field missing"))
            }
        }

        // --- Step 3: enum membership — kind ---
        if let kindRaw = rawJSON["kind"] as? String {
            if CapabilityKind(rawValue: kindRaw) == nil {
                errors.append(ValidationError(
                    field: "kind",
                    reason: "unknown kind \"\(kindRaw)\"; must be one of: \(CapabilityKind.allCases.map(\.rawValue).joined(separator: ", "))"
                ))
            }
        }
        // (missing kind already caught by required-field check above)

        // --- Step 4: enum membership — vendor_tier ---
        if let tierRaw = rawJSON["vendor_tier"] as? String {
            if VendorTier(rawValue: tierRaw) == nil {
                errors.append(ValidationError(
                    field: "vendor_tier",
                    reason: "unknown vendor_tier \"\(tierRaw)\"; must be one of: verified, community, local"
                ))
            }
        }

        // --- Step 5: action_classes.default enum membership ---
        if let ac = rawJSON["action_classes"] as? [String: Any] {
            if let defaultRaw = ac["default"] as? String {
                if ActionClass(rawValue: defaultRaw) == nil {
                    errors.append(ValidationError(
                        field: "action_classes.default",
                        reason: "unknown action class \"\(defaultRaw)\"; must be one of: \(ActionClass.allCases.map(\.rawValue).joined(separator: ", "))"
                    ))
                }
            } else if ac["default"] == nil {
                errors.append(ValidationError(
                    field: "action_classes.default",
                    reason: "action_classes.default is required"
                ))
            }
        }
        // (missing action_classes already caught by required-field check)

        // --- Step 6: schema_version const ---
        if let sv = rawJSON["schema_version"] as? String {
            if sv != ManifestValidator.schemaVersionConst {
                errors.append(ValidationError(
                    field: "schema_version",
                    reason: "expected const \"\(ManifestValidator.schemaVersionConst)\", got \"\(sv)\""
                ))
            }
        }

        // --- Step 7: provenance booleans ---
        if let prov = rawJSON["provenance"] as? [String: Any] {
            if prov["action_receipt"] == nil {
                errors.append(ValidationError(field: "provenance.action_receipt", reason: "required boolean missing"))
            } else if !(prov["action_receipt"] is Bool) {
                errors.append(ValidationError(field: "provenance.action_receipt", reason: "must be a boolean"))
            }
            if prov["replay"] == nil {
                errors.append(ValidationError(field: "provenance.replay", reason: "required boolean missing"))
            } else if !(prov["replay"] is Bool) {
                errors.append(ValidationError(field: "provenance.replay", reason: "must be a boolean"))
            }
        }

        if !errors.isEmpty {
            return .invalid(errors)
        }

        // --- Step 8: full Codable decode (round-trip confirms well-formedness) ---
        let decoder = JSONDecoder()
        do {
            let manifest = try decoder.decode(CapabilityManifest.self, from: jsonData)
            return .valid(manifest)
        } catch {
            return .invalid([ValidationError(field: "$", reason: "JSON decoding failed: \(error)")])
        }
    }
}
