import Foundation
import Testing
@testable import Aesthelity

struct SkinProfileTests {
    @Test func newAndSkippedProfilesRemainDistinctAfterEncoding() throws {
        let newProfile = try roundTrip(SkinProfile())
        let skippedProfile = try roundTrip(SkinProfile.skipped)

        #expect(newProfile.setupStatus == .notStarted)
        #expect(skippedProfile.setupStatus == .skipped)
        for profile in [newProfile, skippedProfile] {
            #expect(profile.schemaVersion == 1)
            #expect(!profile.isComplete)
            #expect(profile.skinType == nil)
            #expect(profile.concerns.isEmpty)
            #expect(profile.avoidedIngredients.isEmpty)
        }
    }

    @Test func selectedValuesAndNormalizationResultsSurviveEncoding() throws {
        let normalizer = IngredientNormalizer(catalog: try .loadBundled())
        let inputs = ["Parfum", "Niacinimide", "Vitamin C", "Unobtainium Extract"]
        let profile = SkinProfile(
            skinType: .combination,
            concerns: [.acneProne, .sensitivityAndRedness],
            avoidedIngredients: normalizer.normalize(inputs),
            setupStatus: .completed
        )

        let restored = try roundTrip(profile)

        #expect(restored == profile)
        #expect(restored.schemaVersion == 1)
        #expect(restored.isComplete)
        #expect(restored.avoidedIngredients.map(\.originalText) == inputs)
        #expect(restored.avoidedIngredients.map(\.ingredientID) == ["fragrance", nil, nil, nil])
        #expect(restored.avoidedIngredients.map(\.needsReview) == [false, true, true, true])
        #expect(restored.avoidedIngredients.warnings.map(\.input) == Array(inputs.dropFirst()))
    }

    @Test func summariesReadBackSetupChoices() {
        #expect(SkinProfile().skinTypeSummary == "Not set up")
        #expect(SkinProfile.skipped.skinTypeSummary == "Skipped")
        #expect(SkinProfile.skipped.concernsSummary == "Skipped")

        let completed = SkinProfile(
            skinType: .dry,
            concerns: [.barrierRepair, .acneProne],
            setupStatus: .completed
        )
        #expect(completed.skinTypeSummary == "Dry skin")
        #expect(completed.concernsSummary == "Acne prone, Barrier repair")
        #expect(completed.avoidedIngredientsSummary == "None")
        #expect(SkinProfile(setupStatus: .completed).concernsSummary == "None selected")
    }

    @Test func submittingOptionalEmptyFieldsDoesNotImplySetupWasSkipped() throws {
        let profile = try roundTrip(SkinProfile(setupStatus: .completed))

        #expect(profile.isComplete)
        #expect(profile.skinType == nil)
        #expect(profile.concerns.isEmpty)
        #expect(profile.avoidedIngredients.isEmpty)
    }

    private func roundTrip(_ profile: SkinProfile) throws -> SkinProfile {
        try JSONDecoder().decode(SkinProfile.self, from: JSONEncoder().encode(profile))
    }

    @Test func schemaVersionIsEncodedAndPreserved() throws {
        let profile = SkinProfile(schemaVersion: 2)
        let data = try JSONEncoder().encode(profile)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["schemaVersion"] as? Int == 2)
        #expect(try roundTrip(profile) == profile)
    }

    @Test func profilesWithoutSchemaVersionDecodeAsVersionOne() throws {
        let profile = SkinProfile(skinType: .dry, concerns: [.barrierRepair], setupStatus: .completed)
        let data = try JSONEncoder().encode(profile)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "schemaVersion")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(SkinProfile.self, from: legacyData) == profile)
    }
}
