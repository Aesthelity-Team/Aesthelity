import Combine
import Foundation

/// Stores manual products on this device, independently of the shared catalog.
@MainActor
final class ManualProductStore: ObservableObject {
    nonisolated static let defaultFileURL = URL.applicationSupportDirectory
        .appendingPathComponent("ManualProducts/products.json")

    @Published private(set) var products: [ManualProduct] = []
    @Published private(set) var loadError: String?
    private let fileURL: URL

    enum StoreError: Error, Equatable {
        case unsupportedSchemaVersion
        case duplicateProductIDs
        case unreadableExistingStore
    }

    private struct Archive: Codable {
        var schemaVersion = 1
        var products: [ManualProduct]
    }

    init(fileURL: URL = ManualProductStore.defaultFileURL) {
        self.fileURL = fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: fileURL))
            guard archive.schemaVersion == 1 else { throw StoreError.unsupportedSchemaVersion }
            try Self.validate(archive.products)
            products = archive.products
        } catch {
            loadError = "Your saved manual products could not be loaded. The saved file has been preserved."
        }
    }

    /// Inserts or updates by ID, publishing only after the atomic write succeeds.
    func save(_ product: ManualProduct) throws {
        guard loadError == nil else { throw StoreError.unreadableExistingStore }
        var updated = products
        if let index = updated.firstIndex(where: { $0.id == product.id }) {
            updated[index] = product
        } else {
            updated.append(product)
        }
        try Self.validate(updated)
        let data = try JSONEncoder().encode(Archive(products: updated))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        products = updated
    }

    private static func validate(_ products: [ManualProduct]) throws {
        guard products.allSatisfy({ $0.schemaVersion == 1 }) else { throw StoreError.unsupportedSchemaVersion }
        guard Set(products.map(\.id)).count == products.count else { throw StoreError.duplicateProductIDs }
    }
}
