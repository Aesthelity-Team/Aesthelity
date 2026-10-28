//
//  CloudSyncConfiguration.swift
//  Aesthelity
//
//  Gate for Firestore routine/profile sync. Kept disabled until account
//  isolation, reconciliation, security rules, and database ID are agreed
//  and verified. See docs/FIRESTORE_SETUP.md.
//

import Foundation

/// Controls whether the app may start Firestore listeners or write routines/profiles.
public enum CloudSyncConfiguration {
    /// Cloud routine and profile sync is intentionally off for this release path.
    public static let isEnabled: Bool = false

    /// Counts store→sync call attempts. Stays at 0 while `isEnabled` is false.
    @MainActor
    public static private(set) var syncInvocationCount: Int = 0

    /// Counts FirestoreSyncService entry points hit while disabled (defense in depth).
    @MainActor
    public static private(set) var blockedServiceCallCount: Int = 0

    @MainActor
    public static func resetTestCounters() {
        syncInvocationCount = 0
        blockedServiceCallCount = 0
    }

    @MainActor
    static func noteSyncInvocation() {
        syncInvocationCount += 1
    }

    @MainActor
    static func noteBlockedServiceCall() {
        blockedServiceCallCount += 1
    }
}
