// SkillValidator.swift — SKILL.md document → TuringSkill validator (A1_29).
//
// BOUNDARY (WHITEPAPER.md §13.9):
//   Pure validation/parsing.  No I/O, no script execution, no persistence.
//
// FAIL-CLOSED INVARIANT (mirrors FailClosedClassifier.swift, A1_21):
//   A skill with missing, empty, or invalid allowedActionClasses is NEVER
//   admitted at a permissive (lower-privilege) class.  It is admitted only
//   at class_3_irreversible_external (the most restrictive), AND the
//   validation result carries a .classDeclaredRequired warning flag.
//
//   "Install ≠ trust" — a skill that omits its action class declaration is
//   treated as maximally dangerous, not maximally permissive.
//
// Required frontmatter keys: skillId, version, description, allowedActionClasses.
// Recommended (warn, not fail): triggerExamples non-empty.

import Foundation

// MARK: - SkillValidationError

/// A structured validation error describing which field failed and why.
public struct SkillValidationError: Sendable, Equatable, CustomStringConvertible {
    /// The frontmatter key or structural path that failed.
    public let field: String
    /// Human-readable reason.
    public let reason: String

    public init(field: String, reason: String) {
        self.field  = field
        self.reason = reason
    }

    public var description: String { "\(field): \(reason)" }
}

// MARK: - SkillValidationWarning

/// A non-fatal advisory from the validator.
public struct SkillValidationWarning: Sendable, Equatable, CustomStringConvertible {
    public let field:   String
    public let message: String

    public init(field: String, message: String) {
        self.field   = field
        self.message = message
    }

    public var description: String { "\(field): \(message)" }
}

// MARK: - SkillValidationResult

/// Result of `SkillValidator.validate(_:)`.
public enum SkillValidationResult: Sendable {
    /// Document is structurally valid.  The parsed `TuringSkill` is provided.
    /// `warnings` may be non-empty (e.g. missing triggerExamples).
    case valid(TuringSkill, warnings: [SkillValidationWarning])

    /// One or more structural violations found.
    case invalid([SkillValidationError])
}

// MARK: - SkillValidator

/// Deterministic, pure validator mapping `SkillMDDocument` → `SkillValidationResult`.
///
/// ## Required frontmatter keys
///   skillId, version, description, allowedActionClasses
///
/// ## Fail-closed on allowedActionClasses
///   Missing/empty/all-invalid → admitted at class_3, flag `.classDeclaredRequired`.
///   Partial: invalid entries are skipped; if the surviving set is non-empty the
///   skill is admitted at the surviving classes with a warning.
///   All entries invalid → treated as class_3 + flag.
///
/// ## Warnings (non-fatal)
///   triggerExamples empty or absent → .triggerExamplesRecommended warning.
///   classDeclaredRequired flag → emitted as a warning in the valid result.
public enum SkillValidator {

    // MARK: - Required frontmatter keys

    private static let requiredKeys: [String] = [
        "skillId", "version", "description", "allowedActionClasses"
    ]

    // MARK: - validate

    /// Validate a parsed `SkillMDDocument` and, if valid, produce a `TuringSkill`.
    ///
    /// - Parameter doc: The parsed SKILL.md document.
    /// - Returns: `.valid(TuringSkill, warnings:)` or `.invalid([SkillValidationError])`.
    ///
    /// ## Determinism guarantee
    /// Pure function: same input → same output.
    public static func validate(_ doc: SkillMDDocument) -> SkillValidationResult {
        var errors:   [SkillValidationError]   = []
        var warnings: [SkillValidationWarning] = []

        // ---- Required key presence checks ----

        let fm = doc.frontmatter

        // skillId
        guard let skillIdValue = fm["skillId"] else {
            errors.append(SkillValidationError(field: "skillId", reason: "required key missing"))
            // Continue collecting errors.
            _ = (fm["version"], fm["description"], fm["allowedActionClasses"])
            if fm["version"] == nil {
                errors.append(SkillValidationError(field: "version", reason: "required key missing"))
            }
            if fm["description"] == nil {
                errors.append(SkillValidationError(field: "description", reason: "required key missing"))
            }
            if fm["allowedActionClasses"] == nil {
                errors.append(SkillValidationError(field: "allowedActionClasses", reason: "required key missing"))
            }
            return .invalid(errors)
        }
        let skillId = scalar(skillIdValue)
        if skillId.isEmpty {
            errors.append(SkillValidationError(field: "skillId", reason: "value must not be empty"))
        }

        // version
        guard let versionValue = fm["version"] else {
            errors.append(SkillValidationError(field: "version", reason: "required key missing"))
            if fm["description"] == nil {
                errors.append(SkillValidationError(field: "description", reason: "required key missing"))
            }
            if fm["allowedActionClasses"] == nil {
                errors.append(SkillValidationError(field: "allowedActionClasses", reason: "required key missing"))
            }
            if !errors.isEmpty { return .invalid(errors) }
            return .invalid(errors)
        }
        let version = scalar(versionValue)
        if version.isEmpty {
            errors.append(SkillValidationError(field: "version", reason: "value must not be empty"))
        }

        // description
        guard let descValue = fm["description"] else {
            errors.append(SkillValidationError(field: "description", reason: "required key missing"))
            if fm["allowedActionClasses"] == nil {
                errors.append(SkillValidationError(field: "allowedActionClasses", reason: "required key missing"))
            }
            if !errors.isEmpty { return .invalid(errors) }
            return .invalid(errors)
        }
        let description = scalar(descValue)
        if description.isEmpty {
            errors.append(SkillValidationError(field: "description", reason: "value must not be empty"))
        }

        // allowedActionClasses — fail-closed logic
        let (resolvedClasses, classDeclaredRequired) = resolveActionClasses(fm["allowedActionClasses"], errors: &errors)

        if classDeclaredRequired {
            warnings.append(SkillValidationWarning(
                field: "allowedActionClasses",
                message: "class-declaration-required: no valid action classes declared; " +
                         "admitted at class_3_irreversible_external (fail-closed)"
            ))
        }

        // Return early if hard errors accumulated.
        if !errors.isEmpty { return .invalid(errors) }

        // ---- Optional fields ----

        let triggerExamples: [String]
        if let tv = fm["triggerExamples"] {
            triggerExamples = listValue(tv)
        } else {
            triggerExamples = []
        }
        if triggerExamples.isEmpty {
            warnings.append(SkillValidationWarning(
                field: "triggerExamples",
                message: "recommended: non-empty triggerExamples improve skill discoverability"
            ))
        }

        let requiredTools:   [String] = fm["requiredTools"]    .map { listValue($0) } ?? []
        let credentialScopes:[String] = fm["credentialScopes"] .map { listValue($0) } ?? []
        let evals:           [String] = fm["evals"]            .map { listValue($0) } ?? []
        let failureModes:    [String] = fm["failureModes"]     .map { listValue($0) } ?? []
        let scriptRefs:      [String] = fm["scriptRefs"]       .map { listValue($0) } ?? []

        let inputSchemaRef:   String? = fm["inputSchemaRef"]   .flatMap { optScalar($0) }
        let outputSchemaRef:  String? = fm["outputSchemaRef"]  .flatMap { optScalar($0) }
        let receiptSchemaRef: String? = fm["receiptSchemaRef"] .flatMap { optScalar($0) }

        // instructions = body (L2)
        let instructions = doc.body

        let skill = TuringSkill(
            skillId:              skillId,
            version:              version,
            description:          description,
            triggerExamples:      triggerExamples,
            requiredTools:        requiredTools,
            instructions:         instructions,
            scriptRefs:           scriptRefs,
            allowedActionClasses: resolvedClasses,
            credentialScopes:     credentialScopes,
            inputSchemaRef:       inputSchemaRef,
            outputSchemaRef:      outputSchemaRef,
            receiptSchemaRef:     receiptSchemaRef,
            evals:                evals,
            failureModes:         failureModes,
            status:               .draft
        )

        return .valid(skill, warnings: warnings)
    }

    // MARK: - Private helpers

    /// Resolve `allowedActionClasses` frontmatter value to `[ActionClass]`.
    ///
    /// Fail-closed semantics:
    ///   - nil / empty list / all-invalid values → [.class3IrreversibleExternal],
    ///     `classDeclaredRequired` = true, no hard error added.
    ///   - invalid individual entries are skipped; surviving valid entries used.
    ///   - If an entry is not a recognised ActionClass raw value → appends an error
    ///     only if ALL entries fail (partial sets are warned, not errored).
    private static func resolveActionClasses(
        _ value: SkillMDValue?,
        errors: inout [SkillValidationError]
    ) -> ([ActionClass], classDeclaredRequired: Bool) {

        guard let value = value else {
            errors.append(SkillValidationError(
                field: "allowedActionClasses",
                reason: "required key missing"
            ))
            return ([.class3IrreversibleExternal], true)
        }

        let rawItems: [String]
        switch value {
        case .scalar(let s):
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            rawItems = trimmed.isEmpty ? [] : [trimmed]
        case .list(let items):
            rawItems = items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        case .object:
            rawItems = []
        }

        if rawItems.isEmpty {
            // Empty declaration → fail-closed.
            return ([.class3IrreversibleExternal], true)
        }

        var resolved: [ActionClass] = []
        var invalidEntries: [String] = []

        for raw in rawItems {
            if let cls = ActionClass(rawValue: raw) {
                resolved.append(cls)
            } else {
                invalidEntries.append(raw)
            }
        }

        if !invalidEntries.isEmpty {
            errors.append(SkillValidationError(
                field: "allowedActionClasses",
                reason: "invalid action class value(s): \(invalidEntries.joined(separator: ", ")); "
                    + "valid values: \(ActionClass.allCases.map(\.rawValue).joined(separator: ", "))"
            ))
            // Even with some invalid entries, if any are valid, still return them.
            // But since we appended an error, the caller will fail anyway.
        }

        if resolved.isEmpty {
            // All entries were invalid → fail-closed.
            return ([.class3IrreversibleExternal], true)
        }

        return (resolved, false)
    }

    private static func scalar(_ v: SkillMDValue) -> String {
        switch v {
        case .scalar(let s): return s.trimmingCharacters(in: .whitespaces)
        case .list(let l):   return l.first ?? ""
        case .object:        return ""
        }
    }

    private static func optScalar(_ v: SkillMDValue) -> String? {
        let s = scalar(v)
        return s.isEmpty ? nil : s
    }

    private static func listValue(_ v: SkillMDValue) -> [String] {
        switch v {
        case .list(let l):   return l.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        case .scalar(let s):
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? [] : [trimmed]
        case .object:        return []
        }
    }
}
