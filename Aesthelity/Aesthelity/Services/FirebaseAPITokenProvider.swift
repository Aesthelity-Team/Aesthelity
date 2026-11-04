import FirebaseAuth
import Foundation

@MainActor
enum FirebaseAPITokenProvider {
    /// Firebase refreshes expired ID tokens. Never persist tokens in app settings,
    /// log them, or silently create an anonymous session for a protected request.
    static func token() async throws -> String {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else {
            throw APIClientError.signInRequired
        }
        let uid = user.uid
        let token = try await user.getIDToken()
        guard let current = Auth.auth().currentUser,
              current.uid == uid, !current.isAnonymous else {
            throw APIClientError.signInRequired
        }
        return token
    }
}
