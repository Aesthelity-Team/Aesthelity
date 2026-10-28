//
//  FirestoreSyncService.swift
//  Aesthelity
//
//  Real-time Firestore synchronization service for skincare routines and user profile.
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
public final class FirestoreSyncService: ObservableObject {
    public static let shared = FirestoreSyncService()

    private let db = Firestore.firestore()
    private var routineListener: ListenerRegistration?
    private var isApplyingRemoteUpdate = false

    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncError: String?

    private init() {}

    deinit {
        routineListener?.remove()
    }

    // MARK: - Real-time Routine Listener

    /// Starts real-time listening to Firestore routines for the given user ID.
    public func startRoutineListener(for userId: String) {
        routineListener?.remove()

        let collection = db.collection("users").document(userId).collection("routines")
        routineListener = collection.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.lastSyncError = error.localizedDescription
                    return
                }

                guard let snapshot = snapshot else { return }

                // Avoid triggering an echo loop while updating local store
                self.isApplyingRemoteUpdate = true
                defer { self.isApplyingRemoteUpdate = false }

                let remoteRoutines: [RoutineRecord] = snapshot.documents.compactMap { doc in
                    RoutineRecord(fromDatabaseDictionary: doc.data())
                }

                if !remoteRoutines.isEmpty {
                    // Update local store atomically with cloud data
                    try? RoutineStore.shared.saveAll(remoteRoutines)
                } else if !RoutineStore.shared.routines.isEmpty {
                    // Seed remote collection with initial local routines
                    self.uploadAllLocalRoutines(RoutineStore.shared.routines, for: userId)
                }
            }
        }
    }

    /// Stops real-time listening.
    public func stopRoutineListener() {
        routineListener?.remove()
        routineListener = nil
    }

    // MARK: - Routine Firestore Operations

    /// Saves a single routine to Firestore under `users/{userId}/routines/{id}`.
    public func saveRoutine(_ routine: RoutineRecord, for userId: String) async {
        guard !isApplyingRemoteUpdate else { return }
        let collection = db.collection("users").document(userId).collection("routines")
        do {
            try await collection.document(routine.id.uuidString).setData(routine.toDatabaseDictionary())
            self.lastSyncError = nil
        } catch {
            self.lastSyncError = error.localizedDescription
        }
    }

    /// Deletes a routine from Firestore.
    public func deleteRoutine(id: UUID, for userId: String) async {
        guard !isApplyingRemoteUpdate else { return }
        let collection = db.collection("users").document(userId).collection("routines")
        do {
            try await collection.document(id.uuidString).delete()
            self.lastSyncError = nil
        } catch {
            self.lastSyncError = error.localizedDescription
        }
    }

    /// Uploads all local routines in a single batch write.
    public func uploadAllLocalRoutines(_ routines: [RoutineRecord], for userId: String) {
        let batch = db.batch()
        let collection = db.collection("users").document(userId).collection("routines")
        for routine in routines {
            let docRef = collection.document(routine.id.uuidString)
            batch.setData(routine.toDatabaseDictionary(), forDocument: docRef)
        }
        batch.commit { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    self?.lastSyncError = error.localizedDescription
                } else {
                    self?.lastSyncError = nil
                }
            }
        }
    }

    // MARK: - Skin Profile Firestore Operations

    /// Syncs user skin profile to Firestore at `users/{userId}/profile/skinProfile`.
    func saveSkinProfile(_ profile: SkinProfile, for userId: String) async {
        do {
            let data = try JSONEncoder().encode(profile)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let docRef = db.collection("users").document(userId).collection("profile").document("skinProfile")
            try await docRef.setData(dict)
            self.lastSyncError = nil
        } catch {
            self.lastSyncError = error.localizedDescription
        }
    }

    /// Fetches skin profile from Firestore if it exists.
    func fetchSkinProfile(for userId: String) async -> SkinProfile? {
        let docRef = db.collection("users").document(userId).collection("profile").document("skinProfile")
        do {
            let doc = try await docRef.getDocument()
            guard let data = doc.data() else { return nil }
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return try JSONDecoder().decode(SkinProfile.self, from: jsonData)
        } catch {
            self.lastSyncError = error.localizedDescription
            return nil
        }
    }
}
