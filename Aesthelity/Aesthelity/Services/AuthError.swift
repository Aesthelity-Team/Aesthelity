//
//  AuthError.swift
//  Aesthelity
//
//  Sanitized authentication errors designed to return clear, user-facing guidance
//  without exposing sensitive credential details or internal service exceptions.
//

import Foundation

public enum AuthError: LocalizedError, Equatable, Sendable {
    case missingFields
    case invalidEmail
    case weakPassword(reason: String)
    case emailAlreadyInUse
    case invalidCredentials
    case sessionExpired
    case networkError
    case unknown(message: String = "An unexpected error occurred. Please try again later.")

    public var errorDescription: String? {
        switch self {
        case .missingFields:
            return "Please enter both your email address and password."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword(let reason):
            return reason
        case .emailAlreadyInUse:
            return "An account with this email address already exists. Try signing in instead."
        case .invalidCredentials:
            // Non-sensitive error message that avoids revealing whether the account exists
            return "Incorrect email or password. Please check your credentials and try again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .networkError:
            return "Unable to connect to the authentication server. Please check your network and try again."
        case .unknown(let message):
            return message
        }
    }
}
