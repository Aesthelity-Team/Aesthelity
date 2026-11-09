//
//  AuthValidator.swift
//  Aesthelity
//
//  Validates registration and sign-in credentials prior to transmission.
//

import Foundation

public struct AuthCredentials: Equatable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public enum AuthValidator {
    private static let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#

    /// Validates an email address and returns the sanitized (trimmed) email string or an AuthError.
    public static func validateEmail(_ email: String) -> Result<String, AuthError> {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.missingFields)
        }
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard predicate.evaluate(with: trimmed) else {
            return .failure(.invalidEmail)
        }
        return .success(trimmed)
    }

    /// Validates password strength and requirements.
    public static func validatePassword(_ password: String) -> Result<String, AuthError> {
        guard !password.isEmpty else {
            return .failure(.missingFields)
        }
        guard password.count >= 8 else {
            return .failure(.weakPassword(reason: "Password must be at least 8 characters long."))
        }
        guard password.contains(where: { $0.isNumber }) else {
            return .failure(.weakPassword(reason: "Password must contain at least one number."))
        }
        return .success(password)
    }

    /// Validates all required credentials for account registration or sign-in.
    public static func validateCredentials(
        email: String,
        password: String
    ) -> Result<AuthCredentials, AuthError> {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            return .failure(.missingFields)
        }

        switch validateEmail(trimmedEmail) {
        case .failure(let error):
            return .failure(error)
        case .success(let validEmail):
            switch validatePassword(password) {
            case .failure(let error):
                return .failure(error)
            case .success(let validPassword):
                return .success(AuthCredentials(email: validEmail, password: validPassword))
            }
        }
    }
}
