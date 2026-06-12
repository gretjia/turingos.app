// FacilitatorDialogue.swift — A1_34: live Facilitator dialogue service.
//
// Constitutional anchors:
//   - WHITEPAPER.md §5.1/§6/§7 — Facilitator dialogue flow (lawful-now subset):
//     a model call is a SHELL OBSERVATION RECORD; zero Q advancement here.
//   - WHITEPAPER.md §5.6 — rules first: this service is reached ONLY when the
//     deterministic IntentRouter missed (escape-hatch fallback). Deterministic
//     route hits never construct a request (predicate 1: zero gateway calls).
//   - docs/02_SOFTWARE_3_UI_PRD.md §3.1 red line 1 — model output enters View
//     IR blocks ONLY. The response text lands in a summary_card BODY STRING;
//     it is never interpreted, never rendered as markup or script.
//   - docs/01_KERNEL_CONTRACTS.md I8/I9 — gateway handles tape + credentials;
//     this service holds neither secrets nor tape handles.
//
// FAIL-VISIBLE: any GatewayError maps to a DETERMINISTIC fallback document
// (fixed Chinese reason strings — no secrets, no scope values, no provider
// error text) plus the intent-suggestions escape hatch. Never fail-silent.
//
// BOUNDARY: async orchestration only — no SwiftUI, no Keychain reads, no
// network primitives. The injected ModelGateway owns all I/O.

import Foundation

// MARK: - FacilitatorDialogue

/// Async dialogue service: user text in, ViewIRDocument out.
///
/// Injection seam: tests build this on a ModelGateway with MockTransport +
/// in-memory sink (zero network, zero disk tape). Production assembly is
/// `FacilitatorDialogue.production()` — constructed ONLY at the app entry
/// path (TuringOSApp → OrbView), never in tests.
public struct FacilitatorDialogue: Sendable {

    private let gateway: ModelGateway
    /// Keychain scope descriptor the gateway resolves (I9: descriptor only,
    /// never the key value). Injectable so tests never touch the real
    /// "deepseek-api" Keychain item.
    private let credentialScope: String

    /// Short Chinese Facilitator system prompt (§5.1 thin/fast lane).
    static let systemPrompt =
        "你是 TuringOS 的 Facilitator AI。用一两句中文回应用户意图，并在适合时建议下一步动作（立项/检查 CI/查看项目）。不要输出 HTML 或代码。"

    public init(gateway: ModelGateway, credentialScope: String = DeepSeekPresets.credentialScope) {
        self.gateway = gateway
        self.credentialScope = credentialScope
    }

    // MARK: - Production assembly

    /// Production wiring (A1_34): FileTapeSink.defaultSink() (I8: every call
    /// enters the shell tape JSONL) + LiveURLSessionTransport + the DeepSeek
    /// facilitator preset. Returns nil when no facilitator preset exists.
    public static func production() -> FacilitatorDialogue? {
        guard DeepSeekPresets.config(for: .facilitator) != nil else { return nil }
        let gateway = ModelGateway(
            tapeSink: FileTapeSink.defaultSink(),
            transport: LiveURLSessionTransport(),
            keychainStore: .shared,
            projectId: "proj_orb_shell"
        )
        return FacilitatorDialogue(gateway: gateway)
    }

    // MARK: - Respond

    /// Send `userText` to the Facilitator model and project the reply.
    ///
    /// SUCCESS → kind "facilitator_reply": the model text goes ONLY into the
    /// summary_card body string (red line 1).
    /// FAILURE → deterministic "facilitator_unavailable" fallback document
    /// (fixed reason string + intent-suggestions escape hatch).
    public func respond(to userText: String) async -> ViewIRDocument {
        // ONE source of truth: model + thinking mode + endpoint from the preset.
        guard let preset = DeepSeekPresets.config(for: .facilitator) else {
            return Self.unavailableDocument(reason: "Facilitator 预设缺失")
        }

        let request = GatewayRequest(
            role: .facilitator,
            messages: [
                GatewayMessage(role: .system, content: Self.systemPrompt),
                GatewayMessage(role: .user, content: userText)
            ],
            maxTokens: 512,
            thinkingMode: preset.thinking
        )
        let config = MetaAIConfig(
            providerKind: .openaiCompatible,
            endpointURL: preset.endpoint,
            credentialScope: credentialScope,
            displayName: "Facilitator (DeepSeek v4 Flash)"
        )

        do {
            let response = try await gateway.send(request, config: config, model: preset.model)
            // RED LINE 1: response.content is a STRING in the card body —
            // never interpreted, never rendered as markup.
            return ViewIRDocument(
                kind: "facilitator_reply",
                deriveSource: ["user_input", "model_call:facilitator:\(preset.model)"],
                blocks: [.summaryCard(SummaryCardPayload(
                    title: "Facilitator",
                    body: response.content
                ))]
            )
        } catch let error as GatewayError {
            return Self.unavailableDocument(reason: Self.fallbackReason(for: error))
        } catch {
            return Self.unavailableDocument(reason: "未知网关错误")
        }
    }

    // MARK: - Deterministic failure mapping

    /// GatewayError → FIXED Chinese reason string. Associated values
    /// (scope descriptors, provider error text) are deliberately dropped —
    /// no secrets, no scope values, no upstream error bodies in the IR.
    static func fallbackReason(for error: GatewayError) -> String {
        switch error {
        case .tapeUnavailable:       return "磁带记录不可用（无记录不通话）"
        case .credentialUnavailable: return "未配置 API Key（请输入「meta 设置」保存密钥）"
        case .providerError:         return "模型服务暂时不可达"
        case .codecError:            return "模型响应解析失败"
        }
    }

    /// Deterministic fallback document: same reason → byte-identical encoding.
    /// Reuses the IntentRouter escape-hatch suggestions payload (fail-visible:
    /// the user always gets the deterministic exits).
    static func unavailableDocument(reason: String) -> ViewIRDocument {
        ViewIRDocument(
            kind: "facilitator_unavailable",
            deriveSource: ["user_input", "gateway_error"],
            blocks: [
                .summaryCard(SummaryCardPayload(title: "Facilitator 暂不可用", body: reason))
            ] + IntentRouter.intentSuggestionsDoc().blocks
        )
    }
}
