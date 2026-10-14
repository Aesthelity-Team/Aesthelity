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
        #expect(restored.isComplete)
        #expect(restored.avoidedIngredients.map(\.originalText) == inputs)
        #expect(restored.avoidedIngredients.map(\.ingredientID) == ["fragrance", nil, nil, nil])
        #expect(restored.avoidedIngredients.map(\.needsReview) == [false, true, true, true])
        #expect(restored.avoidedIngredients.warnings.map(\.input) == Array(inputs.dropFirst()))
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
}
