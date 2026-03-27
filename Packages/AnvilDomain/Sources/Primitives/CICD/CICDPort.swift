import Foundation

public protocol CICDPort: AnvilProviderDefinition {
    func pipelines(repositoryId: String) async throws -> [Pipeline]
    func pipeline(pipelineId: String) async throws -> Pipeline
    func triggerPipeline(pipelineId: String, branch: String?, parameters: [String: String]) async throws -> BuildRun
    func buildRuns(pipelineId: String, limit: Int) async throws -> [BuildRun]
    func buildRun(runId: String) async throws -> BuildRun
    func cancelBuildRun(runId: String) async throws
    func retryBuildRun(runId: String) async throws -> BuildRun
    func testResults(runId: String) async throws -> [TestResult]
}
