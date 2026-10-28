//
//  AuthEmailSignIn.swift
//  Aesthelity
//
//  Pure email sign-in decision helper (no auto sign-up, no silent success).
//

import Foundation

public enum AuthEmailSignInOutcome: Equatable {
    case succeeded
    case failed(message: String)
    case invalidForm(message: String)
    case continuedWithoutAccount
}

@MainActor
public enum AuthEmailSignIn {
    public static let missingCredentialsMessage =
        "Enter your email and password to sign in, or continue without signing in."

    public static func attempt(
        email: String,
        password: String,
        isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("--pf01-ui-testing"),
        signIn: (String, String) async throws -> Void
    ) async -> AuthEmailSignInOutcome {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            return .invalidForm(message: missingCredentialsMessage)
        }

        if isUITesting {
            return .continuedWithoutAccount
        }

        do {
            try await signIn(trimmedEmail, password)
            return .succeeded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .failed(
                message: message.isEmpty
                    ? "Sign-in failed. Check your email and password, then try again."
                    : message
            )
        }
    }
}
