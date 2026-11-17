import Foundation
import FirebaseAuth

// IngredientResolveAPI.swift — iOS client for #98 ingredient resolution.
// Calls POST /api/v1/ingredients/resolve (AI-primary by default). Review uses
// persist: false; Save (signed-in) uses persist: true with ManualProduct.id as
// productID. Manual full-list entry also sends format: analysis-input and
// listStatus: complete (listStatus is ignored without format). See
// Backend/README.md → "Ingredient resolution (#98)".

/// Request/response types for `POST /api/v1/ingredients/resolve` (#98).
struct IngredientResolveRequest: Encodable {
    let contractVersion: Int
    let ingredients: [String]
    let ai: Bool
    let productID: String?
    let persist: Bool
    let sourceType: String?
    /// When set, must be `analysis-input` so the backend attaches the #99 envelope.
    let format: String?
    /// Only applied when `format` is `analysis-input` (`complete` | `partial` | `unavailable`).
    let listStatus: String?

    init(
        ingredients: [String],
        ai: Bool = true,
        productID: String? = nil,
        persist: Bool = false,
        sourceType: String? = nil,
        format: String? = nil,
        listStatus: String? = nil
    ) {
        self.contractVersion = 1
        self.ingredients = ingredients
        self.ai = ai
        self.productID = productID
        self.persist = persist
        self.sourceType = sourceType
        self.format = format
        self.listStatus = listStatus
    }
}

struct IngredientResolveResponse: Decodable, Equatable {
    let contractVersion: Int
    let status: String?
    let coverage: String?
    let failureCode: String?
    let providerStatus: String?
    let ingredients: [IngredientResolveRow]
}

struct IngredientResolveRow: Decodable, Equatable {
    let index: Int
    let originalText: String
    let status: String?
    let mapping: String
    let ingredientID: String?
    let suggestedID: String?
    let candidateIDs: [String]?
    let normalizedName: String?
    let bestGuess: String?
    let explanation: String?
    let reason: String?
    let canonicalName: String?

    /// Maps a backend resolve row into the app's stored `NormalizedIngredient` shape.
    ///
    /// Display rules for the manual-entry review list:
    /// - confirmed → identified (no warning)
    /// - CosIng / catalog uncertain with suggestedID → best guess via suggestedID
    /// - AI tentative without a catalog ID → unmatched + warning carrying the best guess
    /// - ambiguous / unmatched → keep existing warning style
    func asNormalizedIngredient() -> NormalizedIngredient {
        let mappingValue = NormalizedIngredient.Mapping(rawValue: mapping) ?? .unmatched
        let candidates = candidateIDs ?? []
        switch mappingValue {
        case .confirmed:
            if let id = ingredientID, CanonicalIngredientID.isValid(id) {
                return NormalizedIngredient(originalText: originalText, status: .matched(ingredientID: id), warning: nil)
            }
            return NormalizedIngredient(
                originalText: originalText,
                status: .unmatched,
                warning: NormalizationWarning(
                    input: originalText,
                    message: explanation ?? reason ?? "Identified match could not be stored."
                )
            )
        case .uncertain:
            if let id = suggestedID, CanonicalIngredientID.isValid(id) {
                let guess = bestGuess ?? canonicalName ?? normalizedName ?? id
                return NormalizedIngredient(
                    originalText: originalText,
                    status: .uncertain(suggestedID: id),
                    warning: NormalizationWarning(
                        input: originalText,
                        message: "Best guess: \(guess). \(explanation ?? reason ?? "Not approved for analysis yet.")"
                    )
                )
            }
            let guess = bestGuess ?? canonicalName ?? normalizedName
            let detail: String
            if let guess, !guess.isEmpty {
                detail = "Best guess: \(guess). \(explanation ?? reason ?? "Identity is uncertain.")"
            } else {
                detail = explanation ?? reason ?? "Identity is uncertain."
            }
            return NormalizedIngredient(
                originalText: originalText,
                status: .unmatched,
                warning: NormalizationWarning(input: originalText, message: detail)
            )
        case .ambiguous:
            let ids = candidates.filter(CanonicalIngredientID.isValid)
            if ids.count >= 2 {
                return NormalizedIngredient(
                    originalText: originalText,
                    status: .ambiguous(candidateIDs: ids),
                    warning: NormalizationWarning(
                        input: originalText,
                        message: explanation ?? reason ?? "\"\(originalText)\" could refer to more than one ingredient."
                    )
                )
            }
            return NormalizedIngredient(
                originalText: originalText,
                status: .unmatched,
                warning: NormalizationWarning(
                    input: originalText,
                    message: explanation ?? reason ?? "\"\(originalText)\" could not be identified."
                )
            )
        case .unmatched:
            return NormalizedIngredient(
                originalText: originalText,
                status: .unmatched,
                warning: NormalizationWarning(
                    input: originalText,
                    message: explanation ?? reason ?? "\"\(originalText)\" does not match any known ingredient."
                )
            )
        }
    }
}

extension BackendAnalysisAPI {
    /// Resolve label strings through the #98 backend (AI-primary by default).
    func resolveIngredients(
        _ texts: [String],
        productID: String? = nil,
        persist: Bool = false,
        sourceType: String? = "manual",
        ai: Bool = true,
        format: String? = nil,
        listStatus: String? = nil
    ) async throws -> IngredientResolveResponse {
        let root = try baseURL()
        let url = root
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("ingredients")
            .appendingPathComponent("resolve")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let user = Auth.auth().currentUser {
            do {
                let token = try await user.getIDToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } catch {
                throw BackendAnalysisAPIError.authenticationTokenUnavailable
            }
        }
        let payload = IngredientResolveRequest(
            ingredients: texts,
            ai: ai,
            productID: productID,
            persist: persist,
            sourceType: persist ? sourceType : nil,
            format: format,
            listStatus: listStatus
        )
        request.httpBody = try encoder.encode(payload)
        let (data, response) = try await session.data(for: request)
        try requireSuccess(response, data: data)
        let decoded = try decoder.decode(IngredientResolveResponse.self, from: data)
        guard decoded.contractVersion == 1 else {
            throw BackendAnalysisAPIError.invalidResponse
        }
        return decoded
    }
}
