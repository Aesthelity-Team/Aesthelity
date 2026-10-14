import Testing
@testable import Aesthelity

struct SkinProfileDraftTests {
    private func normalizer() throws -> IngredientNormalizer {
        IngredientNormalizer(catalog: try .loadBundled())
    }

    @Test func submissionPreservesChoicesAndDeduplicatesConfidentAliases() throws {
        let draft = SkinProfileDraft(
            skinType: .dry,
            concerns: [.drynessAndHydration, .barrierRepair],
            avoidedIngredientInputs: ["Parfum", "Fragrance", "Retinol"]
        )
        let original = draft

        guard case .completed(let profile) = draft.submit(using: try normalizer()) else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.skinType == .dry)
        #expect(profile.concerns == draft.concerns)
        #expect(profile.isComplete)
        #expect(profile.avoidedIngredients.map(\.ingredientID) == ["fragrance", "retinol"])
        #expect(profile.avoidedIngredients.map(\.originalText) == ["Parfum", "Retinol"])
        #expect(draft == original)
    }

    @Test func unresolvedEntriesKeepTheirStatusAndWarnings() throws {
        let normalizer = try normalizer()
        let inputs = ["Niacinimide", "Vitamin C", "Unobtainium Extract", "Vitamin C"]
        let draft = SkinProfileDraft(avoidedIngredientInputs: inputs)

        guard case .completed(let profile) = draft.submit(using: normalizer) else {
            Issue.record("Unknown names are valid input, not validation errors")
            return
        }
        #expect(profile.avoidedIngredients == normalizer.normalize(inputs))
        #expect(profile.avoidedIngredients.allSatisfy { $0.needsReview })
        #expect(profile.avoidedIngredients.warnings.map(\.input) == inputs)
    }

    @Test func invalidEntriesReturnInlineErrorsWithoutChangingTheDraft() throws {
        let longInput = String(repeating: "a", count: SkinProfileDraft.maximumIngredientLength + 1)
        let draft = SkinProfileDraft(
            skinType: .oily,
            concerns: [.acneProne],
            avoidedIngredientInputs: ["Retinol", "   ", "!!!", longInput, "Retinol\nWater", "123"]
        )
        let original = draft

        guard case .invalid(let errors) = draft.submit(using: try normalizer()) else {
            Issue.record("Invalid input must block submission")
            return
        }
        #expect(errors.map(\.entryIndex) == [1, 2, 3, 4, 5])
        #expect(errors.map(\.input) == Array(draft.avoidedIngredientInputs.dropFirst()))
        #expect(errors.map(\.reason) == [.empty, .missingLetters, .tooLong, .controlCharacters, .missingLetters])
        #expect(errors.allSatisfy { !$0.message.isEmpty })
        #expect(draft == original)
    }

    @Test func correctingInvalidInputAllowsResubmission() throws {
        let normalizer = try normalizer()
        var draft = SkinProfileDraft(avoidedIngredientInputs: ["!!!"])
        #expect(!draft.validationErrors().isEmpty)

        draft.avoidedIngredientInputs[0] = "Parfum"

        guard case .completed(let profile) = draft.submit(using: normalizer) else {
            Issue.record("Corrected input should submit successfully")
            return
        }
        #expect(profile.avoidedIngredients.first?.ingredientID == "fragrance")
        #expect(draft.validationErrors().isEmpty)
    }

    @Test func skipBypassesInvalidDraftAndDoesNotSubmitSelections() {
        let draft = SkinProfileDraft(
            skinType: .combination,
            concerns: [.oilControlAndPores],
            avoidedIngredientInputs: ["!!!"]
        )
        let original = draft
        let profile = draft.skip()

        #expect(profile == SkinProfile.skipped)
        #expect(!profile.isComplete)
        #expect(draft == original)
    }

    @Test func optionalEmptyDraftCanBeSubmitted() throws {
        guard case .completed(let profile) = SkinProfileDraft().submit(using: try normalizer()) else {
            Issue.record("All profile fields are optional")
            return
        }
        #expect(profile == SkinProfile(setupStatus: .completed))
    }

    @Test func validationAcceptsUnicodeAndIngredientNamePunctuationAtTheLengthLimit() {
        let draft = SkinProfileDraft(avoidedIngredientInputs: [
            "  Ascórbic Acid  ", "1,3-Butylene Glycol", "CI 77891", "Fragrance (Parfum)",
            String(repeating: "a", count: SkinProfileDraft.maximumIngredientLength)
        ])
        #expect(draft.validationErrors().isEmpty)
    }
}
