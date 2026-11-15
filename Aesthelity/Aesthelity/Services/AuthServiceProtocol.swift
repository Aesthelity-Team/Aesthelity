//
//  AuthServiceProtocol.swift
//  Aesthelity
//
//  Protocol defining authentication operations and session state.
//

import Combine
import Foundation

@MainActor
public protocol AuthServiceProtocol: AnyObject {
    var currentUser: UserAccount? { get }
    var userId: String? { get }
    var userEmail: String? { get }
    var isAuthenticated: Bool { get }
    var isAnonymous: Bool { get }
    var isLoading: Bool { get }
    var authError: String? { get }
    
    @discardableResult
    func signUp(email: String, password: String) async throws -> UserAccount
    
    @discardableResult
    func signUp(email: String, password: String, username: String?) async throws -> UserAccount
    
    @discardableResult
    func signIn(email: String, password: String) async throws -> UserAccount
    
    func signOut() throws
    func ensureAuthenticated() async
}

extension AuthServiceProtocol {
    @discardableResult
    public func signUp(email: String, password: String, username: String?) async throws -> UserAccount {
        try await signUp(email: email, password: password)
    }
}
