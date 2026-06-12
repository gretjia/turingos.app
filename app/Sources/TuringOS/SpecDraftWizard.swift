// SpecDraftWizard.swift — pure reducer driving the Init Spec drafting wizard (A1_18).
//
// Design: OrbReducer pattern — a plain struct (SpecDraftReducer) with a static
// transition function, fully unit-testable without SwiftUI.  The wizard walks
// through ordered steps; each step provides a prompt and accumulates an answer.
//
// Ordered steps (§7.2 Init Spec Package field order):
//   0. goals              — 项目目标
//   1. nonGoals           — 非目标
//   2. currentState       — 当前状态
//   3. definitionOfDone   — DoD 列表
//   4. acceptancePredicates — 验收谓词（机器可验证）
//   5. dataScope          — 数据边界
//   6. toolPermissions    — 工具权限
//   7. ciRules            — CI 规则
//   8. initialWorktreePlan — Worktree 计划
//   9. risks              — 风险
//  10. budgetSuggestion   — 预算建议
//  11. externalDelegationPolicy — 外派策略
//  12. review             — 展示摘要，等待确认
//
// Retro-Init mode: prefill(projectId:name:path:currentBranch:) seeds known fields
// and adds a knownDebt placeholder in currentState.
//
// Produces a SpecPackage(status: .draft) on finish.  Never produces .ratified —
// see constitutional boundary in SpecPackage.swift.

import Foundation

// MARK: - WizardStep

/// One step in the Init Spec drafting wizard.
public struct WizardStep: Equatable, Sendable {
    /// Field being collected.
    public enum Field: String, Equatable, Sendable, CaseIterable {
        case goals
        case nonGoals
        case currentState
        case definitionOfDone
        case acceptancePredicates
        case dataScope
        case toolPermissions
        case ciRules
        case initialWorktreePlan
        case risks
        case budgetSuggestion
        case externalDelegationPolicy
        case review
    }

    public let field: Field
    /// Human-readable prompt shown in the Orb.
    public let prompt: String
    /// Guidance hint shown alongside the prompt.
    public let hint: String

    public init(field: Field, prompt: String, hint: String) {
        self.field = field
        self.prompt = prompt
        self.hint = hint
    }
}

// MARK: - WizardSession (value type; the reducer's state)

/// Holds the in-progress wizard state.  Value type — safe to copy; no identity.
public struct WizardSession: Equatable, Sendable {
    public let projectId: String
    /// Step index into SpecDraftReducer.steps.
    public var stepIndex: Int
    /// Accumulated answers keyed by WizardStep.Field.
    public var answers: [WizardStep.Field: String]
    /// True once the review step is confirmed.
    public var finished: Bool

    public init(projectId: String, stepIndex: Int = 0,
                answers: [WizardStep.Field: String] = [:],
                finished: Bool = false) {
        self.projectId = projectId
        self.stepIndex = stepIndex
        self.answers = answers
        self.finished = finished
    }

    /// Current step definition (nil when finished).
    public var currentStep: WizardStep? {
        guard !finished, stepIndex < SpecDraftReducer.steps.count else { return nil }
        return SpecDraftReducer.steps[stepIndex]
    }

    /// Whether the session is on the review step.
    public var isOnReview: Bool {
        currentStep?.field == .review
    }
}

// MARK: - WizardEvent

/// Events that drive the wizard reducer.
public enum WizardEvent: Equatable, Sendable {
    /// User submitted an answer for the current step.
    case submitAnswer(String)
    /// User wants to go back one step (ignored on step 0).
    case goBack
    /// User confirmed the review (only valid on the .review step).
    case confirmReview
}

// MARK: - SpecDraftReducer

/// Pure state machine reducer for the Init Spec drafting wizard.
/// Deterministic: same (session, event) → same new session.
public enum SpecDraftReducer {

    // MARK: Ordered step definitions

    public static let steps: [WizardStep] = [
        WizardStep(
            field: .goals,
            prompt: "项目目标是什么？（每行一条）",
            hint: "描述这个项目成功后能达成什么，使用祈使句。"
        ),
        WizardStep(
            field: .nonGoals,
            prompt: "明确的非目标是什么？（每行一条）",
            hint: "列出本项目明确不做的事，防止范围蔓延。"
        ),
        WizardStep(
            field: .currentState,
            prompt: "项目当前状态？",
            hint: "描述代码库、已有债务、最近的重要决定。"
        ),
        WizardStep(
            field: .definitionOfDone,
            prompt: "完工定义（DoD）是什么？（每行一条）",
            hint: "可机器验证的完成标准，不含主观描述。"
        ),
        WizardStep(
            field: .acceptancePredicates,
            prompt: "验收谓词有哪些？（每行一条，输出域 PASS/FAIL）",
            hint: "必须可程序验证，如 exit-code、grep 匹配。"
        ),
        WizardStep(
            field: .dataScope,
            prompt: "数据边界是什么？（每行一条）",
            hint: "哪些数据可以读、写、删除？"
        ),
        WizardStep(
            field: .toolPermissions,
            prompt: "工具权限清单？（每行一条）",
            hint: "Agent 被允许调用的工具/MCP 列表。"
        ),
        WizardStep(
            field: .ciRules,
            prompt: "CI 规则？（每行一条）",
            hint: "CI 必须通过的 check 列表，以及相关 workflow 约束。"
        ),
        WizardStep(
            field: .initialWorktreePlan,
            prompt: "初始 Worktree 计划？（每行一条）",
            hint: "建议的 worktree 分支命名与任务切分方案。"
        ),
        WizardStep(
            field: .risks,
            prompt: "已知风险？（每行一条）",
            hint: "技术风险、依赖风险、已知债务等。"
        ),
        WizardStep(
            field: .budgetSuggestion,
            prompt: "预算建议？",
            hint: "Token 上限、成本预估、CI cycles、wall-clock 建议。"
        ),
        WizardStep(
            field: .externalDelegationPolicy,
            prompt: "外部 Agent 外派策略？",
            hint: "哪些任务可以外派，外派要求什么 provenance 级别？"
        ),
        WizardStep(
            field: .review,
            prompt: "请确认以上内容。输入「确认」提交草案，输入「返回」修改上一步。",
            hint: "草案将以 status=draft 保存，等待内核仪式批准。"
        ),
    ]

    // MARK: - Transition

    /// Pure transition function.  Returns a new WizardSession.
    public static func reduce(session: WizardSession, event: WizardEvent) -> WizardSession {
        var s = session
        switch event {
        case .submitAnswer(let answer):
            guard !s.finished,
                  s.stepIndex < steps.count else { return s }
            let step = steps[s.stepIndex]
            // On the review step, submitAnswer("确认") is equivalent to confirmReview.
            if step.field == .review {
                let trimmed = answer.trimmingCharacters(in: .whitespaces)
                if trimmed == "确认" {
                    s.finished = true
                }
                // Any other answer on review is a no-op (user should type 确认 or use goBack).
                return s
            }
            s.answers[step.field] = answer
            s.stepIndex += 1
            return s

        case .goBack:
            guard !s.finished, s.stepIndex > 0 else { return s }
            s.stepIndex -= 1
            return s

        case .confirmReview:
            guard !s.finished,
                  s.stepIndex < steps.count,
                  steps[s.stepIndex].field == .review else { return s }
            s.finished = true
            return s
        }
    }

    // MARK: - Build SpecPackage

    /// Convert a finished WizardSession → SpecPackage(status: .draft).
    /// Returns nil if the session is not yet finished.
    public static func buildPackage(from session: WizardSession) -> SpecPackage? {
        guard session.finished else { return nil }
        let a = session.answers
        return SpecPackage(
            projectId: session.projectId,
            goals:                  lines(a[.goals]),
            nonGoals:               lines(a[.nonGoals]),
            currentState:           a[.currentState] ?? "",
            definitionOfDone:       lines(a[.definitionOfDone]),
            acceptancePredicates:   lines(a[.acceptancePredicates]),
            dataScope:              lines(a[.dataScope]),
            toolPermissions:        lines(a[.toolPermissions]),
            ciRules:                lines(a[.ciRules]),
            initialWorktreePlan:    lines(a[.initialWorktreePlan]),
            risks:                  lines(a[.risks]),
            budgetSuggestion:       a[.budgetSuggestion] ?? "",
            externalDelegationPolicy: a[.externalDelegationPolicy] ?? "",
            status: .draft
        )
    }

    // MARK: - Retro-Init prefill

    /// Prefill a new WizardSession from catalog-known project data (Retro-Init path).
    /// Seeds `currentState` with the branch/path context and a knownDebt placeholder.
    /// All other answers remain empty — the user completes them.
    public static func prefill(
        projectId: String,
        name: String,
        path: String,
        currentBranch: String
    ) -> WizardSession {
        var answers: [WizardStep.Field: String] = [:]
        // goals: prefill with a placeholder so the user sees the pattern.
        answers[.goals] = "（请补充 \(name) 的具体目标）"
        // currentState: synthesized from known catalog data + knownDebt placeholder.
        answers[.currentState] = """
        项目：\(name)
        路径：\(path)
        当前分支：\(currentBranch)
        已知债务：（请在此列出已知技术债或遗留问题）
        """
        return WizardSession(projectId: projectId, stepIndex: 0, answers: answers)
    }

    // MARK: - Private helpers

    private static func lines(_ s: String?) -> [String] {
        guard let s = s, !s.isEmpty else { return [] }
        return s.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
