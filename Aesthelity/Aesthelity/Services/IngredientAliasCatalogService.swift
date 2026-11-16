import Foundation

/// Fetches the current shared catalog for each product-processing flow.
/// The bundled catalog keeps deterministic normalization available offline.
struct IngredientAliasCatalogService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadCatalog() async throws -> IngredientAliasCatalog {
        let bundled = try IngredientAliasCatalog.loadBundled()
        do {
            let root = try baseURL()
            let url = root.appendingPathComponent("api")
                .appendingPathComponent("v1")
                .appendingPathComponent("ingredient-aliases")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return bundled
            }
            return try IngredientAliasCatalog.load(data: data)
        } catch {
            return bundled
        }
    }

    private func baseURL() throws -> URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "AesthelityAPIBaseURL") as? String
            ?? "http://127.0.0.1:8765"
        guard let url = URL(string: configured), url.scheme != nil, url.host != nil else {
            throw URLError(.badURL)
        }
        return url
    }
}
