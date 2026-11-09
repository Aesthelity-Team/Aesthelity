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

@MainActor
public final class FirebaseAuthService: ObservableObject, AuthServiceProtocol {
    public static let shared = FirebaseAuthService()

    public struct LocalUserRecord: Codable, Sendable {
        public let account: UserAccount
        public let passwordHash: String
        public let salt: String

        public init(account: UserAccount, passwordHash: String, salt: String) {
            self.account = account
            self.passwordHash = passwordHash
            self.salt = salt
        }
    }

    @Published public private(set) var currentUser: UserAccount?
    @Published public private(set) var userId: String?
    @Published public private(set) var userEmail: String?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isAnonymous: Bool = false
    @Published public private(set) var authError: String?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isFallbackActive: Bool = false

    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private let keychain: KeychainManagerProtocol
    private let sessionUserKey = "active_session_user_id"
    private let localSessionUserKey = "local_active_session_user"
    private let localUsersStoreKey = "local_registered_users_store"

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
        } else if let savedSessionData = try? keychain.readData(forKey: localSessionUserKey),
                  let savedAccount = try? JSONDecoder().decode(UserAccount.self, from: savedSessionData) {
            self.currentUser = savedAccount
            self.userId = savedAccount.id
            self.userEmail = savedAccount.email
            self.isAuthenticated = true
            self.isAnonymous = savedAccount.isAnonymous
            self.isFallbackActive = true
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
                // Only let Firebase listener override if not running in local fallback session
                guard !self.isFallbackActive else { return }
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
        if isFallbackActive {
            performLocalAnonymousSignIn()
            return
        }
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
            if isConfigurationNotFoundError(error) {
                isFallbackActive = true
                performLocalAnonymousSignIn()
            } else {
                let mapped = mapError(error)
                self.authError = mapped.localizedDescription
            }
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

        if isFallbackActive {
            return try performLocalSignIn(email: validEmail, password: password)
        }

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
            if isConfigurationNotFoundError(error) {
                isFallbackActive = true
                return try performLocalSignIn(email: validEmail, password: password)
            }
            let mapped = mapError(error)
            self.authError = mapped.localizedDescription
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

        if isFallbackActive {
            return try performLocalSignUp(validated: validated)
        }

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
            if isConfigurationNotFoundError(error) {
                isFallbackActive = true
                return try performLocalSignUp(validated: validated)
            }
            let mapped = mapError(error)
            self.authError = mapped.localizedDescription
            throw mapped
        }
    }

    /// Sign out of the current session and clear secure keychain tokens.
    public func signOut() throws {
        if Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
        }
        try? keychain.delete(forKey: sessionUserKey)
        try? keychain.delete(forKey: localSessionUserKey)
        self.currentUser = nil
        self.userId = nil
        self.userEmail = nil
        self.isAuthenticated = false
        self.isAnonymous = false
        self.authError = nil
    }

    // MARK: - Local Fallback Implementation

    private func performLocalSignUp(validated: AuthCredentials) throws -> UserAccount {
        var users = loadLocalUsers()
        let trimmedEmail = validated.email.lowercased()
        if users[trimmedEmail] != nil {
            let err = AuthError.emailAlreadyInUse
            self.authError = err.localizedDescription
            throw err
        }
        let salt = PasswordHasher.generateSalt()
        let hash = PasswordHasher.hash(password: validated.password, salt: salt)
        let account = UserAccount(
            id: "local_" + UUID().uuidString.prefix(8).lowercased(),
            email: trimmedEmail,
            username: validated.username,
            isAnonymous: false
        )
        users[trimmedEmail] = LocalUserRecord(account: account, passwordHash: hash, salt: salt)
        saveLocalUsers(users)

        self.currentUser = account
        self.userId = account.id
        self.userEmail = account.email
        self.isAuthenticated = true
        self.isAnonymous = false
        self.authError = nil
        if let sessionData = try? JSONEncoder().encode(account) {
            try? keychain.save(data: sessionData, forKey: localSessionUserKey)
        }
        try? keychain.save(string: account.id, forKey: sessionUserKey)
        return account
    }

    private func performLocalSignIn(email: String, password: String) throws -> UserAccount {
        let users = loadLocalUsers()
        guard let record = users[email.lowercased()],
              PasswordHasher.verify(password: password, hash: record.passwordHash, salt: record.salt) else {
            let err = AuthError.invalidCredentials
            self.authError = err.localizedDescription
            throw err
        }
        self.currentUser = record.account
        self.userId = record.account.id
        self.userEmail = record.account.email
        self.isAuthenticated = true
        self.isAnonymous = false
        self.authError = nil
        if let sessionData = try? JSONEncoder().encode(record.account) {
            try? keychain.save(data: sessionData, forKey: localSessionUserKey)
        }
        try? keychain.save(string: record.account.id, forKey: sessionUserKey)
        return record.account
    }

    private func performLocalAnonymousSignIn() {
        let account = UserAccount(
            id: "local_anon_" + UUID().uuidString.prefix(8).lowercased(),
            email: "",
            isAnonymous: true
        )
        self.currentUser = account
        self.userId = account.id
        self.userEmail = nil
        self.isAuthenticated = true
        self.isAnonymous = true
        self.authError = nil
    }

    private func loadLocalUsers() -> [String: LocalUserRecord] {
        guard let data = try? keychain.readData(forKey: localUsersStoreKey),
              let dict = try? JSONDecoder().decode([String: LocalUserRecord].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func saveLocalUsers(_ users: [String: LocalUserRecord]) {
        if let data = try? JSONEncoder().encode(users) {
            try? keychain.save(data: data, forKey: localUsersStoreKey)
        }
    }

    private func isConfigurationNotFoundError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let errorDetails = "\(nsError.userInfo)"
        return errorDetails.contains("CONFIGURATION_NOT_FOUND") ||
               errorDetails.contains("OPERATION_NOT_ALLOWED") ||
               (nsError.code == 17999 && errorDetails.contains("CONFIGURATION_NOT_FOUND"))
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
