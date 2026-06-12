// OrbState.swift — Orb state machine for A1_16.
//
// Design: state machine logic lives in a plain struct reducer (OrbReducer)
// so it can be unit-tested without SwiftUI. The ObservableObject wrapper
// (OrbViewModel) drives the view.
//
// States match docs/02_SOFTWARE_3_UI_PRD.md §2.2 exactly:
//   idle → listening → thinking → needsRuling → (thinking → degraded)
//   Any state can also transition to degraded on FacilitatorRuntimeKind.degraded.

import Foundation
import SwiftUI

// MARK: - State enum

/// The five states of the Orb state machine (docs/02 §2.2).
public enum OrbStateValue: Equatable, Sendable, CaseIterable {
    /// No pending tasks. Orb breathes quietly (安静即成功).
    case idle
    /// User activated text or voice input.
    case listening
    /// Facilitator or Meta AI is processing / Worker executing.
    case thinking
    /// Pending ApprovalEnvelope / stop-loss report / failure cert needs ruling.
    case needsRuling
    /// Facilitator AI unavailable or kernel exception.
    case degraded
}

// MARK: - Events

/// Events that drive state transitions.
public enum OrbEvent: Equatable, Sendable {
    /// User submitted input (text or voice transcript).
    case inputSubmitted(text: String)
    /// Facilitator received the intent; handoff to processing.
    case facilitatorReceived
    /// Orb runtime kind resolved (drives degraded check on startup).
    case runtimeResolved(FacilitatorRuntimeKind)
    /// An ApprovalEnvelope or ruling request arrived.
    case rulingRequested
    /// User completed ruling (approved / rejected / dismissed).
    case rulingCompleted
    /// Task finished successfully — back to idle.
    case taskCompleted
    /// Kernel or model failure detected.
    case faultDetected(reason: String)
    /// Explicit reset to idle.
    case resetIdle
}

// MARK: - Pure reducer

/// Pure state machine reducer. Unit-testable without any SwiftUI dependency.
public struct OrbReducer: Sendable {
    private init() {}

    /// Transition function. Returns the new state given current state + event.
    /// All transitions are deterministic and exhaustive.
    public static func reduce(state: OrbStateValue, event: OrbEvent) -> OrbStateValue {
        switch (state, event) {

        // --- idle transitions ---
        case (.idle, .inputSubmitted):
            return .listening
        case (.idle, .runtimeResolved(let kind)) where kind == .degraded:
            return .degraded
        case (.idle, .rulingRequested):
            return .needsRuling

        // --- listening transitions ---
        case (.listening, .facilitatorReceived):
            return .thinking
        case (.listening, .faultDetected):
            return .degraded
        case (.listening, .runtimeResolved(let kind)) where kind == .degraded:
            return .degraded

        // --- thinking transitions ---
        case (.thinking, .taskCompleted):
            return .idle
        case (.thinking, .rulingRequested):
            return .needsRuling
        case (.thinking, .faultDetected):
            return .degraded
        case (.thinking, .runtimeResolved(let kind)) where kind == .degraded:
            return .degraded

        // --- needsRuling transitions ---
        case (.needsRuling, .rulingCompleted):
            return .thinking
        case (.needsRuling, .faultDetected):
            return .degraded
        case (.needsRuling, .resetIdle):
            return .idle

        // --- degraded transitions ---
        case (.degraded, .resetIdle):
            return .idle
        case (.degraded, .runtimeResolved(let kind)) where kind != .degraded:
            return .idle

        // --- any state: fault always degrades ---
        case (_, .faultDetected):
            return .degraded

        // --- any state: runtime degraded forced entry ---
        case (_, .runtimeResolved(let kind)) where kind == .degraded:
            return .degraded

        // --- any state: explicit reset ---
        case (_, .resetIdle):
            return .idle

        // --- no-op / identity ---
        default:
            return state
        }
    }
}

// MARK: - IntentRouter

/// Deterministic intent router: maps user text to template projections.
/// NO model calls. Same input always produces byte-identical output (pure function).
/// Implements discoverability escape hatch per docs/02 §4.
///
/// A1_17: catalog and ledger/scene state are injected via protocols so tests
/// can supply mock data without hitting disk or the network.
public enum IntentRouter {
    /// Route input text to a deterministic ViewIRDocument.
    /// If `runtimeKind == .degraded`, the result is prefixed with a degradedNotice.
    /// `catalog` supplies the project list; `ledger`+`radarScene` supply project state.
    public static func route(
        input: String,
        runtimeKind: FacilitatorRuntimeKind,
        catalog: any CatalogSource = SystemCatalogSource(),
        ledger: WorktreeLedger = WorktreeLedger(),
        radarScene: RadarScene = RadarScene.derive(ledger: WorktreeLedger())
    ) -> ViewIRDocument {
        let lower = input.lowercased()
        let base = routeBase(lower: lower, catalog: catalog, ledger: ledger, radarScene: radarScene)
        if runtimeKind == .degraded {
            return prefixWithDegradedNotice(base)
        }
        return base
    }

    private static func routeBase(
        lower: String,
        catalog: any CatalogSource,
        ledger: WorktreeLedger,
        radarScene: RadarScene
    ) -> ViewIRDocument {
        // Project state: check whether the input matches a known project name
        // (by display name) before the generic picker intent — more specific first.
        let catalogItems = catalog.items()
        if let matched = catalogItems.first(where: {
            lower == $0.displayName.lowercased()
                || lower == URL(fileURLWithPath: $0.localPath ?? "").lastPathComponent.lowercased()
        }) {
            // Derive the project_id the same way RepoCatalog/ProjectProjections do.
            let projectId = matched.id
            // Display name is the catalog display name; fall back to last path component.
            let displayName = matched.displayName
            return ProjectProjections.projectState(
                projectId: projectId,
                displayName: displayName,
                ledger: ledger,
                radarScene: radarScene,
                deriveSource: catalog.deriveSourceTag
            )
        }

        // Project picker intent (generic: no specific project matched above)
        if lower.contains("项目") || lower.contains("project") {
            return ProjectProjections.projectPicker(from: catalog)
        }
        // Morning ritual intent
        if lower.contains("早") || lower.contains("morning") {
            return TemplateProjections.morningRitual(
                date: isoToday(),
                tapeRange: "seq:0-0",
                done: 0, staged: 0, needsApproval: 0, blocked: 0, failed: 0
            )
        }
        // Config / settings intent
        if lower.contains("设置") || lower.contains("setup") || lower.contains("meta") {
            return TemplateProjections.metaAIConfigCard(config: MetaAIConfigStore.load())
        }
        // Portfolio radar / stump tree intent (A1_24)
        if let portfolioDoc = routePortfolio(lower: lower) {
            return portfolioDoc
        }
        // Unknown → intent suggestions (discoverability escape hatch §4)
        return intentSuggestionsDoc()
    }

    /// Prepend a degraded notice block to an existing document.
    static func prefixWithDegradedNotice(_ doc: ViewIRDocument) -> ViewIRDocument {
        let notice = TemplateProjections.degradedNotice(reason: "Facilitator AI 不可用")
        let combined = notice.blocks + doc.blocks
        return ViewIRDocument(
            kind: doc.kind,
            deriveSource: (notice.deriveSource + doc.deriveSource).removingDuplicates(),
            blocks: combined
        )
    }

    private static func isoToday() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: Date())
    }

    static func intentSuggestionsDoc() -> ViewIRDocument {
        let suggestions = [
            IntentSuggestion(label: "查看项目列表",   intentText: "项目",   contextTag: "nav"),
            IntentSuggestion(label: "今日早晨仪式",   intentText: "早",     contextTag: "morning"),
            IntentSuggestion(label: "配置 Meta AI",   intentText: "meta 设置", contextTag: "config"),
        ]
        return ViewIRDocument(
            kind: "general",
            deriveSource: ["fixture_event_stream:intent_router"],
            blocks: [.intentSuggestions(IntentSuggestionsPayload(suggestions: suggestions))]
        )
    }
}

// MARK: - TemplateProjections extension for metaAIConfigCard

extension TemplateProjections {
    /// Deterministic factory: produces a summary_card + credential_field
    /// describing the current Meta AI config. No secrets — only the scope
    /// descriptor and display metadata appear in the View IR (§7.1 law).
    public static func metaAIConfigCard(config: MetaAIConfig) -> ViewIRDocument {
        let summary = SummaryCardPayload(
            title: "Meta AI 配置",
            body: """
            供应商：\(config.displayName)
            协议：\(config.providerKind.rawValue)
            端点：\(config.endpointURL?.absoluteString ?? "（默认）")
            凭证域：\(config.credentialScope)
            """
        )
        let cred = CredentialFieldPayload(
            fieldId: "meta_ai_api_key_input",
            label: "Meta AI API Key",
            credentialScope: config.credentialScope
        )
        return ViewIRDocument(
            kind: "general",
            deriveSource: ["fixture_event_stream:meta_ai_config"],
            blocks: [.summaryCard(summary), .credentialField(cred)]
        )
    }
}

// MARK: - OrbViewModel (ObservableObject wrapper)

/// SwiftUI-observable wrapper around OrbReducer.
/// The view layer must only mutate state through `send(_:)`.
///
/// Wizard integration (A1_18):
/// When a "立项"/"init" intent is detected, the Orb enters wizard mode.  Each
/// subsequent inputSubmitted feeds an answer into the WizardSession reducer.
/// The wizard step is projected as a spec_draft IR block via
/// ProjectProjections.specDraftCard.  On finish, the draft is saved via
/// SpecDraftStore and a summary_card confirms the specHash + "awaiting kernel
/// ceremony" status.
@MainActor
public final class OrbViewModel: ObservableObject {
    @Published public private(set) var state: OrbStateValue = .idle
    @Published public private(set) var currentProjection: ViewIRDocument?
    @Published public private(set) var inputText: String = ""
    @Published public private(set) var runtimeKind: FacilitatorRuntimeKind = .degraded

    /// Active wizard session (nil when not in wizard mode).
    @Published public private(set) var wizardSession: WizardSession?

    private let probe: any FacilitatorRuntimeProbe

    public init(probe: any FacilitatorRuntimeProbe = SystemFacilitatorProbe()) {
        self.probe = probe
    }

    /// Resolve runtime kind and transition accordingly.
    public func resolveRuntime() {
        let kind = probe.detect()
        runtimeKind = kind
        send(.runtimeResolved(kind))
    }

    public func send(_ event: OrbEvent) {
        state = OrbReducer.reduce(state: state, event: event)
        // Side effects on state change
        if case .inputSubmitted(let text) = event {
            inputText = text
            handleInput(text)
            send(.facilitatorReceived)
            send(.taskCompleted)
        }
    }

    // MARK: - Input dispatch (wizard-aware)

    private func handleInput(_ text: String) {
        // If a wizard session is active, feed the text as a wizard answer.
        if var session = wizardSession {
            session = SpecDraftReducer.reduce(session: session, event: .submitAnswer(text))
            wizardSession = session

            if session.finished {
                // Build and save the draft.
                if let pkg = SpecDraftReducer.buildPackage(from: session) {
                    let savedHash = (try? SpecDraftStore.save(pkg)) != nil ? pkg.specHash : "(save failed)"
                    currentProjection = ProjectProjections.specDraftSummaryCard(
                        specHash: savedHash,
                        projectId: pkg.projectId
                    )
                } else {
                    currentProjection = IntentRouter.intentSuggestionsDoc()
                }
                wizardSession = nil
            } else {
                // Project the current wizard step.
                currentProjection = ProjectProjections.specDraftCard(from: session)
            }
            return
        }

        // Check for "立项" / "init" intent → start wizard.
        let lower = text.lowercased()
        if lower.contains("立项") || lower.hasPrefix("init ") || lower == "init" {
            // Extract a project ID hint from the input (fallback to UUID prefix).
            let projectId = extractProjectId(from: text) ?? "proj_\(UUID().uuidString.prefix(8).lowercased())"
            let session = WizardSession(projectId: projectId)
            wizardSession = session
            currentProjection = ProjectProjections.specDraftCard(from: session)
            return
        }

        // Default: standard intent routing.
        currentProjection = IntentRouter.route(input: text, runtimeKind: runtimeKind)
    }

    private func extractProjectId(from text: String) -> String? {
        // "立项 my_project" or "init my_project" → "my_project"
        let parts = text.split(separator: " ", maxSplits: 1)
        if parts.count == 2 {
            let candidate = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if !candidate.isEmpty {
                return candidate
                    .lowercased()
                    .replacingOccurrences(of: "[^a-z0-9_]", with: "_", options: .regularExpression)
            }
        }
        return nil
    }
}

// MARK: - Array dedup helper

private extension Array where Element: Equatable {
    func removingDuplicates() -> [Element] {
        var seen = [Element]()
        for e in self where !seen.contains(e) { seen.append(e) }
        return seen
    }
}
