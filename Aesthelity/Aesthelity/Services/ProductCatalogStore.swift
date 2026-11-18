import Combine
import Foundation

@MainActor
final class ProductCatalogStore: ObservableObject {
    @Published private(set) var products: [DemoProduct]?
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    private let fetch: () async throws -> [DemoProduct]

    init(fetch: @escaping () async throws -> [DemoProduct] = {
        try await BackendAnalysisAPI().loadProducts()
    }) {
        self.fetch = fetch
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await fetch()
            try Task.checkCancellation()
            products = loaded
            message = nil
        } catch is CancellationError {
        } catch {
            message = products == nil
                ? "Live catalog unavailable. Showing bundled fictional products."
                : "Couldn’t refresh the catalog. Showing the last loaded products."
        }
    }

    static var usesBundledCatalogForTests: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasSuffix("-ui-testing") }
    }
}
