import Foundation

public protocol SourceControlCloudPort: AnvilProviderDefinition {
    func repositories() async throws -> [RemoteRepo]
    func pullRequests(repo: String, status: PRStatus?) async throws -> [PullRequest]
    func pullRequestDetail(repo: String, number: Int) async throws -> PullRequest
    func createPullRequest(repo: String, title: String, body: String, source: String, target: String, isDraft: Bool) async throws -> PullRequest
    func mergePullRequest(repo: String, number: Int, strategy: MergeStrategy) async throws
    func closePullRequest(repo: String, number: Int) async throws
    func pullRequestComments(repo: String, number: Int) async throws -> [PRComment]
    func addComment(repo: String, prNumber: Int, body: String, file: String?, line: Int?) async throws -> PRComment
    func ciStatus(repo: String, prNumber: Int) async throws -> [CICheck]
    func push(remote: String, branch: String, force: Bool) async throws
    func pull(remote: String, branch: String) async throws
    func fetch(remote: String) async throws
}
