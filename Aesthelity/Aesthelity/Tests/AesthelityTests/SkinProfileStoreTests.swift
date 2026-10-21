import Foundation
import Testing
@testable import Aesthelity

@MainActor
struct SkinProfileStoreTests {
    private func withFile(_ test: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(directory.appendingPathComponent("profile.json"))
    }

    @Test func completedProfileReloadsWithChoicesAndWarnings() throws {
        try withFile { url in
            let normalizer = IngredientNormalizer(catalog: try .loadBundled())
            let profile = SkinProfile(skinType: .dry, concerns: [.barrierRepair],
                                      avoidedIngredients: normalizer.normalize(["Parfum", "Vitamin C"]),
                                      setupStatus: .completed)
            let store = SkinProfileStore(fileURL: url)
            #expect(store.profile.setupStatus == .notStarted)
            try store.save(profile)
            #expect(store.profile == profile)
            #expect(SkinProfileStore(fileURL: url).profile == profile)
        }
    }

    @Test func skippedProfileReloadsAsIncomplete() throws {
        try withFile { url in
            try SkinProfileStore(fileURL: url).save(.skipped)
            let restored = SkinProfileStore(fileURL: url)
            #expect(restored.profile == .skipped)
            #expect(!restored.profile.isComplete)
        }
    }

    @Test func invalidAndFutureFilesRemainIntactUntilAnExplicitSave() throws {
        try withFile { url in
            let malformedIngredientID = Data("""
            {"schemaVersion":1,"skinType":"dry","concerns":["barrier-repair"],"setupStatus":"completed","avoidedIngredients":[
              {"originalText":"Water","mapping":"confirmed","ingredientID":"   "}
            ]}
            """.utf8)
            let payloads = [
                Data("invalid json".utf8),
                try JSONEncoder().encode(SkinProfile(schemaVersion: 2)),
                malformedIngredientID,
            ]
            for data in payloads {
                try data.write(to: url)
                let store = SkinProfileStore(fileURL: url)
                #expect(store.loadError == "Your saved profile could not be loaded. You can complete setup again.")
                #expect(store.profile.setupStatus == .notStarted)
                #expect(try Data(contentsOf: url) == data)
                try store.save(.skipped)
                #expect(store.loadError == nil)
            }
        }
    }

    @Test func failedSaveDoesNotPublishAnUnsavedProfile() throws {
        try withFile { url in
            try Data("not a directory".utf8).write(to: url)
            let store = SkinProfileStore(fileURL: url.appendingPathComponent("profile.json"))
            #expect(throws: (any Error).self) { try store.save(.skipped) }
            #expect(store.profile.setupStatus == .notStarted)
        }
    }
}
