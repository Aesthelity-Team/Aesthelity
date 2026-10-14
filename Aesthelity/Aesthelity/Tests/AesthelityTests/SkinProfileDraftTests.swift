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

        guard case .completed(let profile) = draft.submit(using: try normalizer()) else {
            Issue.record("Expected a completed profile")
            return
        }
        #expect(profile.skinType == .dry)
        #expect(profile.concerns == draft.concerns)
        #expect(profile.isComplete)
        #expect(profile.avoidedIngredients.map(\.ingredientID) == ["fragrance", "retinol"])
        #expect(profile.avoidedIngredients.map(\.originalText) == ["Parfum", "Retinol"])
    }

    @Test func unresolvedEntriesKeepTheirStatusAndWarnings() throws {
        let normalizer = try normalizer()
        let inputs = ["Niacinimide", "Vitamin C", "Unobtainium Extract", "Vitamin C", "unobtainium extract", "NIACINIMIDE"]
        let uniqueInputs = Array(inputs.prefix(3))
        let draft = SkinProfileDraft(avoidedIngredientInputs: inputs)

        guard case .completed(let profile) = draft.submit(using: normalizer) else {
            Issue.record("Unknown names are valid input, not validation errors")
            return
        }
        #expect(profile.avoidedIngredients == normalizer.normalize(uniqueInputs))
        #expect(profile.avoidedIngredients.allSatisfy { $0.needsReview })
        #expect(profile.avoidedIngredients.warnings.map(\.input) == uniqueInputs)
    }

    @Test func invalidEntriesReturnInlineErrorsWithoutChangingTheDraft() throws {
        let longInput = String(repeating: "a", count: SkinProfileDraft.maximumIngredientLength + 1)
        let draft = SkinProfileDraft(
            skinType: .oily,
            concerns: [.acneProne],
            avoidedIngredientInputs: ["Retinol", "   ", "!!!", longInput, "Retinol\nWater", "123"]
        )

        guard case .invalid(let errors) = draft.submit(using: try normalizer()) else {
            Issue.record("Invalid input must block submission")
            return
        }
        #expect(errors.map(\.entryIndex) == [1, 2, 3, 4, 5])
        #expect(errors.map(\.input) == Array(draft.avoidedIngredientInputs.dropFirst()))
        #expect(errors.map(\.reason) == [.empty, .missingLetters, .tooLong, .controlCharacters, .missingLetters])
        #expect(errors.allSatisfy { !$0.message.isEmpty })
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
        let profile = draft.skip()

        #expect(profile == SkinProfile.skipped)
        #expect(!profile.isComplete)
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

    @Test func paddedEntryAtTheLengthLimitIsValidatedAndSavedWithoutPadding() throws {
        let name = String(repeating: "a", count: SkinProfileDraft.maximumIngredientLength)
        let draft = SkinProfileDraft(avoidedIngredientInputs: ["  \(name)  "])
        #expect(draft.validationErrors().isEmpty)

        guard case .completed(let profile) = draft.submit(using: try normalizer()) else {
            Issue.record("Surrounding whitespace should not count toward the length limit")
            return
        }
        #expect(profile.avoidedIngredients.first?.originalText == name)
    }

    @Test func pastedFormatCharactersAreRemovedBeforeMatching() throws {
        let draft = SkinProfileDraft(avoidedIngredientInputs: ["Retinol\u{200B}", "Re\u{200D}tinol", "Re\u{00AD}tinol"])
        #expect(draft.validationErrors().isEmpty)

        guard case .completed(let profile) = draft.submit(using: try normalizer()) else {
            Issue.record("Invisible format characters should not block submission")
            return
        }
        #expect(profile.avoidedIngredients.map(\.ingredientID) == ["retinol"])
        #expect(profile.avoidedIngredients.map(\.originalText) == ["Retinol"])
    }

    @Test func validationRejectsRealControlCharactersAndPreservesTypedText() {
        let inputs = ["  Retinol\nWater  ", "Retinol\u{0000}Water"]
        let errors = SkinProfileDraft(avoidedIngredientInputs: inputs).validationErrors()
        #expect(errors.map(\.reason) == [.controlCharacters, .controlCharacters])
        #expect(errors.map(\.input) == inputs)
    }
}
