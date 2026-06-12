// MetaDrafting.swift — A1_35: live Meta AI drafting service (proposal only).
//
// Constitutional anchors:
//   - WHITEPAPER.md §5.2 — Meta AI drafting duty (lawful-now subset): the
//     strongest lane drafts SUGGESTIONS from the user's answered wizard
//     context. A model call is a SHELL OBSERVATION RECORD; zero Q advancement.
//   - docs/02_SOFTWARE_3_UI_PRD.md §3.1 red line 1 — model output enters View
//     IR blocks ONLY. The response text lands in a summary_card BODY STRING;
//     it is never interpreted, never rendered as markup or script.
//   - A1_35 RED LINE 4 — Meta output = PROPOSAL ONLY. `draft(for:userAsk:)`
//     takes the WizardSession BY VALUE and never writes wizard/spec state.
//     The user reads the proposal and answers the wizard steps themselves.
//   - docs/01_KERNEL_CONTRACTS.md I8/I9 — gateway handles tape + credentials;
//     this service holds neither secrets nor tape handles.
//
// FAIL-VISIBLE: any GatewayError maps to a DETERMINISTIC fallback document
// (fixed Chinese reason strings — no secrets, no scope values, no provider
// error text). Never fail-silent.
//
// BOUNDARY: async orchestration only — no SwiftUI, no Keychain reads, no
// network primitives. The injected ModelGateway owns all I/O.

import Foundation

// MARK: - MetaDrafting

/// Async Meta drafting service: answered wizard context + user ask in,
/// ViewIRDocument PROPOSAL out.
///
/// Injection seam: tests build this on a ModelGateway with MockTransport +
/// in-memory sink (zero network, zero disk tape). Production assembly is
/// `MetaDrafting.production()` — constructed ONLY at the app entry path
/// (TuringOSApp → OrbView), never in tests.
public struct MetaDrafting: Sendable {

    private let gateway: ModelGateway
    /// Keychain scope descriptor the gateway resolves (I9: descriptor only,
    /// never the key value). Injectable so tests never touch the real
    /// "deepseek-api" Keychain item.
    private let credentialScope: String

    /// Chinese Meta system prompt (§5.2 drafting lane — proposal only).
    static let systemPrompt =
        "你是 TuringOS 的 Meta AI。基于用户已填写的立项草案上下文，起草剩余字段的具体建议。输出纯文本建议，用户自行采纳。不要输出 HTML 或代码。"

    public init(gateway: ModelGateway, credentialScope: String = DeepSeekPresets.credentialScope) {
        self.gateway = gateway
        self.credentialScope = credentialScope
    }

    // MARK: - Production assembly

    /// Production wiring (A1_35, mirrors FacilitatorDialogue.production):
    /// FileTapeSink.defaultSink() (I8: every call enters the shell tape
    /// JSONL) + LiveURLSessionTransport + the DeepSeek meta preset
    /// (deepseek-v4-pro, thinking enabled — user ruling 2026-06-12).
    /// Returns nil when no meta preset exists.
    public static func production() -> MetaDrafting? {
        guard DeepSeekPresets.config(for: .meta) != nil else { return nil }
        let gateway = ModelGateway(
            tapeSink: FileTapeSink.defaultSink(),
            transport: LiveURLSessionTransport(),
            keychainStore: .shared,
            projectId: "proj_orb_shell"
        )
        return MetaDrafting(gateway: gateway)
    }

    // MARK: - Draft

    /// Send the answered wizard context + `userAsk` to the Meta model and
    /// project the drafting PROPOSAL.
    ///
    /// RED LINE 4: `session` is taken BY VALUE and is never mutated — this
    /// function writes NOTHING back into wizard/spec state. The returned
    /// document is a proposal the user reads and adopts manually.
    ///
    /// SUCCESS → kind "meta_draft_proposal": the model text goes ONLY into
    /// the summary_card body string (red line 1).
    /// FAILURE → deterministic "meta_unavailable" fallback document
    /// (fixed reason string).
    public func draft(for session: WizardSession, userAsk: String) async -> ViewIRDocument {
        // ONE source of truth: model + thinking mode + endpoint from the preset.
        guard let preset = DeepSeekPresets.config(for: .meta) else {
            return Self.unavailableDocument(reason: "Meta 预设缺失")
        }

        let request = GatewayRequest(
            role: .meta,
            messages: [
                GatewayMessage(role: .system, content: Self.systemPrompt),
                GatewayMessage(role: .user, content: Self.userMessage(session: session, userAsk: userAsk))
            ],
            maxTokens: 4096,  // thinking consumes budget; multi-field Chinese drafting needs headroom (verifier finding)
            thinkingMode: preset.thinking
        )
        let config = MetaAIConfig(
            providerKind: .openaiCompatible,
            endpointURL: preset.endpoint,
            credentialScope: credentialScope,
            displayName: "Meta AI (DeepSeek v4 Pro)"
        )

        do {
            let response = try await gateway.send(request, config: config, model: preset.model)
            // RED LINE 1: response.content is a STRING in the card body —
            // never interpreted, never rendered as markup.
            return ViewIRDocument(
                kind: "meta_draft_proposal",
                deriveSource: [
                    "user_input",
                    "wizard:\(session.projectId)",
                    "model_call:meta:\(preset.model)",
                ],
                blocks: [.summaryCard(SummaryCardPayload(
                    title: "Meta AI 起草建议（提案，未写入）",
                    body: response.finishReason == "length"
                        ? response.content + "\n\n（注：回复因长度上限被截断）"
                        : response.content
                ))]
            )
        } catch let error as GatewayError {
            return Self.unavailableDocument(reason: Self.fallbackReason(for: error))
        } catch {
            return Self.unavailableDocument(reason: "未知网关错误")
        }
    }

    // MARK: - Context serialization

    /// Serialize the answered wizard steps as drafting context: one
    /// "step prompt：answer" line per answered step, in canonical step order
    /// (SpecDraftReducer.steps), followed by the user's ask. Deterministic —
    /// dictionary iteration order never leaks (steps array drives order).
    static func userMessage(session: WizardSession, userAsk: String) -> String {
        let answered = SpecDraftReducer.steps.compactMap { step -> String? in
            guard let answer = session.answers[step.field] else { return nil }
            return "\(step.prompt)：\(answer)"
        }
        let context = answered.isEmpty
            ? "（尚无已填写字段）"
            : answered.joined(separator: "\n")
        return "已填写的草案上下文（项目 \(session.projectId)）：\n\(context)\n\n用户请求：\(userAsk)"
    }

    // MARK: - Deterministic failure mapping

    /// GatewayError → FIXED Chinese reason string (mirrors
    /// FacilitatorDialogue.fallbackReason). Associated values (scope
    /// descriptors, provider error text) are deliberately dropped — no
    /// secrets, no scope values, no upstream error bodies in the IR.
    static func fallbackReason(for error: GatewayError) -> String {
        switch error {
        case .tapeUnavailable:       return "磁带记录不可用（无记录不通话）"
        case .credentialUnavailable: return "未配置 API Key（请输入「meta 设置」保存密钥）"
        case .providerError:         return "模型服务暂时不可达"
        case .codecError:            return "模型响应解析失败"
        }
    }

    /// Deterministic fallback document: same reason → byte-identical encoding.
    static func unavailableDocument(reason: String) -> ViewIRDocument {
        ViewIRDocument(
            kind: "meta_unavailable",
            deriveSource: ["user_input", "gateway_error"],
            blocks: [
                .summaryCard(SummaryCardPayload(title: "Meta AI 暂不可用", body: reason))
            ]
        )
    }

    // MARK: - Deterministic route documents (zero model)

    /// Drafting intent without an active wizard session → deterministic
    /// notice (zero gateway). The user must start a draft first.
    static func requiresWizardDocument() -> ViewIRDocument {
        ViewIRDocument(
            kind: "meta_draft_requires_wizard",
            deriveSource: ["user_input"],
            blocks: [.summaryCard(SummaryCardPayload(
                title: "Meta 起草",
                body: "先用 ⌘N 或「立项」开始一个草案，再让 Meta 起草。"
            ))]
        )
    }

    /// Deterministic placeholder shown synchronously while the async meta
    /// task is in flight (the proposal replaces it on arrival).
    static func draftingInProgressDocument() -> ViewIRDocument {
        ViewIRDocument(
            kind: "meta_drafting_in_progress",
            deriveSource: ["user_input"],
            blocks: [.summaryCard(SummaryCardPayload(
                title: "Meta AI",
                body: "起草中…"
            ))]
        )
    }
}
