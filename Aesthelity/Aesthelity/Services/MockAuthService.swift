//
//  MockAuthService.swift
//  Aesthelity
//
//  In-memory mock authentication service for deterministic unit and UI testing.
//

import Combine
import Foundation

@MainActor
public final class MockAuthService: ObservableObject, AuthServiceProtocol {
    public struct StoredCredential: Sendable {
        public let passwordHash: String
        public let salt: String
        public let account: UserAccount

        public init(passwordHash: String, salt: String, account: UserAccount) {
            self.passwordHash = passwordHash
            self.salt = salt
            self.account = account
        }
    }

    @Published public private(set) var currentUser: UserAccount?
    @Published public private(set) var userId: String?
    @Published public private(set) var userEmail: String?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isAnonymous: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var authError: String?
    
    public var simulatedError: Error?
    public var registeredUsers: [String: StoredCredential] = [:]
    
    public init(initialUser: UserAccount? = nil) {
        if let initialUser = initialUser {
            self.currentUser = initialUser
            self.userId = initialUser.id
            self.userEmail = initialUser.email
            self.isAuthenticated = true
            self.isAnonymous = initialUser.isAnonymous
        }
    }
    
    public func ensureAuthenticated() async {
        guard currentUser == nil else { return }
        let anonymousUser = UserAccount(
            id: UUID().uuidString,
            email: "",
            isAnonymous: true
        )
        self.currentUser = anonymousUser
        self.userId = anonymousUser.id
        self.userEmail = nil
        self.isAuthenticated = true
        self.isAnonymous = true
        self.authError = nil
    }
    
    @discardableResult
    public func signUp(email: String, password: String) async throws -> UserAccount {
        if let simulatedError = simulatedError {
            self.authError = simulatedError.localizedDescription
            throw simulatedError
        }
        
        let validated = try AuthValidator.validateCredentials(email: email, password: password).get()
        let lowerEmail = validated.email.lowercased()
        
        if registeredUsers[lowerEmail] != nil {
            let error = AuthError.emailAlreadyInUse
            self.authError = error.localizedDescription
            throw error
        }
        
        let account = UserAccount(
            id: UUID().uuidString,
            email: lowerEmail,
            isAnonymous: false
        )
        let salt = PasswordHasher.generateSalt()
        let passwordHash = PasswordHasher.hash(password: validated.password, salt: salt)
        registeredUsers[lowerEmail] = StoredCredential(passwordHash: passwordHash, salt: salt, account: account)
        
        self.currentUser = account
        self.userId = account.id
        self.userEmail = account.email
        self.isAuthenticated = true
        self.isAnonymous = false
        self.authError = nil
        return account
    }
    
    @discardableResult
    public func signIn(email: String, password: String) async throws -> UserAccount {
        if let simulatedError = simulatedError {
            self.authError = simulatedError.localizedDescription
            throw simulatedError
        }
        
        guard let validEmail = try? AuthValidator.validateEmail(email).get() else {
            let error = AuthError.invalidEmail
            self.authError = error.localizedDescription
            throw error
        }
        guard !password.isEmpty else {
            let error = AuthError.missingFields
            self.authError = error.localizedDescription
            throw error
        }
        
        let lowerEmail = validEmail.lowercased()
        guard let entry = registeredUsers[lowerEmail],
              PasswordHasher.verify(password: password, hash: entry.passwordHash, salt: entry.salt) else {
            let error = AuthError.invalidCredentials
            self.authError = error.localizedDescription
            throw error
        }
        
        self.currentUser = entry.account
        self.userId = entry.account.id
        self.userEmail = entry.account.email
        self.isAuthenticated = true
        self.isAnonymous = false
        self.authError = nil
        return entry.account
    }
    
    public func signOut() throws {
        self.currentUser = nil
        self.userId = nil
        self.userEmail = nil
        self.isAuthenticated = false
        self.isAnonymous = false
        self.authError = nil
    }
}
