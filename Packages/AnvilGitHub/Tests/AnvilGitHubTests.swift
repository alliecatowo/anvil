import Testing
@testable import AnvilGitHub

@Test func adapterHasCorrectProviderInfo() {
    // Basic smoke test — adapter can be instantiated
    let adapter = GitHubSourceControlCloudAdapter(token: "test-token")
    // Actor properties need async access
    Task {
        let id = await adapter.providerId
        let name = await adapter.providerName
        #expect(id == "github")
        #expect(name == "GitHub")
    }
}
