//
//  Ingredient.swift
//  Aesthelity
//
//  Created by Gaurav Pandey on 10/8/26.
//

import Foundation

/// Where an approved name was checked. Unreviewed synonyms stay out of the alias list.
struct IngredientReference: Codable, Hashable {
    let source: String
    let url: String?
    let identifier: String?
    let retrievedOn: String
    let datasetVersion: String?
    let reviewStatus: String
}

struct CanonicalIngredient: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    /// Families such as "retinoid" or "aha" that analysis rules target instead of single ingredients.
    let classes: [String]
    /// Empty for entries reviewed before provenance was recorded.
    let references: [IngredientReference]

    init(id: String, name: String, aliases: [String], classes: [String], references: [IngredientReference] = []) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.classes = classes
        self.references = references
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        classes = try container.decodeIfPresent([String].self, forKey: .classes) ?? []
        references = try container.decodeIfPresent([IngredientReference].self, forKey: .references) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(classes, forKey: .classes)
        if !references.isEmpty {
            try container.encode(references, forKey: .references)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, aliases, classes, references
    }
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

struct NormalizationWarning: Codable, Equatable {
    let input: String
    let message: String
}

struct NormalizedIngredient: Codable, Equatable {
    enum Status: Codable, Equatable {
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
