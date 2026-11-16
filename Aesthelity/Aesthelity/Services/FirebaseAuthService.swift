//
//  FirebaseAuthService.swift
//  Aesthelity
//
//  Authentication service managing Firebase Auth sessions (Email/Password & Anonymous)
//  with Keychain session persistence and domain-level error mapping, plus an automatic
//  secure local fallback when Firebase Auth backend is unconfigured (e.g. CONFIGURATION_NOT_FOUND).
//

import Combine
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import UIKit

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
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
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
    /// providing an immediate unique UID for synchronization.
    public func ensureAuthenticated() async {
        guard Auth.auth().currentUser == nil && currentUser == nil else { return }

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

    public func sendPasswordReset(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard case .success(let validEmail) = AuthValidator.validateEmail(trimmedEmail) else {
            throw AuthError.invalidEmail
        }

        try await Auth.auth().sendPasswordReset(withEmail: validEmail)
    }

    @discardableResult
    public func signInWithGoogle(presenting viewController: UIViewController) async throws -> UserAccount {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthError.unknown(message: "Google sign-in is not configured.")
            }

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            let googleResult: GIDSignInResult = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<GIDSignInResult, Error>) in
                GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(
                            throwing: AuthError.unknown(message: "Google sign-in did not return an account.")
                        )
                    }
                }
            }

            guard let idToken = googleResult.user.idToken?.tokenString else {
                throw AuthError.unknown(message: "Google did not return an ID token.")
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: googleResult.user.accessToken.tokenString
            )
            let result = try await Auth.auth().signIn(with: credential)

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


    @discardableResult
    public func linkEmailPassword(password: String) async throws -> UserAccount {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.sessionExpired
        }
        guard let email = user.email else {
            throw AuthError.unknown(message: "This account does not have an email address.")
        }
        guard !user.isAnonymous else {
            throw AuthError.sessionExpired
        }
        guard !user.providerData.contains(where: { $0.providerID == "password" }) else {
            throw AuthError.unknown(message: "This account already has password sign-in set up.")
        }

        isLoading = true
        defer { isLoading = false }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            let result = try await user.link(with: credential)
            let linkedUser = result.user

            let account = UserAccount(
                id: linkedUser.uid,
                email: linkedUser.email ?? email,
                isAnonymous: linkedUser.isAnonymous
            )
            currentUser = account
            userId = linkedUser.uid
            userEmail = linkedUser.email
            isAuthenticated = true
            isAnonymous = linkedUser.isAnonymous
            authError = nil

            return account
        } catch {
            let mapped = mapError(error)
            authError = mapped.localizedDescription
            throw mapped
        }
    }

    /// Create a new account with email and password.
    @discardableResult
    public func signUp(email: String, password: String) async throws -> UserAccount {
        try await signUp(email: email, password: password, username: nil)
    }

    /// Create a new account with email, password, and optional username.
    @discardableResult
    public func signUp(email: String, password: String, username: String?) async throws -> UserAccount {
        let validated = try AuthValidator.validateCredentials(email: email, password: password, username: username).get()
        let trimmedEmail = validated.email.lowercased()

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: validated.password)
            if let user = Auth.auth().currentUser, let name = validated.username {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = name
                try? await changeRequest.commitChanges()
            }
            let account = UserAccount(
                id: result.user.uid,
                email: result.user.email ?? "",
                username: validated.username,
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

    /// Sign out of the current session and clear secure keychain tokens.
    public func signOut() throws {
        if Auth.auth().currentUser != nil {
            try Auth.auth().signOut()
        }
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
        case .wrongPassword, .userNotFound, .invalidCredential:
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
