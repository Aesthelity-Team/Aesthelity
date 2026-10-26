import Foundation

/// Editable form values. Raw text is retained until explicit submission processing.
struct ManualProductDraft: Equatable {
    static let maximumIngredientLength = 120

    var name: String = ""
    var brand: String = ""
    var category: DemoProductCategory?
    var rawIngredientList: String = ""

    struct ValidationError: Equatable {
        enum Field: Equatable { case name, brand, ingredientList }
        enum Reason: Equatable { case required, controlCharacters, missingLetters, tooLong, unbalancedBrackets }

        let field: Field
        let input: String
        let entryIndex: Int?
        let reason: Reason

        var message: String {
            switch reason {
            case .required: return field == .name ? "Enter a product name." : "Enter at least one ingredient."
            case .controlCharacters: return "Remove control characters from this entry."
            case .missingLetters: return "An ingredient name must contain at least one letter."
            case .tooLong: return "Use at most \(ManualProductDraft.maximumIngredientLength) characters per ingredient."
            case .unbalancedBrackets: return "Check that ingredient brackets are paired correctly."
            }
        }
    }

    enum SubmissionResult: Equatable {
        case completed(ManualProduct)
        case invalid([ValidationError])
    }

    func validationErrors() -> [ValidationError] {
        validationErrors(for: IngredientLabelParser.entriesForValidation(in: rawIngredientList))
    }

    /// Prepares a product without saving it or changing the entered text.
    func submit(using normalizer: IngredientNormalizer) -> SubmissionResult {
        let entries = IngredientLabelParser.entriesForValidation(in: rawIngredientList)
        let errors = validationErrors(for: entries)
        guard errors.isEmpty else { return .invalid(errors) }

        let preparedBrand = Self.prepared(brand)
        // TODO(PD-02): Pass the completed product to the team's persistence/analysis integration.
        return .completed(ManualProduct(
            name: Self.prepared(name),
            brand: preparedBrand.isEmpty ? nil : preparedBrand,
            category: category,
            rawIngredientList: rawIngredientList,
            ingredients: normalizer.normalize(entries.compactMap(\.name))
        ))
    }

    private func validationErrors(for entries: [IngredientLabelParser.Entry]) -> [ValidationError] {
        var errors: [ValidationError] = []
        for (field, input) in [(ValidationError.Field.name, name), (.brand, brand)] {
            if field == .name && Self.prepared(input).isEmpty {
                errors.append(ValidationError(field: field, input: input, entryIndex: nil, reason: .required))
            } else if Self.containsControls(input, allowingLineBreaks: false) {
                errors.append(ValidationError(field: field, input: input, entryIndex: nil, reason: .controlCharacters))
            }
        }

        if Self.containsControls(rawIngredientList, allowingLineBreaks: true) {
            errors.append(ValidationError(field: .ingredientList, input: rawIngredientList, entryIndex: nil, reason: .controlCharacters))
        }
        if !Self.hasBalancedBrackets(rawIngredientList) {
            errors.append(ValidationError(field: .ingredientList, input: rawIngredientList, entryIndex: nil, reason: .unbalancedBrackets))
        }
        if entries.isEmpty {
            errors.append(ValidationError(field: .ingredientList, input: rawIngredientList, entryIndex: nil, reason: .required))
        }
        for (index, entry) in entries.enumerated() {
            let reason: ValidationError.Reason
            if !(entry.name ?? "").unicodeScalars.contains(where: CharacterSet.letters.contains) {
                reason = .missingLetters
            } else if (entry.name ?? "").count > Self.maximumIngredientLength {
                reason = .tooLong
            } else {
                continue
            }
            errors.append(ValidationError(field: .ingredientList, input: entry.input, entryIndex: index, reason: reason))
        }
        return errors
    }

    private static func prepared(_ input: String) -> String {
        String(String.UnicodeScalarView(input.unicodeScalars.filter {
            $0.properties.generalCategory != .format
        })).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsControls(_ input: String, allowingLineBreaks: Bool) -> Bool {
        input.unicodeScalars.contains {
            $0.properties.generalCategory == .control
                && !(allowingLineBreaks && CharacterSet.newlines.contains($0))
        }
    }

    private static func hasBalancedBrackets(_ input: String) -> Bool {
        var stack: [Character] = []
        let pairs: [Character: Character] = [")": "(", "]": "[", "}": "{"]
        for character in input {
            if "([{".contains(character) {
                stack.append(character)
            } else if let opening = pairs[character], stack.popLast() != opening {
                return false
            }
        }
        return stack.isEmpty
    }
}
