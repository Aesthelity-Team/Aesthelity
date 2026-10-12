//
//  IngredientLabelParser.swift
//  Aesthelity
//
//  Created by Gaurav Pandey on 10/8/26.
//

import Foundation

/// Splits a printed ingredient label into individual ingredient names, ready for `IngredientNormalizer`.
enum IngredientLabelParser {
    static func ingredientNames(in label: String) -> [String] {
        splitTopLevel(removingSectionHeadings(from: label))
            .compactMap(cleanedName)
    }

    /// Headings like "Inactive Ingredients:" and "May Contain (+/-):" separate lists rather than name ingredients.
    private static func removingSectionHeadings(from label: String) -> String {
        let headings = [
            #"\b(active|inactive|other)?\s*ingredients?\s*:"#,
            #"\bmay\s+contain\s*(\(\s*\+\s*/\s*-\s*\)|\[\s*\+\s*/\s*-\s*\])?\s*:?"#,
            #"(\(\s*\+\s*/\s*-\s*\)|\[\s*\+\s*/\s*-\s*\])\s*:?"#,
        ]
        return headings.reduce(label) { text, pattern in
            text.replacingOccurrences(of: pattern, with: ",", options: [.regularExpression, .caseInsensitive])
        }
    }

    /// Splits on commas, semicolons, bullets, and line breaks outside brackets, keeping names like "1,3-Butylene Glycol" whole.
    private static func splitTopLevel(_ text: String) -> [String] {
        let characters = Array(text)
        var parts: [String] = []
        var current = ""
        var depth = 0

        for (index, character) in characters.enumerated() {
            switch character {
            case "(", "[", "{":
                depth += 1
            case ")", "]", "}":
                depth = max(0, depth - 1)
            default:
                break
            }

            let isDigitComma = character == ","
                && index > 0 && characters[index - 1].isNumber
                && index + 1 < characters.count && characters[index + 1].isNumber
            let isSeparator = depth == 0 && !isDigitComma
                && (character == "," || character == ";" || character == "•" || character.isNewline)

            if isSeparator {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts
    }

    private static func cleanedName(_ raw: String) -> String? {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // A leading marker means a footnote legend such as "*Certified Organic", not an ingredient.
        if name.hasPrefix("*") || name.hasPrefix("†") { return nil }

        name = name
            .replacingOccurrences(of: #"\(\s*\d+(?:[.,]\d+)?\s*%\s*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\d+(?:[.,]\d+)?\s*%"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\(\s*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".:*†")))

        return name.isEmpty ? nil : name
    }
}
