import Foundation

/// Editable setup values. Validation and submission never overwrite the user's input.
struct SkinProfileDraft: Equatable {
    static let maximumIngredientLength = 120

    var skinType: SkinProfile.SkinType?
    var concerns: Set<SkinProfile.Concern> = []
    /// One ingredient per entry; an empty array means no avoidance preferences.
    var avoidedIngredientInputs: [String] = []

    struct IngredientInputError: Equatable {
        enum Reason: Equatable {
            case empty
            case tooLong
            case controlCharacters
            case missingLetters
        }

        let entryIndex: Int
        let input: String
        let reason: Reason

        var message: String {
            switch reason {
            case .empty: return "Enter an ingredient name or remove this entry."
            case .tooLong: return "Use at most \(SkinProfileDraft.maximumIngredientLength) characters per ingredient."
            case .controlCharacters: return "Enter one ingredient on a single line without control characters."
            case .missingLetters: return "An ingredient name must contain at least one letter."
            }
        }
    }

    enum SubmissionResult: Equatable {
        case completed(SkinProfile)
        case invalid([IngredientInputError])
    }

    /// Returns errors for all invalid entries so the UI can display them inline.
    func validationErrors() -> [IngredientInputError] {
        validationErrors(for: preparedInputs)
    }

    private var preparedInputs: [String] {
        avoidedIngredientInputs.map { input in
            let visibleScalars = input.unicodeScalars.filter { $0.properties.generalCategory != .format }
            return String(String.UnicodeScalarView(visibleScalars))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func validationErrors(for inputs: [String]) -> [IngredientInputError] {
        inputs.enumerated().compactMap { index, input in
            let reason: IngredientInputError.Reason
            if input.isEmpty {
                reason = .empty
            } else if input.count > Self.maximumIngredientLength {
                reason = .tooLong
            } else if input.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
                reason = .controlCharacters
            } else if !input.unicodeScalars.contains(where: CharacterSet.letters.contains) {
                reason = .missingLetters
            } else {
                return nil
            }
            return IngredientInputError(entryIndex: index, input: avoidedIngredientInputs[index], reason: reason)
        }
    }

    /// Builds a profile only after validation succeeds. Unknown names retain DATA-02 warnings.
    func submit(using normalizer: IngredientNormalizer) -> SubmissionResult {
        let inputs = preparedInputs
        let errors = validationErrors(for: inputs)
        guard errors.isEmpty else { return .invalid(errors) }

        var seenIDs = Set<String>()
        var seenUnresolvedKeys = Set<String>()
        let ingredients = normalizer.normalize(inputs).filter { ingredient in
            if let id = ingredient.ingredientID {
                return seenIDs.insert(id).inserted
            }
            return seenUnresolvedKeys.insert(IngredientNormalizer.key(for: ingredient.originalText)).inserted
        }

        return .completed(SkinProfile(
            skinType: skinType,
            concerns: concerns,
            avoidedIngredients: ingredients,
            setupStatus: .completed
        ))
    }

    /// Bypasses validation and does not submit any unfinished draft choices.
    func skip() -> SkinProfile { .skipped }
}
