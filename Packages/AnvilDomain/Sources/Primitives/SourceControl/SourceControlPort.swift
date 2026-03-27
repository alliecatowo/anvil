import Foundation

public protocol SourceControlPort: AnvilProviderDefinition {
    func branches() async throws -> [Branch]
    func currentBranch() async throws -> Branch?
    func commits(branch: String, limit: Int) async throws -> [Commit]
    func diff(from: String?, to: String?) async throws -> [FileDiff]
    func stagedDiff() async throws -> [FileDiff]
    func unstagedDiff() async throws -> [FileDiff]
    func createBranch(name: String, from: String?) async throws -> Branch
    func deleteBranch(name: String, force: Bool) async throws
    func switchBranch(name: String) async throws
    func merge(source: String, into: String, strategy: MergeStrategy) async throws -> MergeResult
    func rebase(branch: String, onto: String) async throws
    func cherryPick(commit: String) async throws
    func revert(commit: String) async throws
    func blame(file: String, ref: String?) async throws -> [BlameLine]
    func fileHistory(file: String) async throws -> [Commit]
    func stash(message: String?) async throws
    func stashPop() async throws
    func stashList() async throws -> [Stash]
    func stage(paths: [String]) async throws
    func unstage(paths: [String]) async throws
    func commit(message: String) async throws -> Commit
    func createWorktree(branch: String, path: String) async throws
    func removeWorktree(path: String) async throws
    func worktrees() async throws -> [Worktree]
    func tags() async throws -> [Tag]
}
