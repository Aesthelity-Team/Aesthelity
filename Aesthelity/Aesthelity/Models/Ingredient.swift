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

/// Canonical ingredient IDs are lowercase alphanumeric words separated by single hyphens.
/// Catalog loading and stored-record decoding share this check so the two cannot drift.
enum CanonicalIngredientID {
    static func isValid(_ value: String) -> Bool {
        value.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil
    }
}

struct NormalizationWarning: Codable, Equatable {
    let input: String
    let message: String
}

struct NormalizedIngredient: Equatable {
    /// In-memory match state. JSON uses the explicit `mapping` fields below, not this enum's synthesized encoding.
    enum Status: Equatable {
        case matched(ingredientID: String)
        case uncertain(suggestedID: String)
        case ambiguous(candidateIDs: [String])
        case unmatched
    }

    /// Storage values for `mapping`. `confirmed` is the only state that carries `ingredientID`.
    enum Mapping: String, Codable {
        case confirmed, uncertain, ambiguous, unmatched
    }

    let originalText: String
    let status: Status
    let warning: NormalizationWarning?

    /// Only set for confident matches; uncertain and ambiguous results must not be analyzed as a known ingredient.
    var ingredientID: String? {
        if case .matched(let id) = status { return id }
        return nil
    }

    var suggestedID: String? {
        if case .uncertain(let id) = status { return id }
        return nil
    }

    var candidateIDs: [String] {
        if case .ambiguous(let ids) = status { return ids }
        return []
    }

    var mapping: Mapping {
        switch status {
        case .matched: .confirmed
        case .uncertain: .uncertain
        case .ambiguous: .ambiguous
        case .unmatched: .unmatched
        }
    }

    var needsReview: Bool { ingredientID == nil }
}

extension NormalizedIngredient: Codable {
    private enum CodingKeys: String, CodingKey {
        case originalText, mapping, ingredientID, suggestedID, candidateIDs, warning, status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(originalText, forKey: .originalText)
        try container.encode(mapping, forKey: .mapping)
        switch status {
        case .matched(let id):
            try container.encode(id, forKey: .ingredientID)
        case .uncertain(let id):
            try container.encode(id, forKey: .suggestedID)
        case .ambiguous(let ids):
            try container.encode(ids, forKey: .candidateIDs)
        case .unmatched:
            break
        }
        try container.encodeIfPresent(warning, forKey: .warning)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let originalText = try container.decode(String.self, forKey: .originalText)
        let warning = try container.decodeIfPresent(NormalizationWarning.self, forKey: .warning)
        let hasMapping = container.contains(.mapping)
        let hasStatus = container.contains(.status)
        // Syntax only. Catalog membership is checked later, when a product becomes analysis input.
        let status: Status
        if hasMapping && hasStatus {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Ingredient mapping must use either mapping or legacy status, not both."
            ))
        } else if hasMapping {
            status = try Self.validatedStatus(
                mapping: try container.decode(Mapping.self, forKey: .mapping),
                ingredientID: try container.decodeIfPresent(String.self, forKey: .ingredientID),
                suggestedID: try container.decodeIfPresent(String.self, forKey: .suggestedID),
                candidateIDs: try container.decodeIfPresent([String].self, forKey: .candidateIDs) ?? [],
                codingPath: decoder.codingPath
            )
        } else if hasStatus {
            let legacy = try container.decode(LegacyStatus.self, forKey: .status)
            status = try Self.validatedStatus(
                mapping: legacy.mapping,
                ingredientID: legacy.ingredientID,
                suggestedID: legacy.suggestedID,
                candidateIDs: legacy.candidateIDs,
                codingPath: decoder.codingPath
            )
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Ingredient mapping requires mapping or a legacy status value."
            ))
        }
        self.init(originalText: originalText, status: status, warning: warning)
    }

    /// Shared rules for the explicit JSON fields and the legacy status object.
    /// Malformed IDs are rejected. They are not trimmed or rewritten into a different identity.
    private static func validatedStatus(
        mapping: Mapping,
        ingredientID: String?,
        suggestedID: String?,
        candidateIDs: [String],
        codingPath: [CodingKey]
    ) throws -> Status {
        let confirmedID = try canonicalID(ingredientID, field: "ingredientID", codingPath: codingPath)
        let suggestion = try canonicalID(suggestedID, field: "suggestedID", codingPath: codingPath)
        let candidates = try canonicalIDs(candidateIDs, field: "candidateIDs", codingPath: codingPath)

        switch mapping {
        case .confirmed:
            guard let confirmedID, suggestion == nil, candidates.isEmpty else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "A confirmed ingredient requires ingredientID and no suggestedID or candidateIDs."
                ))
            }
            return .matched(ingredientID: confirmedID)
        case .uncertain:
            guard confirmedID == nil, let suggestion, candidates.isEmpty else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "An uncertain ingredient requires suggestedID and must not include a confirmed ingredientID or candidateIDs."
                ))
            }
            return .uncertain(suggestedID: suggestion)
        case .ambiguous:
            guard confirmedID == nil, suggestion == nil, candidates.count >= 2 else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "An ambiguous ingredient requires at least two distinct candidateIDs and must not include a confirmed ingredientID or suggestedID."
                ))
            }
            return .ambiguous(candidateIDs: candidates)
        case .unmatched:
            guard confirmedID == nil, suggestion == nil, candidates.isEmpty else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "An unmatched ingredient must not include a confirmed, suggested, or candidate ID."
                ))
            }
            return .unmatched
        }
    }

    private static func canonicalID(_ value: String?, field: String, codingPath: [CodingKey]) throws -> String? {
        guard let value else { return nil }
        guard CanonicalIngredientID.isValid(value) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "\(field) \"\(value)\" must be lowercase alphanumeric words separated by single hyphens."
            ))
        }
        return value
    }

    private static func canonicalIDs(_ values: [String], field: String, codingPath: [CodingKey]) throws -> [String] {
        var seen = Set<String>()
        for value in values {
            guard CanonicalIngredientID.isValid(value) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "\(field) \"\(value)\" must be lowercase alphanumeric words separated by single hyphens."
                ))
            }
            guard seen.insert(value).inserted else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: codingPath,
                    debugDescription: "\(field) repeats \"\(value)\". Repeated IDs do not count as distinct candidates."
                ))
            }
        }
        return values
    }

    /// Files saved before the explicit mapping fields used Swift's associated-value enum encoding.
    private enum LegacyStatus: Decodable {
        case matched(ingredientID: String)
        case uncertain(suggestedID: String)
        case ambiguous(candidateIDs: [String])
        case unmatched

        var mapping: Mapping {
            switch self {
            case .matched: .confirmed
            case .uncertain: .uncertain
            case .ambiguous: .ambiguous
            case .unmatched: .unmatched
            }
        }

        var ingredientID: String? {
            if case .matched(let id) = self { return id }
            return nil
        }

        var suggestedID: String? {
            if case .uncertain(let id) = self { return id }
            return nil
        }

        var candidateIDs: [String] {
            if case .ambiguous(let ids) = self { return ids }
            return []
        }
    }
}

extension Array where Element == NormalizedIngredient {
    var warnings: [NormalizationWarning] { compactMap(\.warning) }
}
