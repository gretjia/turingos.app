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
        let base = routeBase(lower: lower, rawInput: input, catalog: catalog, ledger: ledger, radarScene: radarScene)
        if runtimeKind == .degraded {
            return prefixWithDegradedNotice(base)
        }
        return base
    }

    private static func routeBase(
        lower: String,
        rawInput: String,
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

        // Project picker intent (generic: no specific project matched above).
        // A1_34: 连接/connect joins this deterministic branch — the menu's
        // .connectRepo submits "连接仓库", which must never fall through to
        // the model (zero-call verifier finding).
        if lower.contains("项目") || lower.contains("project")
            || lower.contains("连接") || lower.contains("connect") {
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
        // Canvas projection intent (A1_26)
        if let canvasDoc = routeCanvas(lower: lower, rawInput: rawInput) {
            return canvasDoc
        }
        // CI observation intent (A1_20 projection, wired A1_34 — was a dead
        // TODO until the zero-call verifier caught menu ⌘R falling through to
        // the model). Reducer purity: no live observation source here (running
        // git/gh inside the reducer would be IO); nil source yields the
        // deterministic CIUnavailableNotice card. Live async wiring is a
        // future atom; deterministic-and-honest beats silent-model-call.
        if let ciDoc = routeCIIntent(
            lower: lower, observationSource: nil, projectContext: nil
        ) {
            return ciDoc
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

    /// A1_35 (c): deterministic demo ApprovalEnvelopeDraft → approval_request
    /// block (rendered ONLY by the first-party ApprovalCard, 渲染铁律 §3.3).
    ///
    /// All entropy is FIXED (nonce/expiry/hashes injected as constants — the
    /// A1_23 builder never calls Date()/UUID()), so the document is byte-
    /// identical across calls. Draft only: zero signing ceremony, zero model.
    public static func approvalDraftDemo() -> ViewIRDocument {
        let content = ApprovalCardContent(
            actor: "meta_ai_demo",
            actionKind: "create_worktree",
            actionClass: 1,
            target: "demo://worktree/feature_demo",
            paramsSummary: "branch=feature_demo base=main",
            riskCategory: "low",
            reversibility: "reversible",
            consequenceStatement: "在本地创建一个可回滚的 worktree（演示，不执行）。",
            humanReadableSummary: "演示审批草案：为 proj_default 创建 feature_demo worktree。"
        )
        let result = ApprovalEnvelopeBuilder.build(
            content: content,
            signatureNode: 2,
            projectId: "proj_default",
            specHash: "sha256:deadbeef",
            budgetHash: "sha256:deadbeef",
            policyHash: "sha256:deadbeef",
            payloadHash: "sha256:deadbeef",
            targetResourceHash: "sha256:deadbeef",
            prevTapeHead: "sha256:00000000",
            nonce: "demo-nonce",
            expiryUtc: "2027-01-01T00:00:00Z",
            hostThreatLevel: .t0
        )
        switch result {
        case .success(let draft):
            return ViewIRDocument(
                kind: "approval_draft_demo",
                deriveSource: ["approval_draft:demo"],
                blocks: [
                    .summaryCard(SummaryCardPayload(
                        title: "审批草案（演示）",
                        body: "信封 \(draft.envelopeId) 已构造（draft，未签名）。\n"
                            + "visible_card_hash 已绑定渲染内容（红线 2）。"
                    )),
                    .approvalRequest(ApprovalRequestPayload(envelopeRef: draft.envelopeId)),
                ]
            )
        case .failure:
            // Structurally unreachable with the fixed inputs above (T0, node
            // 2, class 1) — kept fail-visible rather than force-unwrapped.
            return ViewIRDocument(
                kind: "approval_draft_demo",
                deriveSource: ["approval_draft:demo"],
                blocks: [.summaryCard(SummaryCardPayload(
                    title: "审批草案（演示）",
                    body: "构造被拒绝（builder fail-closed）。"
                ))]
            )
        }
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

    /// A1_34: in-flight Facilitator dialogue task (nil when nothing pending).
    /// Exposed read-only so tests can await the async reply deterministically.
    public private(set) var dialogueTask: Task<Void, Never>?

    /// A1_35: in-flight Meta drafting task (nil when nothing pending).
    /// Exposed read-only so tests can await the async proposal deterministically.
    public private(set) var metaTask: Task<Void, Never>?

    /// A1_36: in-flight CI observation task (nil when nothing pending).
    /// Exposed read-only so tests can await the async replacement deterministically.
    public private(set) var ciTask: Task<Void, Never>?

    private let probe: any FacilitatorRuntimeProbe
    /// A1_34: optional live Facilitator dialogue service. nil = escape-hatch
    /// only (all pre-A1_34 behavior unchanged — every existing test sees nil).
    /// Production wiring injects FacilitatorDialogue.production() ONLY at the
    /// app entry path (TuringOSApp → OrbView).
    private let dialogue: FacilitatorDialogue?
    /// A1_35: optional live Meta drafting service. nil = deterministic
    /// "Meta 未接线" card only (tests see nil unless they inject a mock).
    /// Production wiring injects MetaDrafting.production() ONLY at the app
    /// entry path (TuringOSApp → OrbView).
    private let metaDrafting: MetaDrafting?
    /// A1_36: optional CI observation source factory. nil = deterministic
    /// CIUnavailableNotice (pre-A1_36 behavior). Production closure resolves
    /// the first local catalog project to a LiveRepoObservationSource (read-
    /// only git/gh commands per A1_20's no-write predicate) — injected ONLY
    /// at the app entry path. The CI path NEVER touches the model gateway.
    private let ciObservationProvider: (@Sendable () -> (any RepoObservationSource)?)?

    public init(
        probe: any FacilitatorRuntimeProbe = SystemFacilitatorProbe(),
        dialogue: FacilitatorDialogue? = nil,
        metaDrafting: MetaDrafting? = nil,
        ciObservationProvider: (@Sendable () -> (any RepoObservationSource)?)? = nil
    ) {
        self.probe = probe
        self.dialogue = dialogue
        self.metaDrafting = metaDrafting
        self.ciObservationProvider = ciObservationProvider
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
        let intentLower = text.lowercased()

        // A1_35 (a): Meta drafting intent — checked BEFORE the wizard answer
        // feed so a drafting ask is never consumed as a step answer, and
        // BEFORE generic routing so it never reaches the Facilitator lane.
        if intentLower.contains("起草") || intentLower.contains("draft")
            || intentLower.contains("帮我写") {
            handleMetaDraftIntent(text)
            return
        }

        // A1_35 (b): budget intent → A1_19 projection, deterministic, ZERO
        // model. Active wizard supplies the projectId; spec hash is the
        // draft placeholder (no sealed spec exists on this path yet).
        if intentLower.contains("预算") || intentLower.contains("budget") {
            let projectId = wizardSession?.projectId ?? "proj_default"
            let contract = BudgetContract(
                projectId: projectId,
                limits: BudgetLimits(tokenLimit: 100_000, wallClockSecs: 86_400)
            )
            currentProjection = BudgetProjections.budgetDraftCard(
                for: contract, specHash: "sha256:draft"
            )
            return
        }

        // A1_35 (c): approval intent → A1_23 builder demo draft rendered via
        // the first-party ApprovalCard (渲染铁律). Fixed injected nonce/expiry
        // → deterministic, ZERO model, zero signing ceremony (draft only).
        if intentLower.contains("批准") || intentLower.contains("approval")
            || intentLower.contains("审批") {
            currentProjection = TemplateProjections.approvalDraftDemo()
            return
        }

        // A1_36: CI observation intent — live read-only git/gh observation
        // (A1_20 source, first UI wiring). Deterministic placeholder shows
        // IMMEDIATELY; the blocking command run happens in a detached task
        // (never on the MainActor); the projection is replaced on arrival.
        // ZERO model calls on this path. With no provider injected, the
        // deterministic CIUnavailableNotice preserves pre-A1_36 behavior.
        if intentLower.contains("ci") || intentLower.contains("检查")
            || intentLower.contains("check") {
            guard let provider = ciObservationProvider else {
                currentProjection = CIUnavailableNotice.make()
                return
            }
            currentProjection = TemplateProjections.ciCheckingNotice()
            ciTask?.cancel()
            ciTask = Task { [weak self] in
                let doc = await Task.detached(priority: .userInitiated) {
                    IntentRouter.routeCIIntent(
                        lower: intentLower,
                        observationSource: provider(),
                        projectContext: nil
                    ) ?? CIUnavailableNotice.make()
                }.value
                guard !Task.isCancelled else { return }
                self?.currentProjection = doc
            }
            return
        }

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

        // Default: standard intent routing — synchronous, deterministic,
        // shown IMMEDIATELY (rules first, §5.6; reducer/router stay pure).
        let routed = IntentRouter.route(input: text, runtimeKind: runtimeKind)
        currentProjection = routed

        // A1_34: unknown intent landed on the escape hatch → if a live
        // dialogue service is available AND the runtime probe is not
        // degraded, fire the async Facilitator reply and replace the
        // projection when it arrives. The async task lives HERE in the
        // view-model layer ONLY. Deterministic route hits never reach this
        // branch (predicate 1: zero gateway invocations).
        guard let dialogue,
              runtimeKind != .degraded,
              routed == IntentRouter.intentSuggestionsDoc() else { return }
        dialogueTask?.cancel()
        dialogueTask = Task { [weak self] in
            let doc = await dialogue.respond(to: text)
            guard !Task.isCancelled else { return }
            self?.currentProjection = doc
        }
    }

    // MARK: - Meta drafting intent (A1_35)

    /// Drafting ask (起草/draft/帮我写). Deterministic exits first; the model
    /// is reached ONLY with an active wizard session + an injected service.
    ///
    /// RED LINE 4: the session is handed to MetaDrafting BY VALUE — the
    /// proposal NEVER writes back into `wizardSession`. The user reads the
    /// suggestion and answers the wizard steps themselves.
    private func handleMetaDraftIntent(_ text: String) {
        // No active draft → deterministic notice, zero gateway.
        guard let session = wizardSession else {
            currentProjection = MetaDrafting.requiresWizardDocument()
            return
        }
        // Service not wired (default nil — tests, previews) → deterministic
        // unavailable card, zero gateway. Fail-visible, never a stuck spinner.
        guard let metaDrafting else {
            currentProjection = MetaDrafting.unavailableDocument(
                reason: "Meta 服务未接线（仅生产入口注入）"
            )
            return
        }
        // Deterministic placeholder shown IMMEDIATELY; the async proposal
        // replaces it on arrival (mirrors the A1_34 dialogueTask pattern).
        currentProjection = MetaDrafting.draftingInProgressDocument()
        metaTask?.cancel()
        metaTask = Task { [weak self] in
            let doc = await metaDrafting.draft(for: session, userAsk: text)
            guard !Task.isCancelled else { return }
            self?.currentProjection = doc
        }
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
