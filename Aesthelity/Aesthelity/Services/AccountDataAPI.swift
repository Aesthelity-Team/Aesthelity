import FirebaseAuth
import Foundation

/// Separate from the token-free loopback demo configuration. An empty value
/// deliberately leaves account operations unavailable until HTTPS is deployed.
enum ProtectedAPIConfiguration {
@MainActor static func baseURL(bundle: Bundle = .main) throws -> URL {
    guard let value = bundle.object(forInfoDictionaryKey: "AesthelityProtectedAPIBaseURL") as? String,
          !value.isEmpty,
          let url = URL(string: value) else {
        throw APIClientError.configuration
    }

    let scheme = url.scheme?.lowercased()
    let host = url.host?.lowercased()
    let isHTTPS = scheme == "https"

    #if DEBUG
    let isLocalHTTP = scheme == "http"
        && ["127.0.0.1", "localhost", "::1", "[::1]"].contains(host ?? "")
    #else
    let isLocalHTTP = false
    #endif

    guard (isHTTPS || isLocalHTTP),
          host != nil,
          url.user == nil,
          url.password == nil,
          url.query == nil,
          url.fragment == nil else {
        throw APIClientError.configuration
    }

    return url
    }
}

struct AccountIdentity: Equatable {
    let uid: String
    let session: String

    @MainActor static func current() -> Self? {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        let auth = FirebaseAuthService.shared
        guard auth.isAuthenticated, !auth.isAnonymous, auth.userId == user.uid else { return nil }
        return Self(uid: user.uid, session: String(describing: ObjectIdentifier(user)) + auth.apiSessionRevision.uuidString)
    }
}

private struct PrivateWrite<Value: Encodable>: Encodable {
    let contractVersion = 1
    let data: Value
}

private struct PrivateRecord<Value: Decodable>: Decodable {
    let id: String
    let ownerUID: String
    let data: Value
}

private struct PrivateResponse<Value: Decodable>: Decodable {
    let contractVersion: Int
    let record: PrivateRecord<Value>
}

/// Every operation is bound to the Firebase user object that started it.
/// Sign-out/re-sign-in, including to the same UID, invalidates its completion.
@MainActor
struct AccountDataAPI {
    let identity: AccountIdentity
    private let currentIdentity: () -> AccountIdentity?
    private let client: AuthenticatedAPIClient

    init(baseURL: URL, identity: AccountIdentity,
         currentIdentity: @escaping () -> AccountIdentity? = AccountIdentity.current,
         token: @escaping () async throws -> String = FirebaseAPITokenProvider.token,
         transport: AuthenticatedAPIClient.Transport? = nil) throws {
        self.identity = identity
        self.currentIdentity = currentIdentity
        let boundToken: () async throws -> String = {
            guard currentIdentity() == identity else { throw APIClientError.signInRequired }
            let credential = try await token()
            guard currentIdentity() == identity else { throw APIClientError.signInRequired }
            return credential
        }
        if let transport {
            client = try AuthenticatedAPIClient(baseURL: baseURL, token: boundToken, transport: transport)
        } else {
            client = try AuthenticatedAPIClient(baseURL: baseURL, token: boundToken)
        }
    }

    static func configured() throws -> Self {
        guard let identity = AccountIdentity.current() else { throw APIClientError.signInRequired }
        return try Self(baseURL: ProtectedAPIConfiguration.baseURL(), identity: identity)
    }

    func checkSession() throws {
        try Task.checkCancellation()
        guard currentIdentity() == identity else { throw APIClientError.signInRequired }
    }

    func load<Value: Decodable>(_ kind: String, id: String, as: Value.Type) async throws -> Value {
        try checkSession()
        let response = try await client.get(path(kind, id), as: PrivateResponse<Value>.self)
        return try validated(response, id: id)
    }

    func save<Value: Codable>(_ value: Value, kind: String, id: String) async throws {
        try checkSession()
        let response = try await client.put(path(kind, id), body: PrivateWrite(data: value), as: PrivateResponse<Value>.self)
        let _: Value = try validated(response, id: id)
    }

    func analyze(_ payload: AnalysisRequestPayload, catalogVersion: Int) async throws -> AnalysisResponsePayload {
        try checkSession()
        let response = try await BackendAnalysisAPI.analyzeAuthenticated(
            payload: payload, expectedCatalogVersion: catalogVersion, client: client
        )
        try checkSession()
        return response
    }

    static func validate(_ response: AnalysisResponsePayload, for payload: AnalysisRequestPayload, catalogVersion: Int) throws {
        guard response.contractVersion == 1, response.activeCatalogVersion == catalogVersion,
              response.period == payload.period,
              response.productIDs.count == payload.products.count,
              Set(response.productIDs) == Set(payload.products.map(\.productID)),
              ["noFindings", "findings"].contains(response.outcome),
              ["complete", "incomplete"].contains(response.completeness),
              response.findings.allSatisfy({ Set($0.productIDs).isSubset(of: Set(response.productIDs)) }) else {
            throw APIClientError.invalidResponse
        }
    }

    private func path(_ kind: String, _ id: String) -> [String] {
        ["api", "v1", "users", identity.uid, kind, id]
    }

    private func validated<Value>(_ response: PrivateResponse<Value>, id: String) throws -> Value {
        try checkSession()
        guard response.contractVersion == 1, response.record.ownerUID == identity.uid,
              response.record.id == id else { throw APIClientError.invalidResponse }
        return response.record.data
    }
}

enum AccountDataValidation {
    static func profile(_ value: SkinProfile) throws {
        guard value.schemaVersion == 1 else { throw APIClientError.invalidResponse }
    }

    static func routines(_ value: RoutineStorageDocument) throws {
        guard value.schemaVersion == 1,
              Set(value.routines.map(\.id)).count == value.routines.count,
              value.routines.allSatisfy({ routine in
                  !routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  routine.steps.count <= RoutineEditor.maximumSteps &&
                  Set(routine.steps.map(\.id)).count == routine.steps.count &&
                  routine.steps.enumerated().allSatisfy { $0.element.stepNumber == $0.offset + 1 }
              }) else { throw APIClientError.invalidResponse }
    }
}
