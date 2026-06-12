// OrbView.swift — Dynamic Orb first screen for A1_16.
//
// UI constitution compliance (docs/02 §1.1):
//   P4: Orb is the ONLY first screen; no alternative home.
//   P5: All entries via language/Orb intent; no static button queues.
//   P6: System response = generated temporary interface (View IR), not page nav.
//
// Three laws (docs/02 §1.2):
//   注意力优先: needs-ruling state uses strong visual emphasis.
//   语言优先:   text input is the primary entry point; voice placeholder present.
//   安静即成功: idle state is minimal occupancy; no unprompted push.
//
// Color discipline: all Orb state colors reference Tokens.Semantic only.
// No project accent on Orb chrome (docs/02 §2.2 color rules).

import SwiftUI

// MARK: - OrbView

public struct OrbView: View {
    @StateObject private var vm: OrbViewModel
    @State private var inputDraft: String = ""
    @State private var showKernelDebug: Bool = false
    @ObservedObject var store: GlanceStore
    /// A1_30: system menu bar → bus → Orb. Intent commands funnel through
    /// the SAME typed-intent path as the input field (menu = formal entry
    /// for what you could type; docs/02 §6 escape hatch).
    @EnvironmentObject private var commandBus: AppCommandBus

    /// A1_34/A1_35: `dialogue` and `metaDrafting` default to nil (escape-
    /// hatch / deterministic cards only). Production wiring passes
    /// FacilitatorDialogue.production() + MetaDrafting.production() at the
    /// app entry path ONLY (TuringOSApp) — tests and previews keep nil.
    public init(
        store: GlanceStore,
        probe: any FacilitatorRuntimeProbe = SystemFacilitatorProbe(),
        dialogue: FacilitatorDialogue? = nil,
        metaDrafting: MetaDrafting? = nil,
        ciObservationProvider: (@Sendable () -> (any RepoObservationSource)?)? = nil
    ) {
        _vm = StateObject(wrappedValue: OrbViewModel(
            probe: probe, dialogue: dialogue, metaDrafting: metaDrafting,
            ciObservationProvider: ciObservationProvider
        ))
        self.store = store
    }

    public var body: some View {
        ZStack {
            Tokens.Space.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Debug bar (kernel debug面 access — docs/02 §6.2)
                debugToolbar

                Spacer()

                // --- Orb visual ---
                OrbVisual(state: vm.state)
                    .padding(.bottom, 32)

                // --- State annotation ---
                stateLabel

                // --- Text input ---
                inputArea
                    .padding(.top, 20)

                // --- Projection area ---
                if let doc = vm.currentProjection {
                    ViewIRRenderer(document: doc)
                        .frame(maxWidth: 600)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.top, 16)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showKernelDebug) {
            ContentView(store: store)
                .environmentObject(commandBus)
                .frame(minWidth: 960, minHeight: 600)
        }
        .onReceive(commandBus.$pending) { command in
            guard let command else { return }
            handleAppCommand(command)
        }
        .task { vm.resolveRuntime() }
        .preferredColorScheme(.dark)
        .frame(minWidth: 640, minHeight: 520)
    }

    // MARK: - Menu command handling (A1_30)

    /// Consume bus commands addressed to the Orb. Intent commands replay
    /// the exact typed path (`vm.send(.inputSubmitted)`), so menu and input
    /// field stay behaviorally identical. Panel commands only PRESENT the
    /// kernel debug sheet and are left on the bus — ContentView consumes
    /// them to select its panel (its @Published subscription replays the
    /// pending value even when the sheet mounts afterwards).
    private func handleAppCommand(_ command: AppCommand) {
        switch command {
        case .newInit:
            // Same hook as typing 立项: starts the spec wizard
            // (OrbViewModel.handleInput → WizardSession).
            vm.send(.inputSubmitted(text: "立项"))
            commandBus.consume()
        case .projectOverview:
            // IntentRouter routes 项目 → projectPicker.
            vm.send(.inputSubmitted(text: "项目"))
            commandBus.consume()
        case .morningRitual:
            // IntentRouter routes 早 → morningRitual projection.
            vm.send(.inputSubmitted(text: "早"))
            commandBus.consume()
        case .connectRepo:
            // No 连接 route exists in IntentRouter yet — this lands on the
            // intent-suggestions escape hatch (visible, not silent).
            // TODO(A1_3x): route 连接仓库 to a real connect pane backed by
            // GitConnect.detect(runner:) (GitConnect.swift).
            vm.send(.inputSubmitted(text: "连接仓库"))
            commandBus.consume()
        case .runCICheck:
            // TODO(A1_3x): IntentRouter.routeBase does not yet call
            // IntentRouter.routeCIIntent(lower:observationSource:projectContext:)
            // (CIProjections.swift) — wire it with a real RepoObservationSource
            // so this projects live CI status instead of suggestions.
            vm.send(.inputSubmitted(text: "ci 检查"))
            commandBus.consume()
        case .showOrb:
            showKernelDebug = false
            commandBus.consume()
        case .showKernelDebug, .showRadar, .showAttention, .showCI:
            // Present only; ContentView consumes to pick the panel.
            showKernelDebug = true
        }
    }

    // MARK: - Debug toolbar

    /// Debug path to ContentView (内核调试面) — in-view button kept from
    /// A1_16. A1_30: the FORMAL ⌘D entry is now the 视图 menu item (menu
    /// key equivalents match before view shortcuts, so the menu owns the
    /// keystroke); this button stays as the visible on-canvas affordance.
    /// Existing radar/attention features stay reachable here (§6.2).
    private var debugToolbar: some View {
        HStack {
            Spacer()
            Button {
                showKernelDebug = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text("内核调试面")
                        .font(Tokens.Typography.mono(10))
                }
                .foregroundStyle(Tokens.Text.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Tokens.Space.glassBase, in: Capsule())
                .overlay(Capsule().stroke(Tokens.Space.glassBorder))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("d", modifiers: [.command])
            .accessibilityLabel("打开内核调试面")
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
    }

    // MARK: - State label

    private var stateLabel: some View {
        Group {
            switch vm.state {
            case .idle:
                Text("待命")
                    .font(Tokens.Typography.ui(12))
                    .foregroundStyle(Tokens.Text.tertiary)
            case .listening:
                Text("正在聆听…")
                    .font(Tokens.Typography.ui(12))
                    .foregroundStyle(Tokens.Semantic.blue.color)
            case .thinking:
                Text("正在处理…")
                    .font(Tokens.Typography.ui(12))
                    .foregroundStyle(Tokens.Semantic.blue.color)
            case .needsRuling:
                // 注意力优先 — strong visual emphasis
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.Semantic.purple.color)
                    Text("需要你的裁决")
                        .font(Tokens.Typography.ui(13, weight: .semibold))
                        .foregroundStyle(Tokens.Semantic.purple.color)
                }
            case .degraded:
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.Semantic.gray.color)
                    Text("降级模式")
                        .font(Tokens.Typography.ui(12))
                        .foregroundStyle(Tokens.Semantic.gray.color)
                }
            }
        }
        .animation(.easeInOut(duration: Tokens.Motion.cardHover), value: vm.state)
    }

    // MARK: - Input area

    private var inputArea: some View {
        HStack(spacing: 10) {
            TextField("输入意图…", text: $inputDraft)
                .textFieldStyle(.plain)
                .font(Tokens.Typography.ui(14))
                .foregroundStyle(Tokens.Text.primary)
                .onSubmit { submitInput() }

            Button(action: submitInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(inputDraft.isEmpty
                        ? Tokens.Text.tertiary
                        : Tokens.Semantic.blue.color)
            }
            .buttonStyle(.plain)
            .disabled(inputDraft.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(orbBorderColor, lineWidth: 1)
        )
        .frame(maxWidth: 520)
        .animation(.easeInOut(duration: Tokens.Motion.cardHover), value: vm.state)
    }

    private var orbBorderColor: Color {
        switch vm.state {
        case .idle:         return Tokens.Space.glassBorder
        case .listening:    return Tokens.Semantic.blue.color.opacity(0.5)
        case .thinking:     return Tokens.Semantic.blue.color.opacity(0.3)
        case .needsRuling:  return Tokens.Semantic.purple.color.opacity(0.5)
        case .degraded:     return Tokens.Semantic.gray.color.opacity(0.3)
        }
    }

    private func submitInput() {
        guard !inputDraft.isEmpty else { return }
        vm.send(.inputSubmitted(text: inputDraft))
        inputDraft = ""
    }
}

// MARK: - OrbVisual

/// The Orb itself: centered pulsing circle whose color encodes state semantics.
/// Color strictly follows Tokens.Semantic — no project accent on Orb chrome (§2.2).
struct OrbVisual: View {
    let state: OrbStateValue
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(orbColor.opacity(0.08 + 0.04 * sin(phase)))
                .frame(width: 96, height: 96)
                .blur(radius: 14)

            // Inner core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [orbColor.opacity(0.85), orbColor.opacity(0.35)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 32
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .shadow(color: orbColor.opacity(0.4), radius: 12)
        }
        .onAppear { startPulse() }
        .onChange(of: state) { startPulse() }
        .animation(.easeInOut(duration: Tokens.Motion.cardHover), value: state)
        .accessibilityLabel("Orb 状态：\(stateLabel)")
    }

    private var orbColor: Color {
        switch state {
        case .idle:         return Tokens.Semantic.gray.color
        case .listening:    return Tokens.Semantic.blue.color
        case .thinking:     return Tokens.Semantic.blue.color
        case .needsRuling:  return Tokens.Semantic.purple.color
        case .degraded:     return Tokens.Semantic.gray.color
        }
    }

    private var orbSize: CGFloat {
        switch state {
        case .idle:         return 44
        case .listening:    return 52
        case .thinking:     return 48
        case .needsRuling:  return 56
        case .degraded:     return 40
        }
    }

    private var stateLabel: String {
        switch state {
        case .idle:         return "待命"
        case .listening:    return "聆听中"
        case .thinking:     return "处理中"
        case .needsRuling:  return "需要裁决"
        case .degraded:     return "降级"
        }
    }

    private func startPulse() {
        guard state == .thinking || state == .listening else { return }
        withAnimation(
            .easeInOut(duration: Tokens.Motion.pulsePeriod / 2).repeatForever(autoreverses: true)
        ) {
            phase = .pi
        }
    }
}

// MARK: - MetaAIConfigCardView

/// Config card for Meta AI credentials — reachable from Orb via "设置 meta".
/// SecureField for the API key; value goes to KeychainStore, never to any model context.
public struct MetaAIConfigCardView: View {
    @State private var config: MetaAIConfig
    @State private var apiKeyDraft: String = ""
    @State private var savedFeedback: String = ""
    private let store: KeychainStore

    public init(config: MetaAIConfig = MetaAIConfigStore.load(),
                keychainStore: KeychainStore = .shared) {
        _config = State(initialValue: config)
        self.store = keychainStore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meta AI 配置")
                .font(Tokens.Typography.ui(16, weight: .semibold))
                .foregroundStyle(Tokens.Text.primary)

            // Provider picker
            Picker("协议", selection: $config.providerKind) {
                ForEach(MetaAIProviderKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            // Endpoint field
            VStack(alignment: .leading, spacing: 4) {
                Text("端点 URL（可选）")
                    .font(Tokens.Typography.ui(11))
                    .foregroundStyle(Tokens.Text.tertiary)
                TextField("https://...", text: Binding(
                    get: { config.endpointURL?.absoluteString ?? "" },
                    set: { config.endpointURL = $0.isEmpty ? nil : URL(string: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(Tokens.Typography.mono(12))
            }

            // SecureField for API key — value goes directly to Keychain
            // NEVER to model context (docs/02 §7.1).
            VStack(alignment: .leading, spacing: 4) {
                Text("API Key（\(config.credentialScope)）")
                    .font(Tokens.Typography.ui(11))
                    .foregroundStyle(Tokens.Text.tertiary)
                SecureField("粘贴密钥…", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(Tokens.Typography.mono(12))
                Text("凭证将保存至 macOS Keychain，不进入模型上下文。")
                    .font(Tokens.Typography.ui(10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }

            HStack {
                Button("保存") { saveConfig() }
                    .keyboardShortcut(.defaultAction)
                if !savedFeedback.isEmpty {
                    Text(savedFeedback)
                        .font(Tokens.Typography.ui(11))
                        .foregroundStyle(Tokens.Semantic.green.color)
                }
            }
        }
        .padding(20)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.Space.glassBorder))
    }

    private func saveConfig() {
        MetaAIConfigStore.save(config)
        if !apiKeyDraft.isEmpty {
            // Secret goes ONLY to Keychain — not to any observable state.
            _ = try? store.save(
                service: config.credentialScope,
                account: "api_key",
                secret: apiKeyDraft
            )
            apiKeyDraft = ""
        }
        savedFeedback = "已保存"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            savedFeedback = ""
        }
    }
}
