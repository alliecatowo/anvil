import Foundation
import AnvilDomain

public actor GitSourceControlAdapter: SourceControlPort {
    public let providerId: String = "git"
    public let providerName: String = "Git CLI"

    private let shell: GitShell
    private let diffParser = DiffParser()

    public init(workingDirectory: String) {
        self.shell = GitShell(workingDirectory: workingDirectory)
    }

    public func validateConnection() async throws -> Bool {
        do {
            _ = try await shell.run(["rev-parse", "--git-dir"])
            return true
        } catch {
            return false
        }
    }

    // MARK: - Branches

    public func branches() async throws -> [Branch] {
        let output = try await shell.run([
            "branch", "-a",
            "--format=%(refname:short)|||%(upstream:short)|||%(upstream:track)|||%(HEAD)"
        ])
        guard !output.isEmpty else { return [] }

        return output.components(separatedBy: "\n").compactMap { line -> Branch? in
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 4 else { return nil }

            let name = parts[0].trimmingCharacters(in: .whitespaces)
            let upstream = parts[1].isEmpty ? nil : parts[1]
            let trackInfo = parts[2]
            let isCurrent = parts[3].trimmingCharacters(in: .whitespaces) == "*"

            let (ahead, behind) = parseTrackInfo(trackInfo)

            return Branch(
                name: name,
                upstream: upstream,
                aheadCount: ahead,
                behindCount: behind,
                isCurrent: isCurrent
            )
        }
    }

    public func currentBranch() async throws -> Branch? {
        let name = try await shell.run(["branch", "--show-current"])
        guard !name.isEmpty else { return nil }

        let allBranches = try await branches()
        return allBranches.first { $0.name == name }
            ?? Branch(name: name, isCurrent: true)
    }

    // MARK: - Commits

    public func commits(branch: String, limit: Int) async throws -> [Commit] {
        let format = "%H|||%h|||%aN|||%aE|||%aI|||%s|||%P"
        let output = try await shell.run([
            "log", "--format=\(format)", "-n", "\(limit)", branch
        ])
        guard !output.isEmpty else { return [] }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return output.components(separatedBy: "\n").compactMap { line -> Commit? in
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 6 else { return nil }

            let hash = parts[0]
            let shortHash = parts[1]
            let author = parts[2]
            let email = parts[3]
            let dateStr = parts[4]
            let message = parts[5]
            let parents = parts.count > 6 ? parts[6].split(separator: " ").map(String.init) : []

            let date = dateFormatter.date(from: dateStr) ?? Date()

            return Commit(
                id: hash,
                shortHash: shortHash,
                author: author,
                authorEmail: email,
                date: date,
                message: message,
                parents: parents
            )
        }
    }

    // MARK: - Diff

    public func diff(from: String?, to: String?) async throws -> [FileDiff] {
        var args = ["diff"]
        if let from = from, let to = to {
            args.append("\(from)..\(to)")
        } else if let from = from {
            args.append(from)
        }
        let output = try await shell.run(args)
        return diffParser.parse(output)
    }

    public func stagedDiff() async throws -> [FileDiff] {
        let output = try await shell.run(["diff", "--cached"])
        return diffParser.parse(output)
    }

    /// Returns the raw staged diff text (for feeding to AI models).
    public func stagedDiffRaw() async throws -> String {
        try await shell.run(["diff", "--cached"])
    }

    public func unstagedDiff() async throws -> [FileDiff] {
        let output = try await shell.run(["diff"])
        return diffParser.parse(output)
    }

    // MARK: - Remotes

    /// Returns the URL of a named remote (defaults to "origin").
    public func remoteURL(name: String = "origin") async throws -> String {
        try await shell.run(["remote", "get-url", name])
    }

    /// Fetch from a remote (defaults to "origin").
    public func fetch(remote: String = "origin") async throws {
        _ = try await shell.run(["fetch", remote])
    }

    /// Pull from a remote (defaults to "origin"), optionally rebasing.
    public func pull(remote: String = "origin", rebase: Bool = false) async throws {
        var args = ["pull"]
        if rebase { args.append("--rebase") }
        args.append(remote)
        _ = try await shell.run(args)
    }

    /// Push to a remote (defaults to "origin"). Sets upstream if needed.
    public func push(remote: String = "origin", setUpstream: Bool = false, force: Bool = false) async throws {
        var args = ["push"]
        if setUpstream {
            args += ["-u", remote]
            let branchName = try await shell.run(["branch", "--show-current"])
            args.append(branchName)
        } else {
            args.append(remote)
        }
        if force {
            args.append("--force-with-lease")
        }
        _ = try await shell.run(args)
    }

    /// Lists all configured remotes with their fetch and push URLs.
    public func listRemotes() async throws -> [GitRemote] {
        let output = try await shell.run(["remote", "-v"])
        var remotes: [String: (fetch: String, push: String)] = [:]
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "\t")
            guard parts.count == 2 else { continue }
            let name = parts[0]
            let urlAndType = parts[1]
            let url = urlAndType.components(separatedBy: " ").first ?? urlAndType
            if urlAndType.hasSuffix("(fetch)") {
                remotes[name, default: (fetch: "", push: "")].fetch = url
            } else if urlAndType.hasSuffix("(push)") {
                remotes[name, default: (fetch: "", push: "")].push = url
            }
        }
        return remotes.map { GitRemote(name: $0.key, fetchURL: $0.value.fetch, pushURL: $0.value.push) }
            .sorted { $0.name < $1.name }
    }

    /// Adds a new remote.
    public func addRemote(name: String, url: String) async throws {
        _ = try await shell.run(["remote", "add", name, url])
    }

    /// Removes a remote.
    public func removeRemote(name: String) async throws {
        _ = try await shell.run(["remote", "remove", name])
    }

    /// Renames a remote.
    public func renameRemote(oldName: String, newName: String) async throws {
        _ = try await shell.run(["remote", "rename", oldName, newName])
    }

    // MARK: - Working Tree Status

    /// Returns all changed files in the working tree (staged, unstaged, and untracked).
    public func workingTreeStatus() async throws -> [GitFileChange] {
        let output = try await shell.run(["status", "--porcelain=v1"])
        guard !output.isEmpty else { return [] }

        return output.components(separatedBy: "\n").compactMap { line -> GitFileChange? in
            guard line.count >= 4 else { return nil }

            let indexStatus = line[line.startIndex]
            let workTreeStatus = line[line.index(after: line.startIndex)]
            let filePath = String(line.dropFirst(3))

            // Determine if staged, unstaged, or both
            // Index column: staged changes; work-tree column: unstaged changes
            if indexStatus == "?" {
                // Untracked file
                return GitFileChange(filePath: filePath, status: .untracked, staged: false)
            }

            // If there's a staged change, emit a staged entry
            var changes: [GitFileChange] = []
            if indexStatus != " " && indexStatus != "?" {
                let status = parseStatusChar(indexStatus)
                changes.append(GitFileChange(filePath: filePath, status: status, staged: true))
            }
            // If there's an unstaged change, emit an unstaged entry
            if workTreeStatus != " " && workTreeStatus != "?" {
                let status = parseStatusChar(workTreeStatus)
                changes.append(GitFileChange(filePath: filePath, status: status, staged: false))
            }

            return changes.first // For compactMap; we handle both below
        }
    }

    /// Returns all changed files, properly handling files that are both staged and unstaged.
    public func workingTreeChanges() async throws -> (staged: [GitFileChange], unstaged: [GitFileChange], untracked: [GitFileChange]) {
        let output = try await shell.run(["status", "--porcelain=v1"])
        guard !output.isEmpty else { return ([], [], []) }

        var staged: [GitFileChange] = []
        var unstaged: [GitFileChange] = []
        var untracked: [GitFileChange] = []

        for line in output.components(separatedBy: "\n") {
            guard line.count >= 4 else { continue }

            let indexStatus = line[line.startIndex]
            let workTreeStatus = line[line.index(after: line.startIndex)]
            let filePath = String(line.dropFirst(3))

            if indexStatus == "?" {
                untracked.append(GitFileChange(filePath: filePath, status: .untracked, staged: false))
                continue
            }

            if indexStatus != " " {
                staged.append(GitFileChange(filePath: filePath, status: parseStatusChar(indexStatus), staged: true))
            }
            if workTreeStatus != " " {
                unstaged.append(GitFileChange(filePath: filePath, status: parseStatusChar(workTreeStatus), staged: false))
            }
        }

        return (staged, unstaged, untracked)
    }

    private func parseStatusChar(_ c: Character) -> GitFileChangeStatus {
        switch c {
        case "M": .modified
        case "A": .added
        case "D": .deleted
        case "R": .renamed
        case "C": .copied
        case "U": .unmerged
        default: .modified
        }
    }

    // MARK: - Branch operations

    @discardableResult
    public func createBranch(name: String, from: String?) async throws -> Branch {
        var args = ["checkout", "-b", name]
        if let from = from {
            args.append(from)
        }
        _ = try await shell.run(args)
        return Branch(name: name, isCurrent: true)
    }

    public func deleteBranch(name: String, force: Bool) async throws {
        let flag = force ? "-D" : "-d"
        _ = try await shell.run(["branch", flag, name])
    }

    public func switchBranch(name: String) async throws {
        _ = try await shell.run(["checkout", name])
    }

    // MARK: - Staging

    public func stage(paths: [String]) async throws {
        _ = try await shell.run(["add"] + paths)
    }

    public func unstage(paths: [String]) async throws {
        _ = try await shell.run(["restore", "--staged"] + paths)
    }

    // MARK: - Commit

    @discardableResult
    public func commit(message: String, amend: Bool = false) async throws -> Commit {
        var args = ["commit", "-m", message]
        if amend { args.append("--amend") }
        _ = try await shell.run(args)

        // Get the commit we just created
        let commits = try await commits(branch: "HEAD", limit: 1)
        guard let latest = commits.first else {
            throw GitError.parseError("Failed to read commit after creating it")
        }
        return latest
    }

    // MARK: - Blame

    public func blame(file: String, ref: String?) async throws -> [BlameLine] {
        var args = ["blame", "--porcelain"]
        if let ref = ref {
            args.append(ref)
        }
        args += ["--", file]

        let output = try await shell.run(args)
        return parseBlameOutput(output)
    }

    public func fileHistory(file: String) async throws -> [Commit] {
        let format = "%H|||%h|||%aN|||%aE|||%aI|||%s|||%P"
        let output = try await shell.run([
            "log", "--format=\(format)", "--", file
        ])
        guard !output.isEmpty else { return [] }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return output.components(separatedBy: "\n").compactMap { line -> Commit? in
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 6 else { return nil }

            return Commit(
                id: parts[0],
                shortHash: parts[1],
                author: parts[2],
                authorEmail: parts[3],
                date: dateFormatter.date(from: parts[4]) ?? Date(),
                message: parts[5],
                parents: parts.count > 6 ? parts[6].split(separator: " ").map(String.init) : []
            )
        }
    }

    // MARK: - Stash

    public func stash(message: String?) async throws {
        var args = ["stash", "push"]
        if let message = message {
            args += ["-m", message]
        }
        _ = try await shell.run(args)
    }

    public func stashPop() async throws {
        _ = try await shell.run(["stash", "pop"])
    }

    public func stashApply(index: Int) async throws {
        _ = try await shell.run(["stash", "apply", "stash@{\(index)}"])
    }

    public func stashDrop(index: Int) async throws {
        _ = try await shell.run(["stash", "drop", "stash@{\(index)}"])
    }

    public func stashList() async throws -> [Stash] {
        let output = try await shell.run(["stash", "list", "--format=%gd|||%gs|||%aI"])
        guard !output.isEmpty else { return [] }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return output.components(separatedBy: "\n").enumerated().compactMap { index, line -> Stash? in
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 3 else { return nil }

            return Stash(
                index: index,
                message: parts[1],
                date: dateFormatter.date(from: parts[2]) ?? Date()
            )
        }
    }

    // MARK: - Tags

    @discardableResult
    public func createTag(name: String, message: String? = nil, commit: String? = nil) async throws -> Tag {
        var args = ["tag"]
        if let message = message {
            args += ["-a", name, "-m", message]
        } else {
            args.append(name)
        }
        if let commit = commit {
            args.append(commit)
        }
        _ = try await shell.run(args)

        // Read back the tag we just created
        let allTags = try await tags()
        return allTags.first { $0.name == name }
            ?? Tag(name: name, targetCommit: commit ?? "HEAD")
    }

    public func deleteTag(name: String) async throws {
        _ = try await shell.run(["tag", "-d", name])
    }

    public func tags() async throws -> [Tag] {
        let output = try await shell.run([
            "tag", "-l", "--format=%(refname:short)|||%(objectname:short)|||%(contents:subject)|||%(creatordate:iso-strict)"
        ])
        guard !output.isEmpty else { return [] }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return output.components(separatedBy: "\n").compactMap { line -> Tag? in
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 2 else { return nil }

            let name = parts[0]
            let commit = parts[1]
            let annotation = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
            let date = parts.count > 3 ? dateFormatter.date(from: parts[3]) : nil

            return Tag(name: name, targetCommit: commit, annotation: annotation, date: date)
        }
    }

    // MARK: - Worktrees

    public func worktrees() async throws -> [Worktree] {
        let output = try await shell.run(["worktree", "list", "--porcelain"])
        guard !output.isEmpty else { return [] }

        return parseWorktreeOutput(output)
    }

    public func createWorktree(branch: String, path: String) async throws {
        _ = try await shell.run(["worktree", "add", path, branch])
    }

    public func removeWorktree(path: String) async throws {
        _ = try await shell.run(["worktree", "remove", path])
    }

    // MARK: - Merge / Rebase / Cherry-pick / Revert

    public func merge(source: String, into: String, strategy: MergeStrategy) async throws -> MergeResult {
        // Switch to the target branch first
        _ = try await shell.run(["checkout", into])

        var args = ["merge"]
        switch strategy {
        case .squash:
            args.append("--squash")
        case .fastForward:
            args.append("--ff-only")
        case .rebase:
            // For rebase strategy, use rebase instead
            try await rebase(branch: into, onto: source)
            let commits = try await commits(branch: "HEAD", limit: 1)
            guard let latest = commits.first else {
                return .alreadyUpToDate
            }
            return .success(commit: latest)
        case .merge:
            args.append("--no-ff")
        }
        args.append(source)

        do {
            let output = try await shell.run(args)
            if output.contains("Already up to date") {
                return .alreadyUpToDate
            }

            if strategy == .squash {
                // Squash merge requires a separate commit
                let commit = try await commit(message: "Squash merge \(source) into \(into)")
                return .success(commit: commit)
            }

            let commits = try await commits(branch: "HEAD", limit: 1)
            guard let latest = commits.first else {
                return .alreadyUpToDate
            }
            return .success(commit: latest)
        } catch let error as GitError {
            // Check for merge conflicts
            if case .commandFailed(_, _, let stderr) = error,
               stderr.contains("CONFLICT") || stderr.contains("Automatic merge failed") {
                let conflicts = try await parseMergeConflicts()
                return .conflicts(conflicts)
            }
            throw error
        }
    }

    public func rebase(branch: String, onto: String) async throws {
        _ = try await shell.run(["rebase", onto, branch])
    }

    public func cherryPick(commit: String) async throws {
        _ = try await shell.run(["cherry-pick", commit])
    }

    public func revert(commit: String) async throws {
        _ = try await shell.run(["revert", "--no-edit", commit])
    }

    // MARK: - Private helpers

    private func parseTrackInfo(_ info: String) -> (ahead: Int, behind: Int) {
        var ahead = 0
        var behind = 0

        if let aheadRange = info.range(of: #"ahead (\d+)"#, options: .regularExpression) {
            let match = info[aheadRange]
            let numStr = match.split(separator: " ").last.map(String.init) ?? "0"
            ahead = Int(numStr) ?? 0
        }
        if let behindRange = info.range(of: #"behind (\d+)"#, options: .regularExpression) {
            let match = info[behindRange]
            let numStr = match.split(separator: " ").last.map(String.init) ?? "0"
            behind = Int(numStr) ?? 0
        }

        return (ahead, behind)
    }

    private func parseBlameOutput(_ output: String) -> [BlameLine] {
        var blameLines: [BlameLine] = []
        let lines = output.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let headerParts = line.split(separator: " ")
            guard headerParts.count >= 3 else { i += 1; continue }

            let commitHash = String(headerParts[0])
            guard commitHash.count >= 7 else { i += 1; continue }

            let lineNumber = Int(String(headerParts[2])) ?? 0

            var author = ""
            var date = Date()
            var content = ""
            i += 1

            while i < lines.count {
                let currentLine = lines[i]
                if currentLine.hasPrefix("author ") {
                    author = String(currentLine.dropFirst("author ".count))
                } else if currentLine.hasPrefix("author-time ") {
                    let timestamp = TimeInterval(String(currentLine.dropFirst("author-time ".count))) ?? 0
                    date = Date(timeIntervalSince1970: timestamp)
                } else if currentLine.hasPrefix("\t") {
                    content = String(currentLine.dropFirst())
                    i += 1
                    break
                }
                i += 1
            }

            blameLines.append(BlameLine(
                lineNumber: lineNumber,
                commitHash: commitHash,
                author: author,
                date: date,
                content: content
            ))
        }

        return blameLines
    }

    private func parseWorktreeOutput(_ output: String) -> [Worktree] {
        var worktrees: [Worktree] = []
        let blocks = output.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            var path = ""
            var branch: String?
            var isMain = false

            for line in lines {
                if line.hasPrefix("worktree ") {
                    path = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("branch ") {
                    let ref = String(line.dropFirst("branch ".count))
                    branch = ref.replacingOccurrences(of: "refs/heads/", with: "")
                    if branch == "main" || branch == "master" {
                        isMain = true
                    }
                }
            }

            guard !path.isEmpty else { continue }

            worktrees.append(Worktree(
                path: path,
                branch: branch,
                isClean: true,
                isMain: isMain
            ))
        }

        return worktrees
    }

    private func parseMergeConflicts() async throws -> [MergeConflict] {
        let output = try await shell.run(["diff", "--name-only", "--diff-filter=U"])
        guard !output.isEmpty else { return [] }

        return output.components(separatedBy: "\n").map { file in
            MergeConflict(
                filePath: file,
                oursContent: "",
                theirsContent: "",
                baseContent: nil
            )
        }
    }
}
