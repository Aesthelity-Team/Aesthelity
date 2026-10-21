//
//  ProductIngredientMapping.swift
//  Aesthelity
//

import Foundation

/// One product after PD-03 normalization.
/// `listStatus` describes the stored list. It is not derived from how many rows matched.
/// Decoding checks ID syntax and row shape only. It does not load the alias catalog.
struct NormalizedProductIngredients: Codable, Equatable {
    let productID: String
    let listStatus: IngredientListStatus
    /// Same count and order as the stored ingredient strings.
    let ingredients: [NormalizedIngredient]
    /// Alias-catalog content version used when this record was normalized.
    /// Nil for records saved before provenance existed. Nil is not the current catalog version.
    let catalogVersion: Int?

    /// Unavailable lists are empty. Partial and complete lists contain the stored rows.
    var listStatusAgreesWithRowCount: Bool {
        switch listStatus {
        case .unavailable:
            return ingredients.isEmpty
        case .partial, .complete:
            return !ingredients.isEmpty
        }
    }

    /// Stored confirmed IDs that are members of `normalizer`'s catalog, in list order.
    /// An unknown ID is omitted. It is not replaced with a match of `originalText`.
    func confirmedIngredientIDs(using normalizer: IngredientNormalizer) -> [String] {
        ingredients.compactMap { ingredient in
            guard let id = ingredient.ingredientID, normalizer.ingredient(withID: id) != nil else { return nil }
            return id
        }
    }

    /// True only when this record was normalized with `normalizer`'s catalog version,
    /// the list is complete and consistent, and every stored confirmed ID is in that catalog.
    /// A matching version does not skip the membership check. This is not a safety assessment.
    func isFullyResolved(using normalizer: IngredientNormalizer) -> Bool {
        guard catalogVersion == normalizer.catalogVersion else { return false }
        guard listStatus == .complete, listStatusAgreesWithRowCount else { return false }
        return ingredients.allSatisfy { ingredient in
            guard let id = ingredient.ingredientID else { return false }
            return normalizer.ingredient(withID: id) != nil
        }
    }

    /// Analysis view for the active catalog. `uncertaintyPreserved` is computed here.
    /// Callers cannot store a Boolean that turns uncertainty off.
    func analysisInput(using normalizer: IngredientNormalizer) -> IngredientAnalysisInput {
        IngredientAnalysisInput(
            productID: productID,
            listStatus: listStatus,
            confirmedIDs: confirmedIngredientIDs(using: normalizer),
            uncertaintyPreserved: !isFullyResolved(using: normalizer)
        )
    }
}

/// Derived analysis view. This is not a stored record and cannot be decoded from JSON.
/// Confirmed IDs are eligible for a later rule only after catalog membership has been checked.
struct IngredientAnalysisInput: Equatable {
    let productID: String
    let listStatus: IngredientListStatus
    let confirmedIDs: [String]
    /// When true, `confirmedIDs` are not a complete current identity mapping and are not a safe result.
    let uncertaintyPreserved: Bool

    fileprivate init(
        productID: String,
        listStatus: IngredientListStatus,
        confirmedIDs: [String],
        uncertaintyPreserved: Bool
    ) {
        self.productID = productID
        self.listStatus = listStatus
        self.confirmedIDs = confirmedIDs
        self.uncertaintyPreserved = uncertaintyPreserved
    }
}

extension IngredientNormalizer {
    /// Normalizes stored strings in order. Unresolved rows stay in the list and do not receive a confirmed ID.
    func normalizeStoredProduct(
        id productID: String,
        ingredientTexts: [String],
        listStatus: IngredientListStatus
    ) -> NormalizedProductIngredients {
        NormalizedProductIngredients(
            productID: productID,
            listStatus: listStatus,
            ingredients: normalize(ingredientTexts),
            catalogVersion: catalogVersion
        )
    }

    /// Current catalog products store ingredient strings. This reads that storage and does not write Firestore.
    func normalizeCatalogProduct(_ product: DemoProduct) -> NormalizedProductIngredients {
        normalizeStoredProduct(
            id: product.id,
            ingredientTexts: product.ingredients,
            listStatus: product.ingredientListStatus
        )
    }
}

/// Bundled product example checked against `IngredientNormalizer` by the unit tests.
enum PD03ProductExample {
    struct Fixture: Decodable, Equatable {
        let schemaVersion: Int
        let contractStatus: String
        let productID: String
        let displayName: String
        let listStatus: IngredientListStatus
        let ingredients: [String]
        let expected: [NormalizedIngredient]
    }

    static let resourceName = "pd03-product-example"

    enum LoadError: Error, Equatable {
        case missingResource(String)
        case invalidJSON(String)
    }

    static func load(from bundle: Bundle = .main) throws -> Fixture {
        let filename = "\(resourceName).json"
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoadError.missingResource(filename)
        }
        do {
            return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        } catch {
            throw LoadError.invalidJSON(error.localizedDescription)
        }
    }
}
