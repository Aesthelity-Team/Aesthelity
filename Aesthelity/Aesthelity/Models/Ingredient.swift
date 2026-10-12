//
//  Ingredient.swift
//  Aesthelity
//
//  Created by Gaurav Pandey on 10/8/26.
//

import Foundation

struct CanonicalIngredient: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    /// Families such as "retinoid" or "aha" that analysis rules target instead of single ingredients.
    let classes: [String]
}

/// A label term that can refer to more than one canonical ingredient, such as "Vitamin C".
struct AmbiguousIngredientTerm: Codable, Hashable {
    let terms: [String]
    let candidateIDs: [String]
    let note: String
}

struct IngredientAliasCatalog: Codable {
    let version: Int
    let ingredients: [CanonicalIngredient]
    let ambiguousTerms: [AmbiguousIngredientTerm]
}

struct NormalizationWarning: Equatable {
    let input: String
    let message: String
}

struct NormalizedIngredient: Equatable {
    enum Status: Equatable {
        case matched(ingredientID: String)
        case uncertain(suggestedID: String)
        case ambiguous(candidateIDs: [String])
        case unmatched
    }

    let originalText: String
    let status: Status
    let warning: NormalizationWarning?

    /// Only set for confident matches; uncertain and ambiguous results must not be analyzed as a known ingredient.
    var ingredientID: String? {
        if case .matched(let id) = status { return id }
        return nil
    }

    var needsReview: Bool { ingredientID == nil }
}

extension Array where Element == NormalizedIngredient {
    var warnings: [NormalizationWarning] { compactMap(\.warning) }
}
