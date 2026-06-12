// ViewIRRenderer.swift — first-party SwiftUI renderer for View IR documents.
//
// Laws enforced here:
//   • approval_request is rendered EXCLUSIVELY by ApprovalCard — no generic fallback
//     may render it (docs/02 §3.3 渲染铁律; P4 predicate).
//   • credential_field is rendered ONLY via SecureField (isSecure=true);
//     plaintext default is forbidden (docs/02 §7.1 / §3.3 渲染铁律).
//   • .unknown blocks produce an inert notice row; rawType is displayed as
//     a plain string and NEVER interpreted as markup or script.
//   • Every rendered document shows its derive_source provenance line
//     (tape discipline: 凡显示必可溯源, docs/02 §1.3 predicate P1).

import SwiftUI

// MARK: - Top-level renderer

/// Renders a ViewIRDocument as a vertical composition of first-party block components.
public struct ViewIRRenderer: View {
    public let document: ViewIRDocument

    public init(document: ViewIRDocument) {
        self.document = document
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Tape discipline: provenance line is always shown first.
                ProvenanceLine(sources: document.deriveSource)
                Divider()
                    .overlay(Tokens.Space.glassBorder)
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    blockView(for: block)
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .background(Tokens.Space.background)
    }

    @ViewBuilder
    private func blockView(for block: ViewIRBlock) -> some View {
        switch block {
        case .summaryCard(let p):
            SummaryCardView(payload: p)
        case .riskList(let p):
            RiskListView(payload: p)
        case .approvalRequest(let p):
            // ONLY ApprovalCard may render approval_request (§3.3 铁律, P4).
            ApprovalCard(payload: p)
        case .diffView(let p):
            DiffBlockView(payload: p)
        case .evidenceList(let p):
            EvidenceListView(payload: p)
        case .projectPicker(let p):
            ProjectPickerView(payload: p)
        case .specDraft(let p):
            SpecDraftView(payload: p)
        case .budgetCard(let p):
            BudgetCardView(payload: p)
        case .worktreeMap(let p):
            WorktreeMapView(payload: p)
        case .repairPrompt(let p):
            RepairPromptView(payload: p)
        case .dossierView(let p):
            DossierBlockView(payload: p)
        case .morningRitual(let p):
            MorningRitualView(payload: p)
        case .intentSuggestions(let p):
            IntentSuggestionsView(payload: p)
        case .credentialField(let p):
            // SecureField only — no plaintext default (§7.1).
            CredentialFieldView(payload: p)
        case .unknown(let rawType):
            UnknownBlockNotice(rawType: rawType)
        }
    }
}

// MARK: - Provenance line

/// Displays derive_source provenance. Every rendered document shows this
/// (tape discipline, docs/02 §1.3).
struct ProvenanceLine: View {
    let sources: [String]

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 10))
                .foregroundStyle(Tokens.Text.tertiary)
            Text(sources.joined(separator: " · "))
                .font(Tokens.Typography.mono(10))
                .foregroundStyle(Tokens.Text.tertiary)
                .lineLimit(2)
        }
        .accessibilityLabel("来源：\(sources.joined(separator: ", "))")
    }
}

// MARK: - Block components

struct SummaryCardView: View {
    let payload: SummaryCardPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payload.title)
                .font(Tokens.Typography.ui(14, weight: .semibold))
                .foregroundStyle(Tokens.Text.primary)
            Text(payload.body)
                .font(Tokens.Typography.ui(13))
                .foregroundStyle(Tokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let ref = payload.tapeRef {
                Text(ref)
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct RiskListView: View {
    let payload: RiskListPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(payload.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: iconName(for: item.level))
                        .font(.system(size: 11))
                        .foregroundStyle(semantic(for: item.level).color)
                        .padding(.top, 1)
                    Text(item.text)
                        .font(Tokens.Typography.ui(13))
                        .foregroundStyle(Tokens.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    private func semantic(for level: String) -> Tokens.Semantic {
        switch level {
        case "critical": return .red
        case "warn":     return .yellow
        default:         return .blue  // info
        }
    }

    private func iconName(for level: String) -> String {
        switch level {
        case "critical": return "xmark.circle.fill"
        case "warn":     return "exclamationmark.triangle.fill"
        default:         return "info.circle.fill"
        }
    }
}

// MARK: - ApprovalCard (the ONLY renderer for approval_request)

/// ApprovalCard renders approval_request blocks EXCLUSIVELY (docs/02 §3.3 铁律).
/// Visually distinct from all other block renderers.
/// In v0 this carries envelopeRef and renders human-readable placeholders;
/// visible_card_hash validation is wired in a later atom when the kernel
/// ApprovalEnvelope surface is live.
public struct ApprovalCard: View {
    public let payload: ApprovalRequestPayload

    public init(payload: ApprovalRequestPayload) {
        self.payload = payload
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Tokens.Semantic.purple.color)
                Text("批准请求")
                    .font(Tokens.Typography.ui(13, weight: .semibold))
                    .foregroundStyle(Tokens.Semantic.purple.color)
                Spacer()
            }
            Divider()
                .overlay(Tokens.Semantic.purple.color.opacity(0.3))
            // Placeholder fields — actual content resolved from kernel envelope.
            labelRow("信封引用", payload.envelopeRef)
            labelRow("摘要", "（待从内核 ApprovalEnvelope 读取）")
            labelRow("后果", "（待从内核 ApprovalEnvelope 读取）")
            labelRow("可逆性", "（待从内核 ApprovalEnvelope 读取）")
            // Approval button disabled in v0 pending visible_card_hash wiring.
            Button(action: {}) {
                Text("裁决（此版本未激活）")
                    .font(Tokens.Typography.ui(12, weight: .semibold))
                    .foregroundStyle(Tokens.Text.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .disabled(true)
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Tokens.Text.tertiary.opacity(0.3))
            )
        }
        .padding(14)
        .background(Tokens.Semantic.purple.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Tokens.Semantic.purple.color.opacity(0.35))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("批准请求：\(payload.envelopeRef)")
    }

    @ViewBuilder
    private func labelRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(Tokens.Typography.ui(11))
                .foregroundStyle(Tokens.Text.tertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(Tokens.Typography.ui(12))
                .foregroundStyle(Tokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DiffBlockView: View {
    let payload: DiffViewPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProvenanceBadge(provenance: payload.provenance)
            labelRow("diff_ref", payload.diffRef)
            labelRow("worktree_id", payload.worktreeId)
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func labelRow(_ key: String, _ val: String) -> some View {
        HStack {
            Text(key)
                .font(Tokens.Typography.mono(10))
                .foregroundStyle(Tokens.Text.tertiary)
            Text(val)
                .font(Tokens.Typography.mono(11))
                .foregroundStyle(Tokens.Text.secondary)
        }
    }
}

struct EvidenceListView: View {
    let payload: EvidenceListPayload

    var body: some View {
        // Reuse EvidenceDrawer style: key-value rows, no decoration.
        VStack(alignment: .leading, spacing: 4) {
            Text("证据清单")
                .font(Tokens.Typography.ui(11, weight: .semibold))
                .foregroundStyle(Tokens.Text.tertiary)
            ForEach(Array(payload.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline) {
                    Text(item.kind)
                        .font(Tokens.Typography.mono(10))
                        .foregroundStyle(Tokens.Text.tertiary)
                    Text(item.label)
                        .font(Tokens.Typography.ui(12))
                        .foregroundStyle(Tokens.Text.secondary)
                    Spacer(minLength: 8)
                    Text(item.ref)
                        .font(Tokens.Typography.mono(10))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ProjectPickerView: View {
    let payload: ProjectPickerPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("选择项目")
                .font(Tokens.Typography.ui(11, weight: .semibold))
                .foregroundStyle(Tokens.Text.tertiary)
            ForEach(Array(payload.projects.enumerated()), id: \.offset) { _, proj in
                HStack {
                    Circle()
                        .fill(Tokens.Text.secondary)
                        .frame(width: 6, height: 6)
                    Text(proj.name)
                        .font(Tokens.Typography.ui(13))
                        .foregroundStyle(Tokens.Text.primary)
                    Spacer()
                    Text(proj.readiness)
                        .font(Tokens.Typography.mono(10))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SpecDraftView: View {
    let payload: SpecDraftPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            labelRow("spec_ref", payload.specRef)
            labelRow("signature_node", String(payload.signatureNode))
            if !payload.sections.isEmpty {
                Text("节段：\(payload.sections.map(\.ref).joined(separator: ", "))")
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func labelRow(_ key: String, _ val: String) -> some View {
        HStack {
            Text(key).font(Tokens.Typography.mono(10)).foregroundStyle(Tokens.Text.tertiary)
            Text(val).font(Tokens.Typography.mono(11)).foregroundStyle(Tokens.Text.secondary)
        }
    }
}

struct BudgetCardView: View {
    let payload: BudgetCardPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            labelRow("budget_ref", payload.budgetRef)
            labelRow("signature_node", String(payload.signatureNode))
            if let tokens = payload.consumed.tokens {
                labelRow("tokens consumed", String(tokens))
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func labelRow(_ key: String, _ val: String) -> some View {
        HStack {
            Text(key).font(Tokens.Typography.mono(10)).foregroundStyle(Tokens.Text.tertiary)
            Text(val).font(Tokens.Typography.mono(11)).foregroundStyle(Tokens.Text.secondary)
        }
    }
}

struct WorktreeMapView: View {
    let payload: WorktreeMapPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Worktree 拓扑")
                .font(Tokens.Typography.ui(11, weight: .semibold))
                .foregroundStyle(Tokens.Text.tertiary)
            ForEach(Array(payload.worktrees.enumerated()), id: \.offset) { _, wt in
                HStack {
                    Circle()
                        .fill(statusColor(wt.status))
                        .frame(width: 6, height: 6)
                    Text(wt.worktreeId)
                        .font(Tokens.Typography.mono(12))
                        .foregroundStyle(Tokens.Text.primary)
                    Spacer()
                    Text(wt.status)
                        .font(Tokens.Typography.mono(10))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "running":          return Tokens.Semantic.blue.color
        case "done":             return Tokens.Semantic.green.color
        case "halted":           return Tokens.Semantic.gray.color
        case "pending_approval": return Tokens.Semantic.yellow.color
        default:                 return Tokens.Semantic.gray.color
        }
    }
}

struct RepairPromptView: View {
    let payload: RepairPromptPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(Tokens.Semantic.yellow.color)
                Text("修复建议")
                    .font(Tokens.Typography.ui(12, weight: .semibold))
                    .foregroundStyle(Tokens.Semantic.yellow.color)
            }
            Text(payload.suggestedPrompt)
                .font(Tokens.Typography.ui(12))
                .foregroundStyle(Tokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("目标 worktree：\(payload.targetWorktree)")
                .font(Tokens.Typography.mono(10))
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct DossierBlockView: View {
    let payload: DossierViewPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProvenanceBadge(provenance: payload.provenance)
            labelRow("dossier_ref", payload.dossierRef)
            labelRow("signature_node", String(payload.signatureNode))
            if !payload.riskFindings.isEmpty {
                Text("RiskFindings: \(payload.riskFindings.joined(separator: ", "))")
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func labelRow(_ key: String, _ val: String) -> some View {
        HStack {
            Text(key).font(Tokens.Typography.mono(10)).foregroundStyle(Tokens.Text.tertiary)
            Text(val).font(Tokens.Typography.mono(11)).foregroundStyle(Tokens.Text.secondary)
        }
    }
}

struct MorningRitualView: View {
    let payload: MorningRitualPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sunrise.fill")
                    .foregroundStyle(Tokens.Semantic.yellow.color)
                Text("早晨仪式 · \(payload.date)")
                    .font(Tokens.Typography.ui(13, weight: .semibold))
                    .foregroundStyle(Tokens.Text.primary)
            }
            Text("tape 范围：\(payload.tapeRange)")
                .font(Tokens.Typography.mono(10))
                .foregroundStyle(Tokens.Text.tertiary)
            Divider().overlay(Tokens.Space.glassBorder)
            HStack(spacing: 16) {
                ForEach(Array(payload.buckets.enumerated()), id: \.offset) { _, bucket in
                    VStack(spacing: 2) {
                        Text(String(bucket.count))
                            .font(Tokens.Typography.ui(18, weight: .semibold))
                            .foregroundStyle(bucketColor(bucket.label))
                        Text(bucket.label)
                            .font(Tokens.Typography.ui(10))
                            .foregroundStyle(Tokens.Text.tertiary)
                    }
                }
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    private func bucketColor(_ label: String) -> Color {
        switch label {
        case "done":           return Tokens.Semantic.green.color
        case "staged":         return Tokens.Semantic.blue.color
        case "needs_approval": return Tokens.Semantic.purple.color
        case "blocked":        return Tokens.Semantic.yellow.color
        case "failed":         return Tokens.Semantic.red.color
        default:               return Tokens.Semantic.gray.color
        }
    }
}

struct IntentSuggestionsView: View {
    let payload: IntentSuggestionsPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("意图建议")
                .font(Tokens.Typography.ui(11, weight: .semibold))
                .foregroundStyle(Tokens.Text.tertiary)
            ForEach(Array(payload.suggestions.enumerated()), id: \.offset) { _, s in
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Semantic.blue.color)
                    Text(s.label)
                        .font(Tokens.Typography.ui(12))
                        .foregroundStyle(Tokens.Text.primary)
                }
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Renders a credential_field block using macOS SecureField.
/// Iron law: isSecure=true, no plaintext default (docs/02 §7.1).
/// A1_32: submit wires to Keychain via CredentialSubmitHandler (injected,
/// testable). On success the field is CLEARED — the secret never lingers
/// in view state; only the saved-confirmation line remains.
struct CredentialFieldView: View {
    let payload: CredentialFieldPayload
    var handler: CredentialSubmitHandler = .keychain()
    // SecureField binding — value goes directly to Keychain; never surfaced
    // to model context (docs/02 §7.1 / white paper §9 / §13.7).
    @State private var secureValue: String = ""
    @State private var savedScope: String?
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payload.label)
                .font(Tokens.Typography.ui(12, weight: .semibold))
                .foregroundStyle(Tokens.Text.primary)
            // SecureField only — no TextEditor/TextField fallback.
            // isSecure = true prevents screenshot API capture (§7.1).
            HStack(spacing: 8) {
                SecureField("", text: $secureValue)
                    .font(Tokens.Typography.ui(13))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onSubmit(submit)
                Button("存入 Keychain", action: submit)
                    .disabled(secureValue.isEmpty)
            }
            if let savedScope {
                Text("已存入 Keychain · scope：\(savedScope)")
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Semantic.blue.color)
            } else if let saveError {
                Text("保存失败：\(saveError)")
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Semantic.red.color)
            } else {
                Text("scope：\(payload.credentialScope)")
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(14)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
    }

    private func submit() {
        switch handler.submit(scope: payload.credentialScope, secret: secureValue) {
        case .success(let scope):
            secureValue = ""   // secret never lingers in view state
            savedScope = scope
            saveError = nil
        case .failure(let err):
            saveError = errorLabel(err)
        }
    }

    /// Error label — NEVER includes the secret (CredentialSubmitError carries
    /// only saver descriptions, which KeychainStore keeps secret-free).
    private func errorLabel(_ err: CredentialSubmitError) -> String {
        switch err {
        case .emptySecret:        return "输入为空"
        case .emptyScope:         return "scope 缺失"
        case .saverFailed(let d): return d
        }
    }
}

/// Inert notice for unrecognised block types (forward-compat).
/// rawType is displayed as plain text; it is NEVER interpreted as markup or script.
struct UnknownBlockNotice: View {
    let rawType: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.Semantic.gray.color)
            Text("未识别的投影块：\(rawType)")
                .font(Tokens.Typography.ui(12))
                .foregroundStyle(Tokens.Text.tertiary)
        }
        .padding(10)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("未识别的投影块：\(rawType)")
    }
}

// MARK: - Provenance badge (§7.2)

/// Strong provenance badge for diff_view and dossier_view blocks (§7.2).
/// Color references semantic six only (no project accent channel).
struct ProvenanceBadge: View {
    let provenance: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(semantic.color)
            Text(displayLabel)
                .font(Tokens.Typography.ui(10, weight: .semibold))
                .foregroundStyle(semantic.color)
            if let note = cautionNote {
                Spacer(minLength: 4)
                Text(note)
                    .font(Tokens.Typography.ui(10))
                    .foregroundStyle(semantic.color.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(semantic.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(semantic.color.opacity(0.4)))
        .accessibilityLabel("来源级别：\(displayLabel)")
    }

    private var semantic: Tokens.Semantic {
        switch provenance {
        case "FULL":              return .green
        case "REPO_LEVEL":        return .blue
        case "PARTIAL":           return .yellow
        case "OUTSIDE_GOVERNANCE": return .red
        default:                  return .gray
        }
    }

    private var iconName: String {
        switch provenance {
        case "FULL":              return "checkmark.shield.fill"
        case "REPO_LEVEL":        return "shield.fill"
        case "PARTIAL":           return "exclamationmark.shield.fill"
        case "OUTSIDE_GOVERNANCE": return "xmark.shield.fill"
        default:                  return "shield"
        }
    }

    private var displayLabel: String {
        switch provenance {
        case "OUTSIDE_GOVERNANCE": return "OUTSIDE GOVERNANCE"
        default:                   return provenance
        }
    }

    private var cautionNote: String? {
        switch provenance {
        case "PARTIAL":
            return "此变更来自通道外部，谓词门将要求人工确认。"
        case "OUTSIDE_GOVERNANCE":
            return "此变更不在 TuringOS 治理范围内。"
        default:
            return nil
        }
    }
}
