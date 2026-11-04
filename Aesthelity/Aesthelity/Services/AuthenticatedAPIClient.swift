import Foundation

/// Errors expose safe UI copy, never raw server bodies or credentials.
enum APIClientError: LocalizedError, Equatable {
    case configuration, signInRequired, forbidden, server(Int), invalidResponse, unavailable

    var errorDescription: String? {
        switch self {
        case .configuration: return "A secure backend connection has not been configured."
        case .signInRequired: return "Your session could not be verified. Please sign in again."
        case .forbidden: return "You do not have access to this data."
        case .server: return "The server could not complete the request. Please try again."
        case .invalidResponse: return "The server returned an unreadable response."
        case .unavailable: return "The backend is unavailable. Check your connection and try again."
        }
    }
}

/// Authenticated transport for protected endpoints. Demo HTTP traffic uses the
/// separate BackendAnalysisAPI initializer and never receives Firebase tokens.
@MainActor
struct AuthenticatedAPIClient {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private let baseURL: URL
    private let token: () async throws -> String
    private let transport: Transport

    init(baseURL: URL, token: @escaping () async throws -> String,
         transport: @escaping Transport = { request in
             try await PrivateAPISession.session.data(for: request, delegate: NoAPIRedirects())
         }) throws {
        guard baseURL.scheme?.lowercased() == "https", baseURL.host != nil,
              baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil else {
            throw APIClientError.configuration
        }
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: [String], body: Body, as: Response.Type
    ) async throws -> Response {
        guard !path.isEmpty, path.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") }) else {
            throw APIClientError.configuration
        }
        let url = path.reduce(baseURL) { $0.appendingPathComponent($1) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let credential: String
        do { credential = try await token() }
        catch is CancellationError { throw CancellationError() }
        catch { throw APIClientError.signInRequired }
        guard !credential.isEmpty, !credential.contains(where: { $0.isWhitespace || $0.isNewline }) else {
            throw APIClientError.signInRequired
        }
        try Task.checkCancellation()
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await transport(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw APIClientError.unavailable }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw APIClientError.signInRequired
        case 403: throw APIClientError.forbidden
        default: throw APIClientError.server(http.statusCode)
        }
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch { throw APIClientError.invalidResponse }
    }
}

/// Never forward bearer credentials or replay a POST through a redirect.
private final class NoAPIRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private enum PrivateAPISession {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()
}
