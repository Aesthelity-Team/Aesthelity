//
//  FirebaseAuthService.swift
//  Aesthelity
//
//  Authentication service managing Firebase Auth sessions (Email/Password & Anonymous)
//  with Keychain session persistence and domain-level error mapping.
//

import Combine
import FirebaseAuth
import Foundation

@MainActor
public final class FirebaseAuthService: ObservableObject, AuthServiceProtocol {
    public static let shared = FirebaseAuthService()

    @Published public private(set) var currentUser: UserAccount?
    @Published public private(set) var userId: String?
    @Published public private(set) var userEmail: String?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isAnonymous: Bool = false
    @Published public private(set) var authError: String?
    @Published public private(set) var isLoading: Bool = false

    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private let keychain: KeychainManagerProtocol
    private let sessionUserKey = "active_session_user_id"

    public init(keychain: KeychainManagerProtocol = KeychainManager.shared) {
        self.keychain = keychain
        if let current = Auth.auth().currentUser {
            let account = UserAccount(
                id: current.uid,
                email: current.email ?? "",
                isAnonymous: current.isAnonymous
            )
            self.currentUser = account
            self.userId = current.uid
            self.userEmail = current.email
            self.isAuthenticated = true
            self.isAnonymous = current.isAnonymous
            try? keychain.save(string: current.uid, forKey: sessionUserKey)
        }
        setupAuthStateListener()
    }

    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func setupAuthStateListener() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let user = user {
                    let account = UserAccount(
                        id: user.uid,
                        email: user.email ?? "",
                        isAnonymous: user.isAnonymous
                    )
                    self.currentUser = account
                    self.userId = user.uid
                    self.userEmail = user.email
                    self.isAuthenticated = true
                    self.isAnonymous = user.isAnonymous
                    try? self.keychain.save(string: user.uid, forKey: self.sessionUserKey)
                } else {
                    self.currentUser = nil
                    self.userId = nil
                    self.userEmail = nil
                    self.isAuthenticated = false
                    self.isAnonymous = false
                    try? self.keychain.delete(forKey: self.sessionUserKey)
                }
            }
        }
    }

    /// Automatically signs in anonymously if no user is authenticated yet,
    /// providing an immediate unique Firebase UID for Firestore synchronization.
    public func ensureAuthenticated() async {
        guard Auth.auth().currentUser == nil else { return }
        do {
            isLoading = true
            defer { isLoading = false }
            let result = try await Auth.auth().signInAnonymously()
            let account = UserAccount(
                id: result.user.uid,
                email: result.user.email ?? "",
                isAnonymous: result.user.isAnonymous
            )
            self.currentUser = account
            self.userId = result.user.uid
            self.userEmail = result.user.email
            self.isAuthenticated = true
            self.isAnonymous = result.user.isAnonymous
            self.authError = nil
            try? self.keychain.save(string: result.user.uid, forKey: self.sessionUserKey)
        } catch {
            let mapped = mapError(error)
            self.authError = mapped.localizedDescription
        }
    }

    /// Sign in with an existing email and password.
    @discardableResult
    public func signIn(email: String, password: String) async throws -> UserAccount {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard case .success(let validEmail) = AuthValidator.validateEmail(trimmedEmail) else {
            let err = AuthError.invalidEmail
            self.authError = err.localizedDescription
            throw err
        }
        guard !password.isEmpty else {
            let err = AuthError.missingFields
            self.authError = err.localizedDescription
            throw err
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: validEmail, password: password)
            let account = UserAccount(
                id: result.user.uid,
                email: result.user.email ?? "",
                isAnonymous: result.user.isAnonymous
            )
            self.currentUser = account
            self.userId = result.user.uid
            self.userEmail = result.user.email
            self.isAuthenticated = true
            self.isAnonymous = result.user.isAnonymous
            self.authError = nil
            try? self.keychain.save(string: result.user.uid, forKey: self.sessionUserKey)
            return account
        } catch {
            let mapped = mapError(error)
            self.authError = mapped.localizedDescription
            throw mapped
        }
    }

    /// Create a new account with email and password.
    @discardableResult
    public func signUp(email: String, password: String) async throws -> UserAccount {
        let validated = try AuthValidator.validateCredentials(email: email, password: password).get()
        let trimmedEmail = validated.email.lowercased()

        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: validated.password)
            let account = UserAccount(
                id: result.user.uid,
                email: result.user.email ?? "",
                isAnonymous: result.user.isAnonymous
            )
            self.currentUser = account
            self.userId = result.user.uid
            self.userEmail = result.user.email
            self.isAuthenticated = true
            self.isAnonymous = result.user.isAnonymous
            self.authError = nil
            try? self.keychain.save(string: result.user.uid, forKey: self.sessionUserKey)
            return account
        } catch {
            let mapped = mapError(error)
            self.authError = mapped.localizedDescription
            throw mapped
        }
    }

    /// Sign out of the current Firebase session and clear secure keychain tokens.
    public func signOut() throws {
        try Auth.auth().signOut()
        try? keychain.delete(forKey: sessionUserKey)
        self.currentUser = nil
        self.userId = nil
        self.userEmail = nil
        self.isAuthenticated = false
        self.isAnonymous = false
        self.authError = nil
    }

    // MARK: - Error Mapping
    private func mapError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return .unknown(message: error.localizedDescription)
        }
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown(message: error.localizedDescription)
        }
        switch code {
        case .invalidEmail:
            return .invalidEmail
        case .wrongPassword, .userNotFound:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword(reason: "Password does not meet security requirements.")
        case .networkError:
            return .networkError
        case .userDisabled:
            return .invalidCredentials
        default:
            return .unknown(message: error.localizedDescription)
        }
    }
}
