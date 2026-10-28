import Foundation

struct ProductListResponse: Decodable {
    let contractVersion: Int
    let products: [DemoProduct]
}

struct RecordedAllergiesPayload: Encodable {
    let status: String
    let ingredientIDs: [String]
}

struct AnalysisRequestPayload: Encodable {
    let contractVersion: Int
    let period: String
    let recordedAllergies: RecordedAllergiesPayload
    let products: [NormalizedProductIngredients]
}

struct AnalysisResponsePayload: Decodable {
    let contractVersion: Int
    let ruleVersion: String
    let period: String
    let activeCatalogVersion: Int
    let outcome: String
    let completeness: String
    let productIDs: [String]
    let findings: [AnalysisFindingPayload]
    let limitations: [String]
    let displayLabel: String?
}

struct AnalysisFindingPayload: Decodable {
    let ruleID: String
    let ruleStatus: String
    let outcome: String
    let categoryID: String
    let severity: String?
    let productIDs: [String]
    let ingredientIDs: [String]
    let matchedClassIDs: [String]?
    let explanation: String
    let reason: String
    let limitations: [String]
}

struct LiveAnalysisResult {
    let response: AnalysisResponsePayload
    let productNames: [String: String]
}

enum AnalysisDemoScenario: String, CaseIterable, Identifiable {
    case cautionPM
    case noFindingAM
    case allergyMatch
    case partialProduct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cautionPM: return "Caution · PM"
        case .noFindingAM: return "No findings · AM"
        case .allergyMatch: return "Recorded allergy"
        case .partialProduct: return "Partial ingredient list"
        }
    }

    var period: String {
        switch self {
        case .noFindingAM: return "am"
        case .cautionPM, .allergyMatch, .partialProduct: return "pm"
        }
    }

    var productIDs: [String] {
        switch self {
        case .cautionPM: return ["serum_retinol", "treatment_exfoliant"]
        case .noFindingAM: return ["cleanser_gel", "serum_vitamin_c", "moisturizer_gel", "sunscreen_mineral"]
        case .allergyMatch: return ["mist_fragranced"]
        case .partialProduct: return ["mask_partial"]
        }
    }

    var allergyIDs: [String] {
        self == .allergyMatch ? ["limonene"] : []
    }

    var explanation: String {
        switch self {
        case .cautionPM:
            return "Fictional PM demo routine using products retrieved from the shared Firestore catalog."
        case .noFindingAM:
            return "Fictional AM demo routine using products retrieved from the shared Firestore catalog."
        case .allergyMatch:
            return "Demo profile records limonene as an allergy; this is not your saved profile."
        case .partialProduct:
            return "Uses the Firestore mask_partial record. Its ingredient list is explicitly partial."
        }
    }
}

enum BackendAnalysisAPIError: LocalizedError {
    case badURL
    case invalidResponse
    case server(status: Int, message: String)
    case missingProduct(String)
    case catalogVersionMismatch(expected: Int, received: Int)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "The analysis API address is invalid."
        case .invalidResponse:
            return "The analysis API returned an unreadable response."
        case .server(_, let message):
            return message
        case .missingProduct(let productID):
            return "Product \(productID) was not returned by the Firestore catalog API."
        case .catalogVersionMismatch(let expected, let received):
            return "The app alias catalog is version \(expected), but the API returned version \(received). Update both from the same alias file."
        }
    }
}

struct BackendAnalysisAPI {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func analyze(scenario: AnalysisDemoScenario) async throws -> LiveAnalysisResult {
        let root = try baseURL()
        let productURL = root.appendingPathComponent("api").appendingPathComponent("v1").appendingPathComponent("products")
        var listRequest = URLRequest(url: productURL)
        listRequest.httpMethod = "GET"
        let (listData, listResponse) = try await session.data(for: listRequest)
        try requireSuccess(listResponse, data: listData)

        let catalogResponse = try decoder.decode(ProductListResponse.self, from: listData)
        guard catalogResponse.contractVersion == 1 else {
            throw BackendAnalysisAPIError.invalidResponse
        }
        let selectedProducts = try scenario.productIDs.map { productID in
            guard let product = catalogResponse.products.first(where: { $0.id == productID }) else {
                throw BackendAnalysisAPIError.missingProduct(productID)
            }
            return product
        }

        let aliasCatalog = try IngredientAliasCatalog.loadBundled()
        let normalizer = IngredientNormalizer(catalog: aliasCatalog)
        let normalizedProducts = selectedProducts.map(normalizer.normalizeCatalogProduct)
        let payload = AnalysisRequestPayload(
            contractVersion: 1,
            period: scenario.period,
            recordedAllergies: RecordedAllergiesPayload(status: "known", ingredientIDs: scenario.allergyIDs),
            products: normalizedProducts
        )

        let analysisURL = root.appendingPathComponent("api").appendingPathComponent("v1").appendingPathComponent("analyses")
        var analysisRequest = URLRequest(url: analysisURL)
        analysisRequest.httpMethod = "POST"
        analysisRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        analysisRequest.httpBody = try encoder.encode(payload)
        let (analysisData, analysisResponse) = try await session.data(for: analysisRequest)
        try requireSuccess(analysisResponse, data: analysisData)

        let result = try decoder.decode(AnalysisResponsePayload.self, from: analysisData)
        guard result.contractVersion == 1,
              result.activeCatalogVersion == aliasCatalog.version else {
            throw BackendAnalysisAPIError.catalogVersionMismatch(
                expected: aliasCatalog.version,
                received: result.activeCatalogVersion
            )
        }
        let names = Dictionary(uniqueKeysWithValues: selectedProducts.map { ($0.id, $0.name) })
        return LiveAnalysisResult(response: result, productNames: names)
    }

    private func baseURL() throws -> URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "AesthelityAPIBaseURL") as? String
            ?? "http://127.0.0.1:8765"
        guard let url = URL(string: configured), url.scheme != nil, url.host != nil else {
            throw BackendAnalysisAPIError.badURL
        }
        return url
    }

    private func requireSuccess(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BackendAnalysisAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw BackendAnalysisAPIError.server(
                status: http.statusCode,
                message: problem?.error.message ?? "Analysis API request failed (HTTP \(http.statusCode))."
            )
        }
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Problem: Decodable {
        let code: String
        let message: String
    }
    let error: Problem
}
