// WorktreeResearch.swift — A1_41: read-only git research for the Meta-AI
// worktree-task proposal step ("与 Meta AI 沟通": research the project's git,
// then propose a small testable worktree).
//
// READ-ONLY: gathers current branch + recent branches + recent commits + dirty
// state via read-only git verbs (rev-parse / for-each-ref / log / status) over
// the A1_40 RepoGitRunner seam. Writes NOTHING. This is the decision-surface
// data the Meta proposal consumes; it never acts.

import Foundation

public struct WorktreeResearchContext: Equatable, Sendable {
    public let currentBranch: String
    /// Local branch names, most-recently-committed first.
    public let branches: [String]
    /// Recent commits as "shortsha subject".
    public let recentCommits: [String]
    public let dirty: Bool

    public init(currentBranch: String, branches: [String], recentCommits: [String], dirty: Bool) {
        self.currentBranch = currentBranch
        self.branches = branches
        self.recentCommits = recentCommits
        self.dirty = dirty
    }
}

public enum WorktreeResearch {
    /// Gather read-only git facts for `projectRepo`. Synchronous + blocking —
    /// callers MUST dispatch off the main thread.
    public static func gather(
        projectRepo: URL,
        branchLimit: Int = 30,
        commitLimit: Int = 15,
        runner: RepoGitRunner = LiveRepoGitRunner()
    ) throws -> WorktreeResearchContext {
        let (_, cur, _) = try runner.run(
            args: ["rev-parse", "--abbrev-ref", "HEAD"], inRepo: projectRepo)
        let (_, brOut, _) = try runner.run(
            args: ["for-each-ref", "--format=%(refname:short)", "--sort=-committerdate",
                   "--count=\(branchLimit)", "refs/heads"], inRepo: projectRepo)
        let branches = brOut.split(separator: "\n").map(String.init)
        let (_, logOut, _) = try runner.run(
            args: ["log", "--oneline", "-n", "\(commitLimit)"], inRepo: projectRepo)
        let commits = logOut.split(separator: "\n").map(String.init)
        let (_, st, _) = try runner.run(
            args: ["status", "--porcelain"], inRepo: projectRepo)
        return WorktreeResearchContext(
            currentBranch: cur,
            branches: branches,
            recentCommits: commits,
            dirty: !st.isEmpty)
    }

    /// Deterministic context string for the Meta prompt (same facts ⇒ same bytes).
    public static func contextString(_ c: WorktreeResearchContext, projectId: String) -> String {
        let branchLine = c.branches.isEmpty ? "（无）" : c.branches.joined(separator: "、")
        let commitBlock = c.recentCommits.isEmpty ? "（无）" : c.recentCommits.joined(separator: "\n")
        return """
        项目 \(projectId) 的 git 研究：
        当前分支：\(c.currentBranch)
        分支（\(c.branches.count)）：\(branchLine)
        近期提交：
        \(commitBlock)
        工作树：\(c.dirty ? "有未提交改动" : "干净")
        """
    }
}
