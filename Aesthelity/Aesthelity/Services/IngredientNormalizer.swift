//
//  IngredientNormalizer.swift
//  Aesthelity
//
//  Created by Gaurav Pandey on 10/8/26.
//

import Foundation

struct IngredientNormalizer {
    private let ingredientsByID: [String: CanonicalIngredient]
    private let idsByKey: [String: String]
    private let ambiguousTermsByKey: [String: AmbiguousIngredientTerm]

    init(catalog: IngredientAliasCatalog) {
        var ingredientsByID: [String: CanonicalIngredient] = [:]
        var idsByKey: [String: String] = [:]
        for ingredient in catalog.ingredients {
            ingredientsByID[ingredient.id] = ingredient
            for name in [ingredient.name] + ingredient.aliases {
                let key = Self.key(for: name)
                if !key.isEmpty && idsByKey[key] == nil {
                    idsByKey[key] = ingredient.id
                }
            }
        }

        var ambiguousTermsByKey: [String: AmbiguousIngredientTerm] = [:]
        for term in catalog.ambiguousTerms {
            for name in term.terms {
                let key = Self.key(for: name)
                if !key.isEmpty && ambiguousTermsByKey[key] == nil {
                    ambiguousTermsByKey[key] = term
                }
            }
        }

        self.ingredientsByID = ingredientsByID
        self.idsByKey = idsByKey
        self.ambiguousTermsByKey = ambiguousTermsByKey
    }

    func ingredient(withID id: String) -> CanonicalIngredient? {
        ingredientsByID[id]
    }

    func normalize(_ texts: [String]) -> [NormalizedIngredient] {
        texts.map { normalize($0) }
    }

    func normalize(label: String) -> [NormalizedIngredient] {
        normalize(IngredientLabelParser.ingredientNames(in: label))
    }

    func normalize(_ text: String) -> NormalizedIngredient {
        let lookupKeys = Self.lookupKeys(for: text)
        guard let primaryKey = lookupKeys.first else {
            return unmatched(text, message: "Ingredient text is empty.")
        }

        let matchedIDs = Set(lookupKeys.compactMap { idsByKey[$0] })
        if matchedIDs.count == 1, let id = matchedIDs.first {
            return NormalizedIngredient(originalText: text, status: .matched(ingredientID: id), warning: nil)
        }
        if matchedIDs.count > 1 {
            let candidates = matchedIDs.sorted()
            return ambiguous(text, candidateIDs: candidates,
                             message: "\"\(text)\" names more than one known ingredient: \(names(for: candidates)).")
        }
        if let term = lookupKeys.lazy.compactMap({ ambiguousTermsByKey[$0] }).first {
            let candidates = term.candidateIDs.sorted()
            return ambiguous(text, candidateIDs: candidates,
                             message: "\"\(text)\" could refer to \(names(for: candidates)). \(term.note)")
        }

        return closestMatch(for: text, key: primaryKey)
    }

    // MARK: - Fuzzy matching

    private func closestMatch(for text: String, key: String) -> NormalizedIngredient {
        let maxDistance = Self.maxTypoDistance(forKeyLength: key.count)
        guard maxDistance > 0 else { return unmatchedResult(for: text) }

        var bestDistance = Int.max
        var bestIDs = Set<String>()
        var bestIncludesAmbiguousTerm = false

        func consider(_ candidateKey: String, ids: [String], isAmbiguousTerm: Bool) {
            guard abs(candidateKey.count - key.count) <= maxDistance else { return }
            let distance = Self.editDistance(key, candidateKey)
            guard distance <= maxDistance else { return }
            if distance < bestDistance {
                bestDistance = distance
                bestIDs = Set(ids)
                bestIncludesAmbiguousTerm = isAmbiguousTerm
            } else if distance == bestDistance {
                bestIDs.formUnion(ids)
                bestIncludesAmbiguousTerm = bestIncludesAmbiguousTerm || isAmbiguousTerm
            }
        }

        for (candidateKey, id) in idsByKey {
            consider(candidateKey, ids: [id], isAmbiguousTerm: false)
        }
        for (candidateKey, term) in ambiguousTermsByKey {
            consider(candidateKey, ids: term.candidateIDs, isAmbiguousTerm: true)
        }

        if bestIDs.count == 1, !bestIncludesAmbiguousTerm, let id = bestIDs.first {
            let name = ingredientsByID[id]?.name ?? id
            return NormalizedIngredient(
                originalText: text,
                status: .uncertain(suggestedID: id),
                warning: NormalizationWarning(
                    input: text,
                    message: "\"\(text)\" is not an exact match. Closest known ingredient: \(name). Treat as unknown until reviewed."
                )
            )
        }
        if !bestIDs.isEmpty {
            let candidates = bestIDs.sorted()
            return ambiguous(text, candidateIDs: candidates,
                             message: "\"\(text)\" is not an exact match and is close to \(names(for: candidates)).")
        }
        return unmatchedResult(for: text)
    }

    /// Short names get no typo tolerance so abbreviations like "BPO" or "AHA" never fuzzy-match each other.
    private static func maxTypoDistance(forKeyLength length: Int) -> Int {
        switch length {
        case 10...: return 2
        case 5...: return 1
        default: return 0
        }
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    // MARK: - Keys

    /// Folds case, accents, and punctuation so "L-Ascorbic Acid" and "l ascorbic acid" share a key.
    static func key(for text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        let spaced = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    /// The full text first, then the text outside and inside parentheses, as in "Fragrance (Parfum)".
    private static func lookupKeys(for text: String) -> [String] {
        var candidates = [text]
        if let open = text.firstIndex(of: "("), let close = text[open...].firstIndex(of: ")") {
            candidates.append(String(text[..<open]) + String(text[text.index(after: close)...]))
            candidates.append(String(text[text.index(after: open)..<close]))
        }

        var keys: [String] = []
        for candidate in candidates {
            let key = key(for: candidate)
            if !key.isEmpty && !keys.contains(key) {
                keys.append(key)
            }
        }
        return keys
    }

    // MARK: - Results

    private func names(for ids: [String]) -> String {
        ids.map { ingredientsByID[$0]?.name ?? $0 }.joined(separator: ", ")
    }

    private func ambiguous(_ text: String, candidateIDs: [String], message: String) -> NormalizedIngredient {
        NormalizedIngredient(
            originalText: text,
            status: .ambiguous(candidateIDs: candidateIDs),
            warning: NormalizationWarning(input: text, message: message)
        )
    }

    private func unmatchedResult(for text: String) -> NormalizedIngredient {
        unmatched(text, message: "\"\(text)\" does not match any known ingredient. Treat as unknown until reviewed.")
    }

    private func unmatched(_ text: String, message: String) -> NormalizedIngredient {
        NormalizedIngredient(
            originalText: text,
            status: .unmatched,
            warning: NormalizationWarning(input: text, message: message)
        )
    }
}

// MARK: - Catalog

extension IngredientAliasCatalog {
    enum LoadError: Error {
        case missingResource(String)
    }

    static let bundledResourceName = "ingredient-aliases"

    static func loadBundled(from bundle: Bundle = .main) throws -> IngredientAliasCatalog {
        guard let url = bundle.url(forResource: bundledResourceName, withExtension: "json") else {
            throw LoadError.missingResource("\(bundledResourceName).json")
        }
        return try JSONDecoder().decode(IngredientAliasCatalog.self, from: Data(contentsOf: url))
    }

    /// Problems that would make normalization unreliable, such as one alias pointing at two ingredients.
    func validationIssues() -> [String] {
        var issues: [String] = []
        var seenIDs = Set<String>()
        var ownerByKey: [String: String] = [:]

        for ingredient in ingredients {
            if !seenIDs.insert(ingredient.id).inserted {
                issues.append("Duplicate ingredient ID \(ingredient.id).")
            }
            if !Self.isSlug(ingredient.id) {
                issues.append("Ingredient ID \"\(ingredient.id)\" must be lowercase words joined by hyphens.")
            }
            for ingredientClass in ingredient.classes where !Self.isSlug(ingredientClass) {
                issues.append("\(ingredient.id) has class \"\(ingredientClass)\", which must be lowercase words joined by hyphens.")
            }
            for name in [ingredient.name] + ingredient.aliases {
                let key = IngredientNormalizer.key(for: name)
                if key.isEmpty {
                    issues.append("\(ingredient.id) has an empty name or alias.")
                } else if let owner = ownerByKey[key], owner != ingredient.id {
                    issues.append("\"\(name)\" is listed for both \(owner) and \(ingredient.id).")
                } else {
                    ownerByKey[key] = ingredient.id
                }
            }
        }

        for term in ambiguousTerms {
            for id in term.candidateIDs where !seenIDs.contains(id) {
                issues.append("Ambiguous term \(term.terms.first ?? "?") lists unknown ingredient \(id).")
            }
            if term.candidateIDs.count < 2 {
                issues.append("Ambiguous term \(term.terms.first ?? "?") needs at least two candidates.")
            }
            for name in term.terms {
                if let owner = ownerByKey[IngredientNormalizer.key(for: name)] {
                    issues.append("\"\(name)\" is both an ambiguous term and an alias of \(owner).")
                }
            }
        }
        return issues
    }

    private static func isSlug(_ value: String) -> Bool {
        value.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil
    }
}
