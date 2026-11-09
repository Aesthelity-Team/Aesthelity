//
//  AuthEmailRegistration.swift
//  Aesthelity
//
//  Pure email registration decision helper.
//

import Foundation

public enum AuthRegistrationOutcome: Equatable {
    case succeeded(UserAccount)
    case failed(message: String)
    case invalidForm(message: String)
}

@MainActor
public enum AuthEmailRegistration {
    public static func attempt(
        email: String,
        password: String,
        username: String? = nil,
        isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--pf01-ui-testing"),
        signUp: (String, String, String?) async throws -> UserAccount
    ) async -> AuthRegistrationOutcome {
        let validationResult = AuthValidator.validateCredentials(email: email, password: password, username: username)
        let validated: AuthCredentials
        switch validationResult {
        case .success(let credentials):
            validated = credentials
        case .failure(let error):
            return .invalidForm(message: error.localizedDescription)
        }

        if isUITesting {
            let mockAccount = UserAccount(
                id: UUID().uuidString,
                email: validated.email,
                username: validated.username,
                isAnonymous: false
            )
            return .succeeded(mockAccount)
        }

        do {
            let account = try await signUp(validated.email, validated.password, validated.username)
            return .succeeded(account)
        } catch let authError as AuthError {
            switch authError {
            case .missingFields, .invalidEmail, .invalidUsername, .weakPassword:
                return .invalidForm(message: authError.localizedDescription)
            case .emailAlreadyInUse, .invalidCredentials, .sessionExpired, .networkError, .unknown:
                return .failed(message: authError.localizedDescription)
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .failed(
                message: message.isEmpty
                    ? "Account creation failed. Please check your information and try again."
                    : message
            )
        }
    }

    public static func attempt(
        email: String,
        password: String,
        username: String? = nil,
        isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--pf01-ui-testing"),
        signUp: @escaping (String, String) async throws -> UserAccount
    ) async -> AuthRegistrationOutcome {
        await attempt(
            email: email,
            password: password,
            username: username,
            isUITesting: isUITesting,
            signUp: { email, password, _ in
                try await signUp(email, password)
            }
        )
    }
}
