// SkillProjection.swift — TuringSkill → ViewIR projection (A1_29).
//
// BOUNDARY:
//   Uses ONLY existing ViewIR block types (ViewIR.swift UNCHANGED).
//   No new block types are introduced.
//   derive_source cites skillId + "skill_model:v1" (tape discipline,
//   docs/02_SOFTWARE_3_UI_PRD.md §1.3 / §8 predicate P1).
//
// Projection: two blocks
//   1. spec_draft  — surfaces the skill as a draft spec card (skillId as specRef,
//      key sections listed).
//   2. summary_card — skill description + action class summary.
//
// ViewIR.swift is UNCHANGED — only existing block payload types are used.

import Foundation

// MARK: - SkillProjection

/// Projects a `TuringSkill` to a `ViewIRDocument` using existing block types.
///
/// ## derive_source (tape discipline)
/// Every document produced by this projector includes a `deriveSource` that
/// cites the `skillId` and the string `"skill_model:v1"` so the document is
/// traceable to its origin without a running tape.
public enum SkillProjection {

    // MARK: - project

    /// Project a `TuringSkill` into a `ViewIRDocument`.
    ///
    /// Blocks produced (in order):
    ///   1. `spec_draft` — skill identity card (specRef = skillId, sections = key law-shell fields).
    ///   2. `summary_card` — description + action class summary.
    ///
    /// - Parameter skill: The skill to project.
    /// - Returns: A `ViewIRDocument` with two blocks.
    public static func project(_ skill: TuringSkill) -> ViewIRDocument {
        let deriveSource = [skill.skillId, "skill_model:v1"]

        // Block 1: spec_draft — the skill as a structured draft card.
        // specRef = skillId; sections represent key law-shell fields for human review.
        let sections: [SpecSection] = [
            SpecSection(ref: "description",          title: "Description"),
            SpecSection(ref: "allowed_action_classes", title: "Allowed Action Classes"),
            SpecSection(ref: "credential_scopes",    title: "Credential Scopes"),
            SpecSection(ref: "trigger_examples",     title: "Trigger Examples"),
            SpecSection(ref: "failure_modes",        title: "Failure Modes"),
            SpecSection(ref: "evals",                title: "Evals"),
        ]
        let specDraftBlock = ViewIRBlock.specDraft(
            SpecDraftPayload(
                specRef: skill.skillId,
                sections: sections,
                signatureNode: 7  // node 7 = "Approve tool/predicate/policy upgrade" (§9)
            )
        )

        // Block 2: summary_card — human-readable skill summary.
        let actionClassSummary = skill.allowedActionClasses
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
        let body = """
        version: \(skill.version)
        action_classes: \(actionClassSummary)
        status: \(skill.status.rawValue)
        hash: \(skill.skillHash)
        """
        let summaryBlock = ViewIRBlock.summaryCard(
            SummaryCardPayload(
                title: skill.description,
                body:  body,
                tapeRef: nil  // no tape yet (draft domain)
            )
        )

        return ViewIRDocument(
            kind:         "skill_card",
            deriveSource: deriveSource,
            blocks:       [specDraftBlock, summaryBlock]
        )
    }
}
