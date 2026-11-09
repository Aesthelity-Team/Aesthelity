//
//  AuthServiceAndKeychainTests.swift
//  AesthelityTests
//
//  Unit tests for KeychainManager, PasswordHasher, and AuthServiceProtocol implementation.
//

import XCTest
@testable import Aesthelity

final class AuthServiceAndKeychainTests: XCTestCase {
    
    private var keychain: KeychainManager!
    private let testService = "com.Aesthelity.Aesthelity.tests"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        keychain = KeychainManager(service: testService)
        try? keychain.clearAll()
    }
    
    override func tearDownWithError() throws {
        try? keychain.clearAll()
        keychain = nil
        try super.tearDownWithError()
    }
    
    // MARK: - KeychainManager Tests
    
    func testSaveAndReadString() throws {
        let key = "test_string_key"
        let value = "secret_session_token_12345"
        
        try keychain.save(string: value, forKey: key)
        let retrieved = try keychain.readString(forKey: key)
        
        XCTAssertEqual(retrieved, value)
    }
    
    func testSaveAndReadData() throws {
        let key = "test_data_key"
        let originalData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        
        try keychain.save(data: originalData, forKey: key)
        let retrieved = try keychain.readData(forKey: key)
        
        XCTAssertEqual(retrieved, originalData)
    }
    
    func testUpdateExistingKey() throws {
        let key = "test_update_key"
        try keychain.save(string: "initial_value", forKey: key)
        XCTAssertEqual(try keychain.readString(forKey: key), "initial_value")
        
        try keychain.save(string: "updated_value", forKey: key)
        XCTAssertEqual(try keychain.readString(forKey: key), "updated_value")
    }
    
    func testDeleteKey() throws {
        let key = "test_delete_key"
        try keychain.save(string: "to_delete", forKey: key)
        XCTAssertNotNil(try keychain.readString(forKey: key))
        
        try keychain.delete(forKey: key)
        XCTAssertNil(try keychain.readString(forKey: key))
        
        // Deleting already deleted key should succeed silently without error
        XCTAssertNoThrow(try keychain.delete(forKey: key))
    }
    
    func testNonexistentKeyReturnsNil() throws {
        let result = try keychain.readString(forKey: "nonexistent_key_\(UUID().uuidString)")
        XCTAssertNil(result)
    }
    
    func testClearAllRemovesAllEntries() throws {
        try keychain.save(string: "token_1", forKey: "key_1")
        try keychain.save(string: "token_2", forKey: "key_2")
        
        XCTAssertNotNil(try keychain.readString(forKey: "key_1"))
        XCTAssertNotNil(try keychain.readString(forKey: "key_2"))
        
        try keychain.clearAll()
        
        XCTAssertNil(try keychain.readString(forKey: "key_1"))
        XCTAssertNil(try keychain.readString(forKey: "key_2"))
    }
    
    func testKeychainErrorDescriptionsDoNotLeakPayload() {
        let statusError = KeychainError.unhandledError(status: -50)
        XCTAssertFalse(statusError.localizedDescription.contains("password"))
        XCTAssertFalse(statusError.localizedDescription.contains("token"))
        
        let notFound = KeychainError.itemNotFound
        XCTAssertEqual(notFound.localizedDescription, "The requested item was not found in secure storage.")
    }

    // MARK: - Secure Password Keychain Helpers
    
    func testSaveAndReadSecurePassword() throws {
        let account = "maya@aesthelity.app"
        let secret = "SuperSecretPassword123!"
        
        try keychain.saveSecurePassword(secret, forAccount: account)
        let retrieved = try keychain.readSecurePassword(forAccount: account)
        
        XCTAssertEqual(retrieved, secret)
    }
    
    func testDeleteSecurePassword() throws {
        let account = "maya@aesthelity.app"
        let secret = "SuperSecretPassword123!"
        
        try keychain.saveSecurePassword(secret, forAccount: account)
        XCTAssertNotNil(try keychain.readSecurePassword(forAccount: account))
        
        try keychain.deleteSecurePassword(forAccount: account)
        XCTAssertNil(try keychain.readSecurePassword(forAccount: account))
    }
    
    func testSaveEmptyPasswordThrowsMissingFields() {
        XCTAssertThrowsError(try keychain.saveSecurePassword("", forAccount: "user@example.com")) { error in
            XCTAssertEqual(error as? AuthError, .missingFields)
        }
    }
    
    // MARK: - PasswordHasher Tests
    
    func testPasswordHasherProducesDeterministicHashForSameSalt() {
        let password = "SecretPassword123!"
        let salt = "fixed_test_salt_16b"
        
        let hash1 = PasswordHasher.hash(password: password, salt: salt)
        let hash2 = PasswordHasher.hash(password: password, salt: salt)
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertFalse(hash1.isEmpty)
        XCTAssertNotEqual(hash1, password)
    }
    
    func testPasswordHasherDifferentSaltsProduceDifferentHashes() {
        let password = "SecretPassword123!"
        let salt1 = PasswordHasher.generateSalt(byteCount: 16)
        let salt2 = PasswordHasher.generateSalt(byteCount: 16)
        
        XCTAssertNotEqual(salt1, salt2)
        
        let hash1 = PasswordHasher.hash(password: password, salt: salt1)
        let hash2 = PasswordHasher.hash(password: password, salt: salt2)
        
        XCTAssertNotEqual(hash1, hash2)
    }
    
    func testPasswordHasherVerificationSucceedsWithCorrectPassword() {
        let password = "MyVerySecurePassword456!"
        let salt = PasswordHasher.generateSalt(byteCount: 16)
        let hash = PasswordHasher.hash(password: password, salt: salt)
        
        let isValid = PasswordHasher.verify(password: password, hash: hash, salt: salt)
        XCTAssertTrue(isValid)
    }
    
    func testPasswordHasherVerificationFailsWithWrongPassword() {
        let correctPassword = "CorrectPassword123!"
        let wrongPassword = "WrongPassword999!"
        let salt = PasswordHasher.generateSalt(byteCount: 16)
        let hash = PasswordHasher.hash(password: correctPassword, salt: salt)
        
        let isValid = PasswordHasher.verify(password: wrongPassword, hash: hash, salt: salt)
        XCTAssertFalse(isValid)
    }
    
    func testPasswordHasherRandomSaltGenerationHasExpectedByteCount() {
        let salt = PasswordHasher.generateSalt(byteCount: 16)
        let decoded = Data(base64Encoded: salt)
        XCTAssertEqual(decoded?.count, 16)
    }
    
    // MARK: - AuthServiceProtocol & MockAuthService Tests
    
    @MainActor
    func testSignUpSuccessReturnsUserAccount() async throws {
        let authService = MockAuthService()
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        
        let account = try await authService.signUp(
            email: "User@Example.com",
            password: "SecurePassword123!"
        )
        
        XCTAssertEqual(account.email, "user@example.com")
        XCTAssertFalse(account.isAnonymous)
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertEqual(authService.currentUser?.id, account.id)
        XCTAssertEqual(authService.userEmail, "user@example.com")
    }
    
    @MainActor
    func testMockAuthServiceDoesNotStorePlainTextPassword() async throws {
        let authService = MockAuthService()
        let rawPassword = "ClearTextSecret123!"
        let email = "security@aesthelity.app"
        
        _ = try await authService.signUp(email: email, password: rawPassword)
        
        let stored = authService.registeredUsers[email]
        XCTAssertNotNil(stored)
        XCTAssertNotEqual(stored?.passwordHash, rawPassword)
        XCTAssertFalse(stored?.passwordHash.contains(rawPassword) ?? true)
        XCTAssertTrue(PasswordHasher.verify(password: rawPassword, hash: stored!.passwordHash, salt: stored!.salt))
    }
    
    @MainActor
    func testSignUpRejectsInvalidEmailBeforeNetwork() async {
        let authService = MockAuthService()
        
        do {
            _ = try await authService.signUp(email: "invalid-email", password: "Password123!")
            XCTFail("Sign up should fail with invalid email")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidEmail)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testSignUpRejectsWeakPasswordBeforeNetwork() async {
        let authService = MockAuthService()
        
        do {
            _ = try await authService.signUp(email: "valid@example.com", password: "short")
            XCTFail("Sign up should fail with weak password")
        } catch let error as AuthError {
            if case .weakPassword = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .weakPassword, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testSignUpDuplicateEmailThrowsAlreadyInUse() async throws {
        let authService = MockAuthService()
        _ = try await authService.signUp(email: "test@example.com", password: "Password123!")
        
        do {
            _ = try await authService.signUp(email: "test@example.com", password: "Password123!")
            XCTFail("Duplicate sign up should fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .emailAlreadyInUse)
        }
    }
    
    @MainActor
    func testSignInSuccessUpdatesCurrentUserAndState() async throws {
        let authService = MockAuthService()
        _ = try await authService.signUp(email: "maya@aesthelity.app", password: "ValidPassword123!")
        try authService.signOut()
        XCTAssertFalse(authService.isAuthenticated)
        
        let account = try await authService.signIn(email: "maya@aesthelity.app", password: "ValidPassword123!")
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertEqual(authService.currentUser?.id, account.id)
        XCTAssertEqual(account.email, "maya@aesthelity.app")
    }
    
    @MainActor
    func testSignInWrongPasswordThrows() async throws {
        let authService = MockAuthService()
        _ = try await authService.signUp(email: "maya@aesthelity.app", password: "ValidPassword123!")
        try authService.signOut()
        
        do {
            _ = try await authService.signIn(email: "maya@aesthelity.app", password: "WrongPassword")
            XCTFail("Sign in with wrong password should fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        }
    }
    
    @MainActor
    func testSignInUnknownUserThrows() async {
        let authService = MockAuthService()
        
        do {
            _ = try await authService.signIn(email: "unregistered@example.com", password: "Password123!")
            XCTFail("Sign in with unknown user should fail")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testSignOutClearsSession() async throws {
        let authService = MockAuthService()
        _ = try await authService.signUp(email: "maya@aesthelity.app", password: "ValidPassword123!")
        XCTAssertTrue(authService.isAuthenticated)
        
        try authService.signOut()
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        XCTAssertNil(authService.userId)
        XCTAssertNil(authService.userEmail)
    }
    
    @MainActor
    func testEnsureAuthenticatedCreatesAnonymousUser() async {
        let authService = MockAuthService()
        XCTAssertFalse(authService.isAuthenticated)
        
        await authService.ensureAuthenticated()
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertTrue(authService.isAnonymous)
        XCTAssertNotNil(authService.userId)
    }

    // MARK: - AuthEmailRegistration Tests

    @MainActor
    func testRegistrationAttemptSuccess() async {
        let outcome = await AuthEmailRegistration.attempt(
            email: "valid@example.com",
            password: "StrongPassword123!",
            isUITesting: false,
            signUp: { email, _ in
                UserAccount(id: "user-123", email: email, isAnonymous: false)
            }
        )

        if case .succeeded(let account) = outcome {
            XCTAssertEqual(account.id, "user-123")
            XCTAssertEqual(account.email, "valid@example.com")
        } else {
            XCTFail("Expected .succeeded, got \(outcome)")
        }
    }

    @MainActor
    func testRegistrationAttemptInvalidEmail() async {
        let outcome = await AuthEmailRegistration.attempt(
            email: "bad-email",
            password: "StrongPassword123!",
            isUITesting: false,
            signUp: { _, _ in
                XCTFail("signUp should not be called for invalid email")
                throw AuthError.unknown()
            }
        )

        if case .invalidForm(let message) = outcome {
            XCTAssertEqual(message, AuthError.invalidEmail.localizedDescription)
        } else {
            XCTFail("Expected .invalidForm, got \(outcome)")
        }
    }

    @MainActor
    func testRegistrationAttemptWeakPassword() async {
        let outcome = await AuthEmailRegistration.attempt(
            email: "valid@example.com",
            password: "short",
            isUITesting: false,
            signUp: { _, _ in
                XCTFail("signUp should not be called for weak password")
                throw AuthError.unknown()
            }
        )

        if case .invalidForm(let message) = outcome {
            XCTAssertEqual(message, AuthError.weakPassword(reason: "Password must be at least 8 characters long.").localizedDescription)
        } else {
            XCTFail("Expected .invalidForm, got \(outcome)")
        }
    }

    @MainActor
    func testRegistrationAttemptDuplicateEmail() async {
        let outcome = await AuthEmailRegistration.attempt(
            email: "duplicate@example.com",
            password: "StrongPassword123!",
            isUITesting: false,
            signUp: { _, _ in
                throw AuthError.emailAlreadyInUse
            }
        )

        if case .failed(let message) = outcome {
            XCTAssertEqual(message, AuthError.emailAlreadyInUse.localizedDescription)
        } else {
            XCTFail("Expected .failed, got \(outcome)")
        }
    }
}
