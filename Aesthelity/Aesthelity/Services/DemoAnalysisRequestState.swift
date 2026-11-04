import Combine
import Foundation

/// Invalidates ownership before cancellation: even a non-cooperative request cannot
/// publish a result, error, or loading transition into a newer selection/session.
@MainActor
final class DemoAnalysisRequestState: ObservableObject {
    @Published private(set) var result: LiveAnalysisResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    private var requestID: UUID?
    private var task: Task<Void, Never>?
    private let analyze: @MainActor (AnalysisDemoScenario) async throws -> LiveAnalysisResult

    init(analyze: @escaping @MainActor (AnalysisDemoScenario) async throws -> LiveAnalysisResult = {
        try await BackendAnalysisAPI().analyze(scenario: $0)
    }) {
        self.analyze = analyze
    }

    func invalidate() {
        requestID = nil
        task?.cancel()
        task = nil
        result = nil
        errorMessage = nil
        isLoading = false
    }

    @discardableResult
    func run(scenario: AnalysisDemoScenario) -> Task<Void, Never> {
        invalidate()
        let id = UUID()
        requestID = id
        isLoading = true
        let analyze = self.analyze
        let task = Task { [weak self] in
            do {
                let response = try await analyze(scenario)
                guard let self, self.requestID == id else { return }
                self.result = response
                self.isLoading = false
                self.task = nil
            } catch {
                guard let self, self.requestID == id else { return }
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.task = nil
            }
        }
        self.task = task
        return task
    }
}
