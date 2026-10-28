import Foundation

/// Transport adapter for AN-03's draft Python product-input contract.
struct ManualProductAnalysisInput: Encodable, Equatable {
    enum ListStatus: String, Encodable, CaseIterable {
        case complete, partial, unavailable
    }

    struct IngredientRow: Encodable, Equatable {
        enum Mapping: String, Encodable {
            case confirmed, uncertain, ambiguous, unmatched
        }

        let originalText: String
        let mapping: Mapping
        let ingredientID: String?
        let suggestedID: String?
        let candidateIDs: [String]
        let warning: NormalizationWarning?

        init(_ ingredient: NormalizedIngredient) {
            originalText = ingredient.originalText
            warning = ingredient.warning
            switch ingredient.status {
            case .matched(let id):
                mapping = .confirmed
                ingredientID = id
                suggestedID = nil
                candidateIDs = []
            case .uncertain(let id):
                mapping = .uncertain
                ingredientID = nil
                suggestedID = id
                candidateIDs = []
            case .ambiguous(let ids):
                mapping = .ambiguous
                ingredientID = nil
                suggestedID = nil
                candidateIDs = ids
            case .unmatched:
                mapping = .unmatched
                ingredientID = nil
                suggestedID = nil
                candidateIDs = []
            }
        }
    }

    let productID: String
    let listStatus: ListStatus
    let catalogVersion: Int?
    let ingredients: [IngredientRow]

    /// Supply the version used to normalize these rows, or nil when unknown.
    init(product: ManualProduct, listStatus: ListStatus, catalogVersion: Int?) {
        productID = product.id.uuidString
        self.listStatus = listStatus
        self.catalogVersion = catalogVersion
        ingredients = product.ingredients.map(IngredientRow.init)
    }
}
