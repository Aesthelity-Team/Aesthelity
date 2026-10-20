//
//  ProductIngredientMapping.swift
//  Aesthelity
//

import Foundation

/// One product after PD-03 normalization.
/// `listStatus` describes the stored list. It is not derived from how many rows matched.
struct NormalizedProductIngredients: Codable, Equatable {
    let productID: String
    let listStatus: IngredientListStatus
    /// Same count and order as the stored ingredient strings.
    let ingredients: [NormalizedIngredient]

    /// Confirmed canonical IDs in list order. Unresolved rows are omitted, not filled in.
    var confirmedIngredientIDs: [String] {
        ingredients.compactMap(\.ingredientID)
    }

    /// Unavailable lists are empty. Partial and complete lists contain the stored rows.
    var listStatusAgreesWithRowCount: Bool {
        switch listStatus {
        case .unavailable:
            return ingredients.isEmpty
        case .partial, .complete:
            return !ingredients.isEmpty
        }
    }

    /// True only for a complete, consistent list whose every row has a confirmed ID.
    var isFullyResolved: Bool {
        listStatus == .complete
            && listStatusAgreesWithRowCount
            && ingredients.allSatisfy { !$0.needsReview }
    }

    /// Derived analysis view. It does not replace the ordered rows.
    var analysisInput: IngredientAnalysisInput {
        IngredientAnalysisInput(
            productID: productID,
            listStatus: listStatus,
            confirmedIDs: confirmedIngredientIDs,
            uncertaintyPreserved: !isFullyResolved
        )
    }
}

/// Confirmed IDs an analysis rule may match, and whether unresolved data still blocks a complete conclusion.
struct IngredientAnalysisInput: Codable, Equatable {
    let productID: String
    let listStatus: IngredientListStatus
    let confirmedIDs: [String]
    /// When true, `confirmedIDs` are not a complete basis for a safe result.
    let uncertaintyPreserved: Bool
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
            ingredients: normalize(ingredientTexts)
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
