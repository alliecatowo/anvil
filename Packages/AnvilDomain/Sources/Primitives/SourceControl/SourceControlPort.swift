import Foundation

public protocol SourceControlPort: AnvilProviderDefinition {
    // MARK: - Branches
    func branches() async throws -> [Branch]
    func currentBranch() async throws -> Branch?
    func createBranch(name: String, from: String?) async throws -> Branch
    func deleteBranch(name: String, force: Bool) async throws
    func switchBranch(name: String) async throws

    // MARK: - Commits
    func commits(branch: String, limit: Int) async throws -> [Commit]
    func commit(message: String, amend: Bool) async throws -> Commit

    // MARK: - Staging
    func stage(paths: [String]) async throws
    func unstage(paths: [String]) async throws

    // MARK: - Diff
    func diff(from: String?, to: String?) async throws -> [FileDiff]
    func stagedDiff() async throws -> [FileDiff]
    func unstagedDiff() async throws -> [FileDiff]

    // MARK: - Working Tree
    func workingTreeStatus() async throws -> [GitFileChange]
    func workingTreeChanges() async throws -> (staged: [GitFileChange], unstaged: [GitFileChange], untracked: [GitFileChange])

    // MARK: - Remote Sync
    func fetch(remote: String) async throws
    func pull(remote: String, rebase: Bool) async throws
    func push(remote: String, setUpstream: Bool, force: Bool) async throws

    // MARK: - Remotes
    func listRemotes() async throws -> [GitRemote]
    func addRemote(name: String, url: String) async throws
    func removeRemote(name: String) async throws
    func renameRemote(oldName: String, newName: String) async throws

    // MARK: - Merge / Rebase / Cherry-pick / Revert
    func merge(source: String, into: String, strategy: MergeStrategy) async throws -> MergeResult
    func rebase(branch: String, onto: String) async throws
    func cherryPick(commit: String) async throws
    func revert(commit: String) async throws

    // MARK: - Blame / History
    func blame(file: String, ref: String?) async throws -> [BlameLine]
    func fileHistory(file: String) async throws -> [Commit]

    // MARK: - Stash
    func stash(message: String?) async throws
    func stashPop() async throws
    func stashApply(index: Int) async throws
    func stashDrop(index: Int) async throws
    func stashList() async throws -> [Stash]

    // MARK: - Tags
    func tags() async throws -> [Tag]
    func createTag(name: String, message: String?, commit: String?) async throws -> Tag
    func deleteTag(name: String) async throws

    // MARK: - Worktrees
    func createWorktree(branch: String, path: String) async throws
    func removeWorktree(path: String) async throws
    func worktrees() async throws -> [Worktree]
}
