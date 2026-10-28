//
//  CloudSyncAndCatalogSafetyTests.swift
//  AesthelityTests
//

import Foundation
import Testing
@testable import Aesthelity

@MainActor
struct CloudSyncAndCatalogSafetyTests {

    @Test func cloudSyncRemainsDisabledForThisPR() {
        #expect(CloudSyncConfiguration.isEnabled == false)
    }

    @Test func localRoutineStoreSaveDoesNotInvokeCloudSync() throws {
        CloudSyncConfiguration.resetTestCounters()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("routines.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = RoutineStore(fileURL: url)
        try store.save(RoutineRecord(name: "Local Only", period: .am))
        try store.update(RoutineRecord(id: store.routines[0].id, name: "Local Only Updated", period: .am))
        try store.delete(id: store.routines[0].id)

        #expect(CloudSyncConfiguration.syncInvocationCount == 0)
    }

    @Test func localSkinProfileSaveDoesNotInvokeCloudSync() throws {
        CloudSyncConfiguration.resetTestCounters()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("profile.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = SkinProfileStore(fileURL: url)
        var profile = SkinProfile()
        profile.setupStatus = .completed
        try store.save(profile)

        #expect(CloudSyncConfiguration.syncInvocationCount == 0)
    }

    @Test func firestoreSyncServiceNoOpsWhileDisabled() async {
        CloudSyncConfiguration.resetTestCounters()
        let before = CloudSyncConfiguration.blockedServiceCallCount

        FirestoreSyncService.shared.startRoutineListener(for: "test-user")
        await FirestoreSyncService.shared.saveRoutine(RoutineRecord(name: "x"), for: "test-user")
        await FirestoreSyncService.shared.deleteRoutine(id: UUID(), for: "test-user")
        FirestoreSyncService.shared.uploadAllLocalRoutines([RoutineRecord(name: "y")], for: "test-user")

        #expect(CloudSyncConfiguration.blockedServiceCallCount >= before + 3)
        #expect(CloudSyncConfiguration.isEnabled == false)
    }

    @Test func failedEmailSignInDoesNotReportSuccess() async {
        struct Boom: LocalizedError {
            var errorDescription: String? { "Invalid password" }
        }

        var signInCalls = 0
        let outcome = await AuthEmailSignIn.attempt(
            email: "maya@aesthelity.app",
            password: "wrong",
            isUITesting: false,
            signIn: { _, _ in
                signInCalls += 1
                throw Boom()
            }
        )

        #expect(signInCalls == 1)
        #expect(outcome == .failed(message: "Invalid password"))
        if case .succeeded = outcome {
            Issue.record("Failed sign-in must not succeed")
        }
    }

    @Test func emailSignInDoesNotAutoCreateAccountOnFailure() async {
        struct Missing: Error {}
        var signInCalls = 0
        let outcome = await AuthEmailSignIn.attempt(
            email: "new@aesthelity.app",
            password: "password123",
            isUITesting: false,
            signIn: { _, _ in
                signInCalls += 1
                throw Missing()
            }
        )
        #expect(signInCalls == 1)
        guard case .failed = outcome else {
            Issue.record("Expected failed outcome without sign-up fallback")
            return
        }
    }

    @Test func productDetailAddCreatesRoutineWhenMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("routines.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = RoutineStore(fileURL: url)
        #expect(store.routines.isEmpty)

        let productId = CatalogProductIdentity.uuid(forCatalogId: "cleanser_gel")
        let saved = try store.addProduct(
            title: "Gel Cleanser",
            subtitle: "Brand · Cleanser",
            period: .am,
            productId: productId
        )

        #expect(store.routines.count == 1)
        #expect(saved.period == .am)
        #expect(saved.steps.count == 1)
        #expect(saved.steps[0].productId == productId)
        #expect(saved.steps[0].title == "Gel Cleanser")
    }

    @Test func failedRoutineSaveSurfacesError() throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        // Parent path is a file, so createDirectory/write must fail.
        let store = RoutineStore(fileURL: blocker.appendingPathComponent("routines.json"))
        #expect(throws: (any Error).self) {
            try store.addProduct(
                title: "X",
                subtitle: "Y",
                period: .pm,
                productId: nil
            )
        }
    }

    @Test func catalogProductIdentitySurvivesDatabaseReload() throws {
        let catalog = try DemoCatalog.load()
        let sample = try #require(catalog.products.first)

        let firstDB = ProductDatabase()
        let first = firstDB.detail(forDemoProduct: sample)
        let expectedId = CatalogProductIdentity.uuid(forCatalogId: sample.id)
        #expect(first.id == expectedId)
        #expect(first.catalogId == sample.id)

        let secondDB = ProductDatabase()
        let byUUID = try #require(secondDB.detail(forId: expectedId))
        #expect(byUUID.catalogId == sample.id)
        #expect(byUUID.title == sample.name)

        let byCatalogString = try #require(secondDB.detail(forId: sample.id))
        #expect(byCatalogString.id == expectedId)
    }

    @Test func homeReflectsSavedRoutinesAndEmptyState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("routines.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = RoutineStore(fileURL: url)
        let emptyHome = ContentView(selectedPeriod: .am, routineStore: store)
        #expect(emptyHome.currentSteps.isEmpty)
        #expect(emptyHome.emptyRoutineMessage == "No AM routine steps to show yet.")

        try store.save(
            RoutineRecord(
                name: "Morning Routine",
                period: .am,
                steps: [
                    RoutineStepItem(stepNumber: 1, title: "Cleanser", subtitle: "Step 1", state: .incomplete)
                ]
            )
        )
        try store.save(
            RoutineRecord(
                name: "Evening Routine",
                period: .pm,
                steps: [
                    RoutineStepItem(stepNumber: 1, title: "Oil Cleanser", subtitle: "Step 1", state: .incomplete),
                    RoutineStepItem(stepNumber: 2, title: "Moisturizer", subtitle: "Step 2", state: .incomplete)
                ]
            )
        )

        let amHome = ContentView(selectedPeriod: .am, routineStore: store)
        #expect(amHome.currentSteps.map(\.title) == ["Cleanser"])
        #expect(amHome.emptyRoutineMessage == nil)

        let pmHome = ContentView(selectedPeriod: .pm, routineStore: store)
        #expect(pmHome.currentSteps.map(\.title) == ["Oil Cleanser", "Moisturizer"])
        #expect(pmHome.emptyRoutineMessage == nil)
    }

    @Test func homeDoesNotEditOtherPeriodWhenSelectedPeriodMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("routines.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = RoutineStore(fileURL: url)
        try store.save(
            RoutineRecord(
                name: "Evening Only",
                period: .pm,
                steps: [RoutineStepItem(stepNumber: 1, title: "Oil Cleanser", subtitle: "Step 1", state: .incomplete)]
            )
        )

        let home = ContentView(selectedPeriod: .am, routineStore: store)
        #expect(home.selectedPeriodRoutine == nil)
        #expect(home.selectedPeriodRoutine?.period != .pm)
        #expect(store.routines.first?.period == .pm)
    }

    @Test func homeUpdateFailureDoesNotFallBackToBlindSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("routines.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = RoutineStore(fileURL: url)
        let existing = RoutineRecord(name: "Morning", period: .am)
        try store.save(existing)

        // Unknown id must throw from update and must not be inserted via silent save fallback.
        let orphan = RoutineRecord(name: "Orphan", period: .am)
        #expect(throws: RoutineStore.StoreError.routineNotFound) {
            try store.update(orphan)
        }
        #expect(store.routines.count == 1)
        #expect(store.routines[0].id == existing.id)
    }

    @Test func productionHomeHidesMockCompatibilityScore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("routines.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = RoutineStore(fileURL: url)
        try store.save(
            RoutineRecord(
                name: "Morning",
                period: .am,
                steps: [RoutineStepItem(stepNumber: 1, title: "Cleanser", subtitle: "Step 1", state: .incomplete)]
            )
        )
        let productionHome = ContentView(selectedPeriod: .am, routineStore: store)
        #expect(productionHome.showsMockCompatibilityScore == false)

        let sampleHome = ContentView(
            selectedPeriod: .am,
            showClashDemo: true,
            amSteps: ContentViewStepModel.defaultAMSteps,
            amClashSteps: ContentViewStepModel.defaultAMClashSteps,
            pmSteps: ContentViewStepModel.defaultPMSteps
        )
        #expect(sampleHome.showsMockCompatibilityScore == true)
    }

    @Test func invalidSignInRetryPreservesTypedCredentials() {
        let email = "user@example.com"
        let password = "my-secret"
        let preserved = AuthEmailSignIn.credentialsPreservedForRetry(email: email, password: password)
        #expect(preserved.email == email)
        #expect(preserved.password == password)
        #expect(preserved.email != "maya@aesthelity.app")
        #expect(preserved.password != "password123")
    }

    @Test func unavailableAndPartialIngredientsAvoidBlanketSafetyClaims() {
        let unavailable = DemoProduct(
            id: "test_unavailable",
            name: "Fictional Mist",
            brand: "Test",
            category: .mist,
            subtype: "facial mist",
            ingredients: [],
            ingredientListStatus: .unavailable
        )
        let unavailableDetail = ProductDetailItem(demoProduct: unavailable)
        let unavailableGuidance = unavailableDetail.ingredientGuidance ?? ""
        #expect(unavailableGuidance.localizedCaseInsensitiveContains("unavailable"))
        #expect(!unavailableGuidance.localizedCaseInsensitiveContains("Suitable for daily"))
        #expect(unavailableDetail.routineFits.allSatisfy { $0.badgeText != "Best" && $0.badgeText != "Safe" })

        let partial = DemoProduct(
            id: "test_partial",
            name: "Fictional Serum",
            brand: "Test",
            category: .serum,
            subtype: "serum",
            ingredients: ["Water"],
            ingredientListStatus: .partial
        )
        let partialDetail = ProductDetailItem(demoProduct: partial)
        let partialGuidance = partialDetail.ingredientGuidance ?? ""
        #expect(partialGuidance.localizedCaseInsensitiveContains("partial"))
        #expect(!partialGuidance.localizedCaseInsensitiveContains("Suitable for daily"))
        #expect(partialDetail.routineFits.allSatisfy { $0.badgeText != "Best" && $0.badgeText != "Safe" })
    }
}
