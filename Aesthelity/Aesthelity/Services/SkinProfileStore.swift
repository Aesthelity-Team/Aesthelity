import Combine
import Foundation

@MainActor
final class SkinProfileStore: ObservableObject {
    nonisolated static let defaultFileURL = URL.applicationSupportDirectory
        .appendingPathComponent("SkinProfile/profile.json")

    @Published private(set) var profile = SkinProfile()
    @Published private(set) var loadError: String?
    private let fileURL: URL

    enum StoreError: Error { case unsupportedSchemaVersion }

    init(fileURL: URL = SkinProfileStore.defaultFileURL) {
        self.fileURL = fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode(SkinProfile.self, from: Data(contentsOf: fileURL))
            guard saved.schemaVersion == 1 else { throw StoreError.unsupportedSchemaVersion }
            profile = saved
        } catch {
            loadError = "Your saved profile could not be loaded. You can complete setup again."
        }
    }

    /// Publishes the new profile only after its atomic write succeeds.
    func save(_ profile: SkinProfile) throws {
        guard profile.schemaVersion == 1 else { throw StoreError.unsupportedSchemaVersion }
        let data = try JSONEncoder().encode(profile)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        self.profile = profile
        loadError = nil
        enqueueCloudSave(profile)
    }

    private func enqueueCloudSave(_ profile: SkinProfile) {
        guard CloudSyncConfiguration.isEnabled else { return }
        CloudSyncConfiguration.noteSyncInvocation()
        guard let userId = FirebaseAuthService.shared.userId else { return }
        Task {
            await FirestoreSyncService.shared.saveSkinProfile(profile, for: userId)
        }
    }
}
