// Onboarding (A1_07): two screens, one decision each (Software 3.0 law 1).
// Connect = one button + one status sentence; Select = one list + one
// confirm. Completion writes the registry, raises the daemon, lands Home.

import SwiftUI

@MainActor
public final class OnboardingModel: ObservableObject {
    public enum Step { case connect, select }

    @Published var step: Step = .connect
    @Published var connect: ConnectLevel?
    @Published var probing = false
    @Published var catalog: [CatalogItem] = []
    @Published var selection = Set<String>()
    @Published var catalogSentence = ""
    @Published var finishError: String?

    public init() {}

    func runConnect() {
        guard !probing else { return } // model-level re-entrancy invariant
        probing = true
        Task.detached { [weak self] in
            // Token never enters published state (S-stage risk): it lives
            // in this local, feeds listAllRepos, and dies with the task.
            let result = GitConnect.detect()
            let local = RepoCatalog.discoverLocal()
            var items: [CatalogItem]
            var sentence: String
            if case .ghCli = result.level, let token = result.token {
                do {
                    let (remote, truncated) = try await GitHubAPI.listAllRepos(token: token)
                    items = RepoCatalog.merge(gitHub: remote, local: local)
                    sentence = "GitHub \(remote.count) 个仓库 + 本地发现 \(local.count) 个 clone"
                    if truncated {
                        sentence += "（远程列表超出上限被截断，缺的仓库可稍后手动添加）"
                    }
                } catch {
                    // Degrade VISIBLY to the local list - never a silent
                    // partial world.
                    items = RepoCatalog.merge(gitHub: [], local: local)
                    sentence = "GitHub 列表拉取失败（\(error.localizedDescription)），先用本地发现的 \(local.count) 个"
                }
            } else {
                items = RepoCatalog.merge(gitHub: [], local: local)
                sentence = "本地发现 \(local.count) 个 clone"
            }
            let final = (items, sentence, result.level)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.connect = final.2
                self.catalog = final.0
                self.catalogSentence = final.1
                // Preselect local clones - they are radar-able today.
                self.selection = Set(final.0.filter { $0.localPath != nil }.map(\.id))
                self.probing = false
            }
        }
    }

    func finish() -> Bool {
        let chosen = catalog.filter { selection.contains($0.id) }
        do {
            try RegistryWriter.write(projects: RegistryWriter.entries(from: chosen))
            return true
        } catch {
            finishError = "注册表写入失败：\(error.localizedDescription)"
            return false
        }
    }
}

public struct OnboardingView: View {
    @StateObject private var model = OnboardingModel()
    let onDone: () -> Void

    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    public var body: some View {
        ZStack {
            Tokens.Space.background.ignoresSafeArea()
            switch model.step {
            case .connect: connectStep
            case .select: selectStep
            }
        }
        .frame(minWidth: 560, minHeight: 480)
        .preferredColorScheme(.dark)
    }

    private var connectStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("TuringOS")
                .font(Tokens.Typography.ui(28, weight: .semibold))
                .foregroundStyle(Tokens.Text.primary)
            Text("把你的 git 世界交给它看管")
                .font(Tokens.Typography.ui(14))
                .foregroundStyle(Tokens.Text.secondary)

            if let connect = model.connect {
                Text(connect.sentence)
                    .font(Tokens.Typography.ui(13))
                    .foregroundStyle(Tokens.Text.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Tokens.Space.glassBase, in: Capsule())
                    .overlay(Capsule().stroke(Tokens.Space.glassBorder))
                Button("继续") { model.step = .select }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(model.probing ? "正在探测…" : "接入") { model.runConnect() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.probing)
            }
            Spacer()
        }
    }

    private var selectStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("看管哪些项目？")
                .font(Tokens.Typography.ui(18, weight: .semibold))
                .foregroundStyle(Tokens.Text.primary)
            Text(model.catalogSentence)
                .font(Tokens.Typography.ui(12))
                .foregroundStyle(Tokens.Text.secondary)

            List(model.catalog, selection: $model.selection) { item in
                HStack {
                    Toggle(isOn: Binding(
                        get: { model.selection.contains(item.id) },
                        set: { on in
                            if on { model.selection.insert(item.id) } else { model.selection.remove(item.id) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(Tokens.Typography.mono(12))
                                .foregroundStyle(Tokens.Text.primary)
                            Text(item.sentence)
                                .font(Tokens.Typography.ui(11))
                                .foregroundStyle(Tokens.Text.tertiary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)

            if let err = model.finishError {
                Text(err)
                    .font(Tokens.Typography.ui(11))
                    .foregroundStyle(Tokens.Semantic.red.color)
            }
            HStack {
                Spacer()
                Text("\(model.selection.count) 个已选")
                    .font(Tokens.Typography.ui(11))
                    .foregroundStyle(Tokens.Text.tertiary)
                Button("开始看管") {
                    if model.finish() { onDone() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.selection.isEmpty)
            }
        }
        .padding(24)
    }
}
