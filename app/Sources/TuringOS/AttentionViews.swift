// A1_08: the Attention Stack home + sentence-first Glance (三定律视图层).
// Structural anti-pattern guarantee: rows render exactly ONE sentence
// string; there is no count-grid component left in the app (GlanceMetrics
// was deleted in this atom). Empty sections collapse; all-healthy renders
// a single sentence on space - silence is success.

import SwiftUI

public struct AttentionStackView: View {
    @ObservedObject var store: GlanceStore
    @State private var evidenceItem: AttentionItem?

    public init(store: GlanceStore) {
        self.store = store
    }

    public var body: some View {
        let triage = store.triage
        Group {
            if triage.needsYou.isEmpty && triage.working.isEmpty {
                allQuiet(triage)
            } else {
                stack(triage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Space.background)
        .popover(item: $evidenceItem) { item in
            EvidenceDrawer(item: item)
        }
    }

    private func allQuiet(_ triage: AttentionTriage) -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Tokens.Semantic.blue.color)
                .frame(width: 6, height: 6)
                .breathing()
            Text(triage.glanceSentence)
                .font(Tokens.Typography.ui(15))
                .foregroundStyle(Tokens.Text.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(triage.glanceSentence)
    }

    private func stack(_ triage: AttentionTriage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !triage.needsYou.isEmpty {
                    section("等你") {
                        ForEach(triage.needsYou) { item in
                            AttentionRow(item: item) { evidenceItem = item }
                        }
                    }
                }
                if !triage.working.isEmpty {
                    section("进行中") {
                        ForEach(triage.working) { row in
                            WorkingRowView(row: row)
                        }
                    }
                }
                if let quiet = triage.quietSentence {
                    Text(quiet)
                        .font(Tokens.Typography.ui(12))
                        .foregroundStyle(Tokens.Text.tertiary)
                        .padding(.top, 4)
                }
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Tokens.Typography.ui(11, weight: .semibold))
                .foregroundStyle(Tokens.Text.tertiary)
                .textCase(.uppercase)
            content()
        }
    }
}

/// One needs-you row: severity dot + the sentence + one action (law 1:
/// a single decision per item).
struct AttentionRow: View {
    let item: AttentionItem
    let onEvidence: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // Icon + color dual channel (VISUAL_SEMANTICS rule 3: color
            // never carries semantics alone; the sentence is the text leg).
            Image(systemName: item.severity.iconName)
                .font(.system(size: 11))
                .foregroundStyle(item.severity.semantic.color)
                .padding(.top, 2)
            Text(item.sentence)
                .font(Tokens.Typography.ui(13))
                .foregroundStyle(Tokens.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if item.evidence != nil {
                Button("查看证据", action: onEvidence)
                    .buttonStyle(.plain)
                    .font(Tokens.Typography.ui(11))
                    .foregroundStyle(Tokens.Text.secondary)
            }
        }
        .padding(12)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.severity.semantic.color.opacity(0.25))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.sentence)
    }
}

/// Ambient working row: name + breathing pulse + sentence. No numbers grid.
struct WorkingRowView: View {
    let row: WorkingRow

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Tokens.Semantic.blue.color)
                .frame(width: 6, height: 6)
                .breathing()
            Text(row.projectId)
                .font(Tokens.Typography.mono(12))
                .foregroundStyle(Tokens.Text.primary)
            Text(row.sentence)
                .font(Tokens.Typography.ui(12))
                .foregroundStyle(Tokens.Text.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.projectId)：\(row.sentence)")
    }
}

/// Evidence drill-down (law 2): the raw payload behind the sentence,
/// rendered as plain key-value rows - evidence, not decoration.
struct EvidenceDrawer: View {
    let item: AttentionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.sentence)
                .font(Tokens.Typography.ui(12, weight: .semibold))
                .foregroundStyle(Tokens.Text.primary)
            Divider()
            switch item.evidence {
            case .object(let fields):
                fieldRows(fields)
            case .array(let parts):
                // grouped evidence (e.g. one conflict, N worktrees)
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if case .object(let fields) = part {
                        if index > 0 { Divider().padding(.vertical, 2) }
                        fieldRows(fields)
                    }
                }
            default:
                EmptyView()
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(Tokens.Space.background)
    }

    @ViewBuilder
    private func fieldRows(_ fields: [String: JSONValue]) -> some View {
        ForEach(fields.keys.sorted(), id: \.self) { key in
            HStack(alignment: .firstTextBaseline) {
                Text(key)
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Text.tertiary)
                Spacer(minLength: 16)
                Text(scalarDescription(fields[key]!))
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Text.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func scalarDescription(_ value: JSONValue) -> String {
        switch value {
        case .null: "null"
        case .bool(let b): String(b)
        case .number(let n): n.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(n)) : String(n)
        case .string(let s): s
        case .array(let a): "[\(a.count)]"
        case .object(let o): "{\(o.count)}"
        }
    }
}

/// The breathing pulse (V6 material language; Motion budget pinned in
/// tokens - breathe, never flicker).
struct BreathingModifier: ViewModifier {
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(dim ? 0.35 : 1.0)
            .animation(
                .easeInOut(duration: Tokens.Motion.pulsePeriod / 2).repeatForever(autoreverses: true),
                value: dim
            )
            .onAppear { dim = true }
    }
}

extension View {
    func breathing() -> some View { modifier(BreathingModifier()) }
}
