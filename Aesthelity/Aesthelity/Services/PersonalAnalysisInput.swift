import Foundation

struct SavedPersonalAnalysis: Codable {
    let schemaVersion: Int
    let routineID: UUID
    let request: AnalysisRequestPayload
    let response: AnalysisResponsePayload
    let productNames: [String: String]
    let savedAt: Date
}

enum PersonalAnalysisInput {
    /// Snapshot strings are normalized with the active catalog. Old step labels
    /// without ingredient data stay unavailable; nothing substitutes demo inputs.
    static func make(steps: [RoutineStepItem], period: RoutinePeriod, normalizer: IngredientNormalizer) -> AnalysisRequestPayload {
        let products = steps.map { step -> NormalizedProductIngredients in
            let snapshot = step.product
            let texts = snapshot?.ingredientNames ?? []
            let status: IngredientListStatus
            if texts.isEmpty {
                status = .unavailable
            } else if let raw = snapshot?.listStatus, let stored = IngredientListStatus(rawValue: raw) {
                status = stored
            } else {
                // Manual-product input has no attestation of list completeness.
                status = .partial
            }
            return normalizer.normalizeStoredProduct(
                id: step.id.uuidString, ingredientTexts: status == .unavailable ? [] : texts, listStatus: status
            )
        }
        return AnalysisRequestPayload(contractVersion: 1, period: period.rawValue.lowercased(),
                                      recordedAllergies: RecordedAllergiesPayload(status: "unknown", ingredientIDs: nil),
                                      products: products)
    }
}
