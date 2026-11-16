//
//  AuthModelAndValidationTests.swift
//  AesthelityTests
//
//  Tests for UserAccount model, AuthError definitions, and AuthValidator logic.
//

import Foundation
import Testing
@testable import Aesthelity

@Suite("Authentication Model & Credential Validation Tests")
struct AuthModelAndValidationTests {

    // MARK: - UserAccount Model Tests

    @Test("UserAccount initializes and encodes/decodes correctly")
    func userAccountEncodingDecoding() throws {
        let originalDate = Date(timeIntervalSince1970: 1700000000)
        let account = UserAccount(
            id: "uid_12345",
            email: "skincare.fan@example.com",
            createdAt: originalDate,
            isAnonymous: false
        )

        #expect(account.id == "uid_12345")
        #expect(account.email == "skincare.fan@example.com")
        #expect(account.isAnonymous == false)

        let encoded = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(UserAccount.self, from: encoded)

        #expect(decoded.id == account.id)
        #expect(decoded.email == account.email)
        #expect(decoded.isAnonymous == account.isAnonymous)
    }

    // MARK: - AuthValidator: Email Tests

    @Test("Valid emails pass validation")
    func validEmailValidation() {
        let validEmails = [
            "user@example.com",
            "glow.routine@subdomain.example.org",
            "first+last@aesthelity.app"
        ]

        for email in validEmails {
            let result = AuthValidator.validateEmail(email)
            #expect(result == .success(email))
        }
    }

    @Test("Email with surrounding whitespace is trimmed")
    func emailWhitespaceTrimming() {
        let raw = "   user@example.com \n "
        let result = AuthValidator.validateEmail(raw)
        #expect(result == .success("user@example.com"))
    }

    @Test("Invalid or empty emails fail validation with clear error")
    func invalidEmailValidation() {
        #expect(AuthValidator.validateEmail("") == .failure(.missingFields))
        #expect(AuthValidator.validateEmail("   ") == .failure(.missingFields))
        #expect(AuthValidator.validateEmail("invalid-email") == .failure(.invalidEmail))
        #expect(AuthValidator.validateEmail("user@") == .failure(.invalidEmail))
        #expect(AuthValidator.validateEmail("@example.com") == .failure(.invalidEmail))
    }

    // MARK: - AuthValidator: Password Tests

    @Test("Strong passwords pass validation")
    func validPasswordValidation() {
        let passwords = ["Skincare2026!", "aesthelity9", "SecurePass42"]
        for pass in passwords {
            let result = AuthValidator.validatePassword(pass)
            #expect(result == .success(pass))
        }
    }

    @Test("Passwords shorter than 8 characters fail with helpful reason")
    func shortPasswordValidation() {
        let result = AuthValidator.validatePassword("pass1")
        #expect(result == .failure(.weakPassword(reason: "Password must be at least 8 characters long.")))
    }

    @Test("Passwords missing numbers fail with helpful reason")
    func passwordMissingNumbersValidation() {
        let result = AuthValidator.validatePassword("passwordOnly")
        #expect(result == .failure(.weakPassword(reason: "Password must contain at least one number.")))
    }

    @Test("Empty password returns missingFields error")
    func emptyPasswordValidation() {
        #expect(AuthValidator.validatePassword("") == .failure(.missingFields))
    }

    // MARK: - AuthValidator: Combined Credentials Validation

    @Test("Combined credential validation succeeds when both email and password are valid")
    func combinedCredentialsSuccess() {
        let result = AuthValidator.validateCredentials(email: "valid@example.com", password: "Password123")
        guard case .success(let credentials) = result else {
            Issue.record("Expected successful credential validation")
            return
        }
        #expect(credentials.email == "valid@example.com")
        #expect(credentials.password == "Password123")
    }

    @Test("Combined validation returns error when fields are missing or invalid")
    func combinedCredentialsFailures() {
        #expect(AuthValidator.validateCredentials(email: "", password: "") == .failure(.missingFields))
        #expect(AuthValidator.validateCredentials(email: "bad-email", password: "Password123") == .failure(.invalidEmail))
        #expect(AuthValidator.validateCredentials(email: "valid@example.com", password: "short") == .failure(.weakPassword(reason: "Password must be at least 8 characters long.")))
    }

    // MARK: - AuthValidator: Username Tests

    @Test("Valid usernames pass validation")
    func validUsernameValidation() {
        let validUsernames = ["maya", "skincare_lover", "glow-123", "user.name"]
        for username in validUsernames {
            let result = AuthValidator.validateUsername(username)
            #expect(result == .success(username))
        }
    }

    @Test("Invalid usernames fail with appropriate errors")
    func invalidUsernameValidation() {
        #expect(AuthValidator.validateUsername("") == .failure(.missingFields))
        #expect(AuthValidator.validateUsername("ab") == .failure(.invalidUsername(reason: "Username must be at least 3 characters long.")))
        #expect(AuthValidator.validateUsername("bad name with spaces") == .failure(.invalidUsername(reason: "Username can only contain letters, numbers, underscores, and dashes.")))
    }

    @Test("Combined credential validation succeeds with optional username")
    func combinedCredentialsWithUsername() {
        let result = AuthValidator.validateCredentials(
            email: "valid@example.com",
            password: "Password123",
            username: "glow_expert"
        )
        guard case .success(let credentials) = result else {
            Issue.record("Expected successful credential validation with username")
            return
        }
        #expect(credentials.email == "valid@example.com")
        #expect(credentials.password == "Password123")
        #expect(credentials.username == "glow_expert")
    }

    // MARK: - AuthError Tests

    @Test("AuthError descriptions provide clear, non-sensitive messages")
    func authErrorDescriptions() {
        #expect(AuthError.invalidCredentials.errorDescription == "Incorrect email or password. Please check your credentials and try again.")
        #expect(AuthError.emailAlreadyInUse.errorDescription == "An account with this email address already exists. Try signing in instead.")
        #expect(AuthError.missingFields.errorDescription == "Please enter both your email address and password.")
    }
}
