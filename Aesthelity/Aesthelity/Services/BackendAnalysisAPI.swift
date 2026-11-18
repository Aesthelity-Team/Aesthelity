import Foundation

struct ProductListResponse: Decodable {
    let contractVersion: Int
    let products: [DemoProduct]
}

struct RecordedAllergiesPayload: Codable, Equatable {
    let status: String
    let ingredientIDs: [String]?

    private enum CodingKeys: String, CodingKey {
        case status, ingredientIDs
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(ingredientIDs, forKey: .ingredientIDs)
    }
}

struct AnalysisRequestPayload: Codable, Equatable {
    let contractVersion: Int
    let period: String
    let recordedAllergies: RecordedAllergiesPayload
    let products: [NormalizedProductIngredients]
}


struct AnalysisCoveragePayload: Codable, Equatable {
    let status: String
    let unknownIngredientCount: Int
    let missingReferenceCount: Int
    let limitations: [String]

    var isComplete: Bool {
        status == "complete"
    }
}

struct AnalysisResponsePayload: Codable, Equatable {

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
    let coverage: AnalysisCoveragePayload?
    let summary: String?

    var hasCompleteCoverage: Bool {
        if let coverage {
            return coverage.isComplete
        }
        return completeness == "complete"
    }

    var isLimitedCoverage: Bool {
        !hasCompleteCoverage
    }
}

struct AnalysisFindingPayload: Codable, Equatable {
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
    let originalText: String?
    let rowIndex: Int?

    var isUnknownOrCoverageGap: Bool {
        outcome == "unknown" || categoryID == "coverage-gap"
    }
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
    case unavailableProduct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cautionPM: return "Caution · PM"
        case .noFindingAM: return "No findings · AM"
        case .allergyMatch: return "Recorded allergy"
        case .partialProduct: return "Partial ingredient list"
        case .unavailableProduct: return "Unavailable ingredient list"
        }
    }

    var period: String {
        switch self {
        case .noFindingAM: return "am"
        case .cautionPM, .allergyMatch, .partialProduct, .unavailableProduct: return "pm"
        }
    }

    var productIDs: [String] {
        switch self {
        case .cautionPM: return ["serum_retinol", "treatment_exfoliant"]
        case .noFindingAM: return ["cleanser_gel", "serum_vitamin_c", "moisturizer_gel", "sunscreen_mineral"]
        case .allergyMatch: return ["mist_fragranced"]
        case .partialProduct: return ["mask_partial"]
        case .unavailableProduct: return ["sunscreen_unknown"]
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
        case .unavailableProduct:
            return "Uses the Firestore sunscreen_unknown record. Its ingredient list is completely unavailable."
        }
    }
}

enum BackendAnalysisAPIError: LocalizedError {
    case badURL
    case invalidResponse
    case server(status: Int, message: String)
    case missingProduct(String)
    case catalogVersionMismatch(expected: Int, received: Int)
    case authenticationRequired
    case authenticationTokenUnavailable

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
            return "The app used alias catalog version \(expected), but the API analyzed version \(received). Reload the shared catalog and try again."
        case .authenticationRequired:
            return "Please sign in to analyze this routine."
        case .authenticationTokenUnavailable:
            return "Could not get your sign-in token. Please try again."
        }
    }
}

struct BackendAnalysisAPI {
    let session: URLSession
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

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

        let aliasCatalog = try await IngredientAliasCatalogService(session: session).loadCatalog()
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
        let names = Dictionary(uniqueKeysWithValues: selectedProducts.map { ($0.id, $0.name) } as [(String, String)])
        return LiveAnalysisResult(response: result, productNames: names)
    }

    /// Protected analysis for real inputs; never substitutes a fictional scenario.
    /// The caller owns loading/error presentation and retains local data on failure.
    @MainActor
    static func analyzeAuthenticated(
        payload: AnalysisRequestPayload,
        expectedCatalogVersion: Int,
        baseURL: URL,
        token: @escaping () async throws -> String = FirebaseAPITokenProvider.token
    ) async throws -> AnalysisResponsePayload {
        let client = try AuthenticatedAPIClient(baseURL: baseURL, token: token)
        return try await analyzeAuthenticated(payload: payload, expectedCatalogVersion: expectedCatalogVersion, client: client)
    }

    /// Uses the session-bound client supplied by AccountDataAPI.
    @MainActor
    static func analyzeAuthenticated(
        payload: AnalysisRequestPayload,
        expectedCatalogVersion: Int,
        client: AuthenticatedAPIClient
    ) async throws -> AnalysisResponsePayload {
        let result = try await client.post(
            ["api", "v1", "analyses"], body: payload, as: AnalysisResponsePayload.self
        )
        try AccountDataAPI.validate(result, for: payload, catalogVersion: expectedCatalogVersion)
        return result
    }

    func baseURL() throws -> URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "AesthelityAPIBaseURL") as? String
            ?? "http://127.0.0.1:8765"
        guard let url = URL(string: configured), url.scheme == "http",
              ["127.0.0.1", "localhost", "[::1]"].contains(url.host ?? ""),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw BackendAnalysisAPIError.badURL
        }
        return url
    }

    func requireSuccess(_ response: URLResponse, data: Data) throws {
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
