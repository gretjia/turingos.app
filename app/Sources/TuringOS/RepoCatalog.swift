// The Select screen's single list (A1_07): GitHub repos (when connected)
// merged with locally discovered clones by normalized remote identity.
// One row per repo, one sentence of recency - no metric grids (三定律).

import Foundation

public struct CatalogItem: Identifiable, Equatable, Sendable {
    /// Identity includes the local path when present (S-stage risk: two
    /// clones of one remote must be two selectable rows, never one id).
    public var id: String {
        if let localPath { return "\(remoteKey ?? "local")@\(localPath)" }
        return remoteKey ?? "local:\(displayName)"
    }
    public let displayName: String
    public let remoteKey: String?
    public let localPath: String?
    public let pushedAt: Date?

    /// The one recency/locality sentence for the row (语言优先).
    public var sentence: String {
        switch (localPath != nil, pushedAt) {
        case (true, .some(let d)): "本地有 clone · 最近推送 \(Self.humanize(d))"
        case (true, .none): "本地 clone（未关联 GitHub）"
        case (false, .some(let d)): "仅远程 · 最近推送 \(Self.humanize(d))"
        case (false, .none): "仅远程"
        }
    }

    static func humanize(_ date: Date, now: Date = Date()) -> String {
        let days = Int(now.timeIntervalSince(date) / 86_400)
        switch days {
        case ..<1: return "今天"
        case 1: return "昨天"
        case 2...30: return "\(days) 天前"
        case 31...365: return "\(days / 30) 个月前"
        default: return "\(days / 365) 年前"
        }
    }
}

public enum RepoCatalog {
    /// Conventional roots (R1_auth_memo §4 + on-machine probe: 25ms, no TCC
    /// friction - these are NOT Desktop/Documents/Downloads). Extra roots
    /// come from the user via NSOpenPanel later (user-intent path).
    public static var conventionalRoots: [String] {
        ["Developer", "Projects", "src", "code", "workspace"]
            .map { "\(NSHomeDirectory())/\($0)" }
    }

    /// Discover local main worktrees: a MAIN clone's `.git` is a DIRECTORY;
    /// linked worktrees have a `.git` FILE (R1_memo §1.5) and are skipped -
    /// the daemon enumerates those itself.
    public static func discoverLocal(
        roots: [String] = conventionalRoots,
        maxDepth: Int = 4
    ) -> [(path: String, remote: String?)] {
        var found: [(String, String?)] = []
        let fm = FileManager.default
        for root in roots where fm.fileExists(atPath: root) {
            scan(dir: root, depth: 0, maxDepth: maxDepth, fm: fm, into: &found)
        }
        return found.sorted { $0.0 < $1.0 }
    }

    private static let skipNames: Set<String> = [
        "node_modules", ".build", "target", "Library", ".Trash", "dist",
    ]

    private static func scan(
        dir: String,
        depth: Int,
        maxDepth: Int,
        fm: FileManager,
        into found: inout [(String, String?)]
    ) {
        var isDir: ObjCBool = false
        let gitPath = "\(dir)/.git"
        if fm.fileExists(atPath: gitPath, isDirectory: &isDir) {
            if isDir.boolValue {
                found.append((dir, originRemote(of: dir)))
            }
            return // a repo (main or linked) - never descend inside
        }
        guard depth < maxDepth,
              let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries where !entry.hasPrefix(".") && !skipNames.contains(entry) {
            let child = "\(dir)/\(entry)"
            // Never follow symlinked directories (S-stage risk: an
            // ancestor-pointing symlink multiplies the walk and yields the
            // same physical clone under several paths).
            if let attrs = try? fm.attributesOfItem(atPath: child),
               attrs[.type] as? FileAttributeType == .typeSymbolicLink {
                continue
            }
            var childIsDir: ObjCBool = false
            if fm.fileExists(atPath: child, isDirectory: &childIsDir), childIsDir.boolValue {
                scan(dir: child, depth: depth + 1, maxDepth: maxDepth, fm: fm, into: &found)
            }
        }
    }

    static func originRemote(of repo: String) -> String? {
        guard let (code, out, _) = try? SystemProcessRunner().run(
            "/usr/bin/git", ["-C", repo, "config", "--get", "remote.origin.url"]
        ), code == 0 else { return nil }
        return String(data: out, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Merge GitHub listing with local discovery by normalized remote key.
    /// Every on-disk clone keeps its own row (S-stage risk: the old
    /// last-write-wins byKey overwrite silently dropped a second clone of
    /// the same remote - a partial world).
    public static func merge(
        gitHub: [GitHubRepo],
        local: [(path: String, remote: String?)]
    ) -> [CatalogItem] {
        var byKey: [String: CatalogItem] = [:]
        var localOnly: [CatalogItem] = []

        for repo in gitHub {
            guard let key = normalizeGitHubRemote(repo.cloneUrl) else { continue }
            byKey[key] = CatalogItem(
                displayName: repo.fullName,
                remoteKey: key,
                localPath: nil,
                pushedAt: repo.pushedAt
            )
        }
        for (path, remote) in local {
            let key = remote.flatMap(normalizeGitHubRemote)
            if let key, let existing = byKey[key] {
                if existing.localPath == nil {
                    byKey[key] = CatalogItem(
                        displayName: existing.displayName,
                        remoteKey: key,
                        localPath: path,
                        pushedAt: existing.pushedAt
                    )
                } else {
                    // an additional clone of the same remote: its own row
                    localOnly.append(CatalogItem(
                        displayName: existing.displayName,
                        remoteKey: key,
                        localPath: path,
                        pushedAt: existing.pushedAt
                    ))
                }
            } else {
                localOnly.append(CatalogItem(
                    displayName: URL(fileURLWithPath: path).lastPathComponent,
                    remoteKey: key,
                    localPath: path,
                    pushedAt: nil
                ))
            }
        }
        // Local clones first (they are radar-able today), then remote-only
        // by recency - the list's order IS the triage (注意力优先).
        let merged = byKey.values.sorted {
            switch ($0.localPath != nil, $1.localPath != nil) {
            case (true, false): return true
            case (false, true): return false
            default: return ($0.pushedAt ?? .distantPast) > ($1.pushedAt ?? .distantPast)
            }
        }
        return localOnly.sorted { $0.displayName < $1.displayName } + merged
    }
}

// MARK: - GitHub REST (only reached at L-gh; verified shapes from probes)

public struct GitHubRepo: Equatable, Sendable {
    public let fullName: String
    public let cloneUrl: String
    public let pushedAt: Date?

    public init(fullName: String, cloneUrl: String, pushedAt: Date?) {
        self.fullName = fullName
        self.cloneUrl = cloneUrl
        self.pushedAt = pushedAt
    }
}

public enum GitHubAPI {
    /// Parse one /user/repos page (fields live-verified 2026-06-10).
    public static func parseRepoPage(_ data: Data) throws -> [GitHubRepo] {
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        let iso = ISO8601DateFormatter()
        return arr.compactMap { obj in
            guard let fullName = obj["full_name"] as? String,
                  let cloneUrl = obj["clone_url"] as? String else { return nil }
            return GitHubRepo(
                fullName: fullName,
                cloneUrl: cloneUrl,
                pushedAt: (obj["pushed_at"] as? String).flatMap(iso.date(from:))
            )
        }
    }

    /// RFC5988 Link header -> next page URL (pagination per memo §3).
    public static func nextLink(fromLinkHeader header: String?) -> URL? {
        guard let header else { return nil }
        for part in header.split(separator: ",") {
            let segments = part.split(separator: ";").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard segments.count >= 2,
                  segments.dropFirst().contains(#"rel="next""#),
                  segments[0].hasPrefix("<"), segments[0].hasSuffix(">")
            else { continue }
            return URL(string: String(segments[0].dropFirst().dropLast()))
        }
        return nil
    }

    /// Fetch the user's repos. Network failure is a visible error; hitting
    /// the page cap with more pages remaining is a visible TRUNCATION flag
    /// (S-stage risk: a capped loop that returns the same shape as a
    /// complete one IS a silent partial world).
    public static func listAllRepos(
        token: String,
        pageCap: Int = 30
    ) async throws -> (repos: [GitHubRepo], truncated: Bool) {
        var url: URL? = URL(string:
            "https://api.github.com/user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=pushed")!
        var all: [GitHubRepo] = []
        var pages = 0
        while let current = url, pages < pageCap {
            pages += 1
            var req = URLRequest(url: current)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.userAuthenticationRequired)
            }
            all += try parseRepoPage(data)
            url = nextLink(fromLinkHeader: http.value(forHTTPHeaderField: "Link"))
        }
        return (all, truncated: url != nil)
    }
}
