//
//  FirebaseAuthService.swift
//  Aesthelity
//
//  Authentication service managing Firebase Auth sessions (Email/Password & Anonymous).
//

import Combine
import FirebaseAuth
import Foundation

@MainActor
public final class FirebaseAuthService: ObservableObject {
    public static let shared = FirebaseAuthService()

    @Published public private(set) var userId: String?
    @Published public private(set) var userEmail: String?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isAnonymous: Bool = false
    @Published public private(set) var authError: String?
    @Published public private(set) var isLoading: Bool = false

    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    private init() {
        if let current = Auth.auth().currentUser {
            self.userId = current.uid
            self.userEmail = current.email
            self.isAuthenticated = true
            self.isAnonymous = current.isAnonymous
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
                self.userId = user?.uid
                self.userEmail = user?.email
                self.isAuthenticated = user != nil
                self.isAnonymous = user?.isAnonymous ?? false
            }
        }
    }

    /// Automatically signs in anonymously if no user is authenticated yet,
    /// providing an immediate unique Firebase UID for Firestore synchronization.
    public func ensureAuthenticated() async {
        guard Auth.auth().currentUser == nil else { return }
        do {
            isLoading = true
            let result = try await Auth.auth().signInAnonymously()
            self.userId = result.user.uid
            self.userEmail = result.user.email
            self.isAuthenticated = true
            self.isAnonymous = result.user.isAnonymous
            self.isLoading = false
            self.authError = nil
        } catch {
            self.isLoading = false
            self.authError = error.localizedDescription
        }
    }

    /// Sign in with an existing email and password.
    public func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userId = result.user.uid
            self.userEmail = result.user.email
            self.isAuthenticated = true
            self.isAnonymous = result.user.isAnonymous
            self.authError = nil
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }

    /// Create a new account with email and password.
    public func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userId = result.user.uid
            self.userEmail = result.user.email
            self.isAuthenticated = true
            self.isAnonymous = result.user.isAnonymous
            self.authError = nil
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }

    /// Sign out of the current Firebase session and revert to anonymous if desired.
    public func signOut() throws {
        try Auth.auth().signOut()
        self.userId = nil
        self.userEmail = nil
        self.isAuthenticated = false
        self.isAnonymous = false
        self.authError = nil
    }
}
