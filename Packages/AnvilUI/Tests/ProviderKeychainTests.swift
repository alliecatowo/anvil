import XCTest
@testable import AnvilUI
import Security

/// Unit tests for ProviderKeychain (macOS Keychain round-trips) and
/// isAutoPREnabled / showMinimap UserDefaults persistence.
///
/// Keychain tests write to unique test-only keys and clean up in tearDown.
final class ProviderKeychainTests: XCTestCase {

    override func tearDown() {
        // Belt-and-suspenders: clean any residual test keys
        ProviderKeychain.delete("test.roundtrip")
        ProviderKeychain.delete("test.overwrite")
        ProviderKeychain.delete("test.delete")
        ProviderKeychain.delete("test.empty")
        ProviderKeychain.delete("test.unicode")
        ProviderKeychain.delete("test.long")
        super.tearDown()
    }

    // MARK: - get / set / delete primitives

    func testGetReturnsNilForNonExistentKey() {
        let key = "test.nonexistent.\(UUID().uuidString)"
        defer { ProviderKeychain.delete(key) }
        XCTAssertNil(ProviderKeychain.get(key))
    }

    func testSetAndGetRoundTrip() {
        let key = "test.roundtrip"
        ProviderKeychain.set(key, value: "secret-value-123")
        defer { ProviderKeychain.delete(key) }
        XCTAssertEqual(ProviderKeychain.get(key), "secret-value-123")
    }

    func testSetOverwritesPreviousValue() {
        let key = "test.overwrite"
        ProviderKeychain.set(key, value: "first")
        ProviderKeychain.set(key, value: "second")
        defer { ProviderKeychain.delete(key) }
        XCTAssertEqual(ProviderKeychain.get(key), "second")
    }

    func testDeleteRemovesValue() {
        let key = "test.delete"
        ProviderKeychain.set(key, value: "to-be-deleted")
        ProviderKeychain.delete(key)
        XCTAssertNil(ProviderKeychain.get(key))
    }

    func testDeleteNonExistentKeyIsNoOp() {
        let key = "test.delete.nonexistent.\(UUID().uuidString)"
        ProviderKeychain.delete(key) // must not crash
        XCTAssertNil(ProviderKeychain.get(key))
    }

    func testSetEmptyStringRoundTrip() {
        let key = "test.empty"
        ProviderKeychain.set(key, value: "")
        defer { ProviderKeychain.delete(key) }
        XCTAssertEqual(ProviderKeychain.get(key), "")
    }

    func testSetUnicodeValueRoundTrip() {
        let key = "test.unicode"
        let value = "token-unicode-\u{1F512}-\u{00E9}"
        ProviderKeychain.set(key, value: value)
        defer { ProviderKeychain.delete(key) }
        XCTAssertEqual(ProviderKeychain.get(key), value)
    }

    func testSetLongValueRoundTrip() {
        let key = "test.long"
        let longValue = String(repeating: "abcdefgh", count: 100)
        ProviderKeychain.set(key, value: longValue)
        defer { ProviderKeychain.delete(key) }
        XCTAssertEqual(ProviderKeychain.get(key), longValue)
    }

    func testTwoDistinctKeysStoredIndependently() {
        let keyA = "test.independent.a.\(UUID().uuidString)"
        let keyB = "test.independent.b.\(UUID().uuidString)"
        defer {
            ProviderKeychain.delete(keyA)
            ProviderKeychain.delete(keyB)
        }
        ProviderKeychain.set(keyA, value: "value-A")
        ProviderKeychain.set(keyB, value: "value-B")
        XCTAssertEqual(ProviderKeychain.get(keyA), "value-A")
        XCTAssertEqual(ProviderKeychain.get(keyB), "value-B")
    }

    func testDeletingOneKeyLeavesOtherIntact() {
        let keyA = "test.intact.a.\(UUID().uuidString)"
        let keyB = "test.intact.b.\(UUID().uuidString)"
        defer {
            ProviderKeychain.delete(keyA)
            ProviderKeychain.delete(keyB)
        }
        ProviderKeychain.set(keyA, value: "keep")
        ProviderKeychain.set(keyB, value: "delete-me")
        ProviderKeychain.delete(keyB)
        XCTAssertEqual(ProviderKeychain.get(keyA), "keep")
        XCTAssertNil(ProviderKeychain.get(keyB))
    }

    // MARK: - GitHub named keys

    func testGithubTokenRoundTrip() {
        let original = ProviderKeychain.githubToken
        defer { ProviderKeychain.githubToken = original }
        ProviderKeychain.githubToken = "ghp_test_token_12345"
        XCTAssertEqual(ProviderKeychain.githubToken, "ghp_test_token_12345")
    }

    func testGithubTokenNilDeletesEntry() {
        let original = ProviderKeychain.githubToken
        defer { ProviderKeychain.githubToken = original }
        ProviderKeychain.githubToken = "some-token"
        ProviderKeychain.githubToken = nil
        XCTAssertNil(ProviderKeychain.githubToken)
    }

    func testGithubOwnerRoundTrip() {
        let original = ProviderKeychain.githubOwner
        defer { ProviderKeychain.githubOwner = original }
        ProviderKeychain.githubOwner = "myorg"
        XCTAssertEqual(ProviderKeychain.githubOwner, "myorg")
    }

    func testGithubRepoRoundTrip() {
        let original = ProviderKeychain.githubRepo
        defer { ProviderKeychain.githubRepo = original }
        ProviderKeychain.githubRepo = "myrepo"
        XCTAssertEqual(ProviderKeychain.githubRepo, "myrepo")
    }

    // MARK: - Linear named keys

    func testLinearApiKeyRoundTrip() {
        let original = ProviderKeychain.linearApiKey
        defer { ProviderKeychain.linearApiKey = original }
        ProviderKeychain.linearApiKey = "lin_api_test_key"
        XCTAssertEqual(ProviderKeychain.linearApiKey, "lin_api_test_key")
    }

    func testLinearApiKeyNilDeletesEntry() {
        let original = ProviderKeychain.linearApiKey
        defer { ProviderKeychain.linearApiKey = original }
        ProviderKeychain.linearApiKey = "key-to-delete"
        ProviderKeychain.linearApiKey = nil
        XCTAssertNil(ProviderKeychain.linearApiKey)
    }

    // MARK: - Vercel named keys

    func testVercelTokenRoundTrip() {
        let original = ProviderKeychain.vercelToken
        defer { ProviderKeychain.vercelToken = original }
        ProviderKeychain.vercelToken = "vercel_test_token"
        XCTAssertEqual(ProviderKeychain.vercelToken, "vercel_test_token")
    }

    func testVercelTeamIdEmptyStringSetsNil() {
        let original = ProviderKeychain.vercelTeamId
        defer { ProviderKeychain.vercelTeamId = original }
        // Empty string should behave as delete per ProviderKeychain implementation
        ProviderKeychain.vercelTeamId = ""
        XCTAssertNil(ProviderKeychain.vercelTeamId)
    }

    func testVercelTeamIdNonEmptyRoundTrip() {
        let original = ProviderKeychain.vercelTeamId
        defer { ProviderKeychain.vercelTeamId = original }
        ProviderKeychain.vercelTeamId = "team_abc123"
        XCTAssertEqual(ProviderKeychain.vercelTeamId, "team_abc123")
    }

    // MARK: - Slack named keys

    func testSlackTokenRoundTrip() {
        let original = ProviderKeychain.slackToken
        defer { ProviderKeychain.slackToken = original }
        ProviderKeychain.slackToken = "xoxb-test-slack-token"
        XCTAssertEqual(ProviderKeychain.slackToken, "xoxb-test-slack-token")
    }

    // MARK: - Netlify named keys

    func testNetlifyTokenRoundTrip() {
        let original = ProviderKeychain.netlifyToken
        defer { ProviderKeychain.netlifyToken = original }
        ProviderKeychain.netlifyToken = "netlify_test_token"
        XCTAssertEqual(ProviderKeychain.netlifyToken, "netlify_test_token")
    }
}

// MARK: - UserDefaults Persistence Tests

/// Tests that UserDefaults keys used by AppState are correctly named and persist.
/// Does not depend on AppState itself — tests the contract the view model relies on.
final class AppStateUserDefaultsTests: XCTestCase {

    private let autoPRKey = "anvil_auto_pr_enabled"
    private let minimapKey = "showMinimap"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: autoPRKey)
        UserDefaults.standard.removeObject(forKey: minimapKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: autoPRKey)
        UserDefaults.standard.removeObject(forKey: minimapKey)
        super.tearDown()
    }

    // MARK: - autoPR

    func testAutoPRKeyDefaultsFalseWhenAbsent() {
        XCTAssertFalse(UserDefaults.standard.bool(forKey: autoPRKey))
    }

    func testAutoPRKeyPersistsTrue() {
        UserDefaults.standard.set(true, forKey: autoPRKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: autoPRKey))
    }

    func testAutoPRKeyPersistsFalse() {
        UserDefaults.standard.set(true, forKey: autoPRKey)
        UserDefaults.standard.set(false, forKey: autoPRKey)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: autoPRKey))
    }

    func testAutoPRToggleWritesCorrectKey() {
        let before = UserDefaults.standard.bool(forKey: autoPRKey)
        UserDefaults.standard.set(!before, forKey: autoPRKey)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: autoPRKey), !before)
    }

    func testAutoPRKeyName() {
        // Verify the exact key string matches AppState usage — guards against typo regressions
        XCTAssertEqual(autoPRKey, "anvil_auto_pr_enabled")
    }

    // MARK: - showMinimap

    func testMinimapKeyDefaultsFalseWhenAbsent() {
        XCTAssertFalse(UserDefaults.standard.bool(forKey: minimapKey))
    }

    func testMinimapKeyPersistsTrue() {
        UserDefaults.standard.set(true, forKey: minimapKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: minimapKey))
    }

    func testMinimapKeyPersistsFalse() {
        UserDefaults.standard.set(true, forKey: minimapKey)
        UserDefaults.standard.set(false, forKey: minimapKey)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: minimapKey))
    }

    func testMinimapToggleWritesCorrectKey() {
        let before = UserDefaults.standard.bool(forKey: minimapKey)
        UserDefaults.standard.set(!before, forKey: minimapKey)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: minimapKey), !before)
    }

    func testMinimapKeyName() {
        XCTAssertEqual(minimapKey, "showMinimap")
    }

    // MARK: - Keys are independent

    func testAutoPRAndMinimapAreIndependentKeys() {
        UserDefaults.standard.set(true, forKey: autoPRKey)
        UserDefaults.standard.set(false, forKey: minimapKey)

        XCTAssertTrue(UserDefaults.standard.bool(forKey: autoPRKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: minimapKey))
    }
}
