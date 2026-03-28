import XCTest
@testable import AnvilUI
import AnvilDomain

@MainActor
final class ShipViewModelTests: XCTestCase {

    // MARK: - Helpers

    /// Create a ShipViewModel pre-loaded with sample data for tests that need it.
    private func makeVM() -> ShipViewModel {
        let vm = ShipViewModel()
        vm.loadSampleData()
        return vm
    }

    // MARK: - Init

    func testInitStartsEmpty() {
        let vm = ShipViewModel()
        XCTAssertTrue(vm.environments.isEmpty, "ShipViewModel must start with no environments")
        XCTAssertTrue(vm.deployments.isEmpty, "ShipViewModel must start with no deployments")
        XCTAssertTrue(vm.buildLogs.isEmpty, "ShipViewModel must start with no build logs")
        XCTAssertTrue(vm.envVars.isEmpty, "ShipViewModel must start with no env vars")
        XCTAssertTrue(vm.deployHistory.isEmpty, "ShipViewModel must start with no deploy history")
        XCTAssertNil(vm.selectedEnvironmentID, "ShipViewModel must start with no selected environment")
    }

    func testLoadSampleDataPopulatesAll() {
        let vm = makeVM()
        XCTAssertGreaterThan(vm.environments.count, 0)
        XCTAssertGreaterThan(vm.deployments.count, 0)
        XCTAssertGreaterThan(vm.buildLogs.count, 0)
        XCTAssertFalse(vm.envVars.isEmpty)
        XCTAssertFalse(vm.deployHistory.isEmpty)
        XCTAssertEqual(vm.selectedEnvironmentID, vm.environments.first?.id)
    }

    // MARK: - Computed Properties

    func testSelectedEnvironmentMatchesID() {
        let vm = makeVM()
        let firstID = vm.environments.first!.id
        vm.selectedEnvironmentID = firstID
        XCTAssertEqual(vm.selectedEnvironment?.id, firstID, "selectedEnvironment must return environment matching selectedEnvironmentID")
    }

    func testSelectedEnvironmentNilWhenNoSelection() {
        let vm = makeVM()
        vm.selectedEnvironmentID = nil
        XCTAssertNil(vm.selectedEnvironment, "selectedEnvironment must be nil when selectedEnvironmentID is nil")
    }

    func testDeploymentsForSelectedFiltersCorrectly() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.selectedEnvironmentID = envID
        let filtered = vm.deploymentsForSelected
        XCTAssertTrue(filtered.allSatisfy { $0.environmentId == envID },
            "deploymentsForSelected must only return deployments for the selected environment")
    }

    func testEnvVarsForSelectedReturnsCorrectVars() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.selectedEnvironmentID = envID
        let vars = vm.envVarsForSelected
        XCTAssertEqual(vars, vm.envVars[envID] ?? [], "envVarsForSelected must return vars for selected environment")
    }

    func testDeployHistoryForSelectedReturnsCorrectHistory() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.selectedEnvironmentID = envID
        let history = vm.deployHistoryForSelected
        XCTAssertEqual(history.count, vm.deployHistory[envID]?.count ?? 0,
            "deployHistoryForSelected must return all history entries for selected environment")
    }

    // MARK: - deploy()

    func testDeployStartsDeploying() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        XCTAssertFalse(vm.isDeploying, "isDeploying must be false before deploy")
        vm.deploy(environmentID: envID)
        XCTAssertTrue(vm.isDeploying, "deploy() must set isDeploying to true immediately")
    }

    func testDeploySetsDeployingEnvironmentID() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.deploy(environmentID: envID)
        XCTAssertEqual(vm.deployingEnvironmentID, envID, "deploy() must set deployingEnvironmentID")
    }

    func testDeployZerosProgress() {
        let vm = makeVM()
        vm.deployProgress = 0.5 // simulate leftover state
        let envID = vm.environments.first!.id
        vm.deploy(environmentID: envID)
        XCTAssertEqual(vm.deployProgress, 0.0, "deploy() must reset deployProgress to 0")
    }

    func testDeployMarksEnvironmentAsDeploying() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.deploy(environmentID: envID)
        let env = vm.environments.first(where: { $0.id == envID })
        XCTAssertEqual(env?.status, .deploying, "deploy() must mark environment status as .deploying")
    }

    func testDeployIsIdempotentWhileRunning() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.deploy(environmentID: envID)
        XCTAssertTrue(vm.isDeploying)
        // Second call should be ignored
        let secondEnvID = vm.environments.last?.id ?? envID
        vm.deploy(environmentID: secondEnvID)
        XCTAssertEqual(vm.deployingEnvironmentID, envID,
            "deploy() must be ignored while another deploy is in progress")
    }

    // MARK: - requestRollback / confirmRollback / cancelRollback

    func testRequestRollbackShowsConfirmation() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let historyEntry = vm.deployHistory[envID]!.first!
        XCTAssertFalse(vm.showingRollbackConfirm, "showingRollbackConfirm must be false initially")
        vm.requestRollback(deploymentID: historyEntry.id, environmentID: envID)
        XCTAssertTrue(vm.showingRollbackConfirm, "requestRollback must set showingRollbackConfirm to true")
    }

    func testRequestRollbackStoresPendingIDs() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let historyEntry = vm.deployHistory[envID]!.first!
        vm.requestRollback(deploymentID: historyEntry.id, environmentID: envID)
        XCTAssertEqual(vm.pendingRollbackDeployID, historyEntry.id)
        XCTAssertEqual(vm.pendingRollbackEnvID, envID)
    }

    func testCancelRollbackClearsConfirmation() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let historyEntry = vm.deployHistory[envID]!.first!
        vm.requestRollback(deploymentID: historyEntry.id, environmentID: envID)
        vm.cancelRollback()
        XCTAssertFalse(vm.showingRollbackConfirm, "cancelRollback must hide confirmation dialog")
        XCTAssertNil(vm.pendingRollbackDeployID, "cancelRollback must clear pendingRollbackDeployID")
        XCTAssertNil(vm.pendingRollbackEnvID, "cancelRollback must clear pendingRollbackEnvID")
    }

    func testConfirmRollbackDismissesConfirmation() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let historyEntry = vm.deployHistory[envID]!.first!
        vm.requestRollback(deploymentID: historyEntry.id, environmentID: envID)
        vm.confirmRollback()
        XCTAssertFalse(vm.showingRollbackConfirm, "confirmRollback must dismiss the confirmation dialog")
        XCTAssertNil(vm.pendingRollbackDeployID, "confirmRollback must clear pendingRollbackDeployID")
    }

    // MARK: - Env Var CRUD

    func testAddEnvVarIncreasesCount() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let before = vm.envVars[envID]?.count ?? 0
        vm.newEnvKey = "MY_KEY"
        vm.newEnvValue = "my_value"
        vm.addEnvVar(to: envID)
        XCTAssertEqual(vm.envVars[envID]?.count ?? 0, before + 1, "addEnvVar must add one env var")
    }

    func testAddEnvVarSetsKeyAndValue() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.newEnvKey = "DATABASE_POOL_SIZE"
        vm.newEnvValue = "10"
        vm.addEnvVar(to: envID)
        let added = vm.envVars[envID]!.last!
        XCTAssertEqual(added.key, "DATABASE_POOL_SIZE")
        XCTAssertEqual(added.value, "10")
    }

    func testAddEnvVarClearsInputFields() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.newEnvKey = "SOME_KEY"
        vm.newEnvValue = "some_value"
        vm.newEnvIsSecret = true
        vm.addEnvVar(to: envID)
        XCTAssertTrue(vm.newEnvKey.isEmpty, "addEnvVar must clear newEnvKey after adding")
        XCTAssertTrue(vm.newEnvValue.isEmpty, "addEnvVar must clear newEnvValue after adding")
        XCTAssertFalse(vm.newEnvIsSecret, "addEnvVar must reset newEnvIsSecret after adding")
    }

    func testAddEnvVarIgnoresEmptyKey() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let before = vm.envVars[envID]?.count ?? 0
        vm.newEnvKey = ""
        vm.newEnvValue = "value"
        vm.addEnvVar(to: envID)
        XCTAssertEqual(vm.envVars[envID]?.count ?? 0, before, "addEnvVar must ignore empty key")
    }

    func testAddEnvVarWithSecret() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        vm.newEnvKey = "SECRET_TOKEN"
        vm.newEnvValue = "super_secret"
        vm.newEnvIsSecret = true
        vm.addEnvVar(to: envID)
        XCTAssertTrue(vm.envVars[envID]!.last!.isSecret, "addEnvVar must store isSecret flag")
    }

    func testConfirmDeleteEnvVarRemovesIt() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let envVar = vm.envVars[envID]!.first!
        let before = vm.envVars[envID]!.count
        vm.requestDeleteEnvVar(id: envVar.id, from: envID)
        vm.confirmDeleteEnvVar()
        XCTAssertEqual(vm.envVars[envID]?.count, before - 1, "confirmDeleteEnvVar must remove the env var")
        XCTAssertFalse(vm.envVars[envID]!.contains(where: { $0.id == envVar.id }),
            "Deleted env var must not be present after confirmation")
    }

    func testRequestDeleteEnvVarShowsConfirmation() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let envVar = vm.envVars[envID]!.first!
        vm.requestDeleteEnvVar(id: envVar.id, from: envID)
        XCTAssertTrue(vm.showingDeleteConfirm, "requestDeleteEnvVar must show confirmation")
        XCTAssertEqual(vm.pendingDeleteEnvVarID, envVar.id)
        XCTAssertEqual(vm.pendingDeleteEnvID, envID)
    }

    func testCancelDeleteEnvVarClearsState() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let envVar = vm.envVars[envID]!.first!
        vm.requestDeleteEnvVar(id: envVar.id, from: envID)
        vm.cancelDeleteEnvVar()
        XCTAssertFalse(vm.showingDeleteConfirm, "cancelDeleteEnvVar must hide confirmation")
        XCTAssertNil(vm.pendingDeleteEnvVarID)
        XCTAssertNil(vm.pendingDeleteEnvID)
    }

    func testToggleEnvVarSecretFlipsFlag() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let envVar = vm.envVars[envID]!.first!
        let wasSeret = envVar.isSecret
        vm.toggleEnvVarSecret(id: envVar.id, in: envID)
        XCTAssertEqual(vm.envVars[envID]!.first!.isSecret, !wasSeret,
            "toggleEnvVarSecret must flip isSecret flag")
    }

    // MARK: - Editing Env Var

    func testStartEditingPopulatesFields() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let envVar = vm.envVars[envID]!.first(where: { !$0.isSecret })!
        vm.startEditingEnvVar(envVar)
        XCTAssertEqual(vm.editingEnvVarID, envVar.id, "startEditingEnvVar must set editingEnvVarID")
        XCTAssertEqual(vm.editingKey, envVar.key, "startEditingEnvVar must populate editingKey")
        XCTAssertEqual(vm.editingValue, envVar.value, "startEditingEnvVar must populate editingValue for non-secret")
    }

    func testStartEditingSecretClearsValue() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let secretVar = vm.envVars[envID]!.first(where: { $0.isSecret })!
        vm.startEditingEnvVar(secretVar)
        XCTAssertTrue(vm.editingValue.isEmpty, "startEditingEnvVar must clear editingValue for secret vars")
    }

    func testSaveEditingEnvVarUpdatesKey() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let envVar = vm.envVars[envID]!.first(where: { !$0.isSecret })!
        vm.startEditingEnvVar(envVar)
        vm.editingKey = "UPDATED_KEY"
        vm.editingValue = "new_value"
        vm.saveEditingEnvVar(in: envID)
        let updated = vm.envVars[envID]!.first(where: { $0.id == envVar.id })!
        XCTAssertEqual(updated.key, "UPDATED_KEY", "saveEditingEnvVar must update the key")
        XCTAssertEqual(updated.value, "new_value", "saveEditingEnvVar must update the value")
    }

    func testCancelEditingClearsState() {
        let vm = makeVM()
        let envID = vm.environments.first!.id
        let envVar = vm.envVars[envID]!.first!
        vm.startEditingEnvVar(envVar)
        vm.cancelEditing()
        XCTAssertNil(vm.editingEnvVarID, "cancelEditing must clear editingEnvVarID")
        XCTAssertTrue(vm.editingKey.isEmpty, "cancelEditing must clear editingKey")
    }

    // MARK: - Env Compare

    func testOpenEnvCompareSetsBothSourceAndTarget() {
        let vm = makeVM()
        vm.openEnvCompare()
        XCTAssertNotNil(vm.compareSourceID, "openEnvCompare must set compareSourceID")
        XCTAssertNotNil(vm.compareTargetID, "openEnvCompare must set compareTargetID")
        XCTAssertNotEqual(vm.compareSourceID, vm.compareTargetID,
            "openEnvCompare must choose different environments for comparison")
    }

    func testOpenEnvCompareShowsModal() {
        let vm = makeVM()
        vm.openEnvCompare()
        XCTAssertTrue(vm.showingEnvCompare, "openEnvCompare must set showingEnvCompare to true")
    }

    func testEnvCompareDataDiffersWhenEnvsAreDifferent() {
        let vm = makeVM()
        vm.openEnvCompare()
        let diffs = vm.envCompareData.filter { $0.isDifferent }
        // Production and staging have different LOG_LEVEL and other vars
        XCTAssertGreaterThan(diffs.count, 0, "envCompareData must identify at least one differing env var")
    }

    // MARK: - Log Streaming

    func testStopLogStreamingSetsIsStreamingFalse() {
        let vm = makeVM()
        vm.isStreamingLogs = true // force state
        vm.stopLogStreaming()
        XCTAssertFalse(vm.isStreamingLogs, "stopLogStreaming must set isStreamingLogs to false")
    }

    // MARK: - Static helpers

    func testMakeSampleDataReturnsNonEmptyCollections() {
        let (envs, deploys, logs, vars, history) = ShipViewModel.makeSampleData()
        XCTAssertFalse(envs.isEmpty)
        XCTAssertFalse(deploys.isEmpty)
        XCTAssertFalse(logs.isEmpty)
        XCTAssertFalse(vars.isEmpty)
        XCTAssertFalse(history.isEmpty)
    }
}
