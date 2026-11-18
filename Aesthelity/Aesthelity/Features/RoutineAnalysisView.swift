import SwiftUI

/// An assessment is tied to the displayed routine inputs and signed-in session.
struct RoutineAnalysisView: View {
    let routineName: String
    let steps: [RoutineStepItem]
    var routineID: UUID? = nil
    var period: RoutinePeriod = .am
    @ObservedObject var routines: RoutineStore = .shared
    let onDismiss: () -> Void
    @EnvironmentObject private var products: ManualProductStore
    @ObservedObject private var auth = FirebaseAuthService.shared
    @State private var showDemo = false
    @State private var showSignIn = false
    @State private var task: Task<Void, Never>?
    @State private var operation = UUID()
    @State private var busy = false
    @State private var result: SavedPersonalAnalysis?
    @State private var message: String?
    @State private var needsSignIn = false

    private var currentRoutine: RoutineRecord? {
        guard let routineID else { return nil }
        return routines.routines.first { $0.id == routineID }
    }

    private var currentSteps: [RoutineStepItem] {
        let values = routineID == nil ? steps : currentRoutine?.steps ?? []
        return values.map { step in
            guard step.product == nil, let id = step.productId,
                  let product = products.products.first(where: { $0.id == id }) else { return step }
            return RoutineStepItem(id: step.id, stepNumber: step.stepNumber, title: step.title,
                                   subtitle: step.subtitle, state: step.state, hasClash: step.hasClash,
                                   productId: id, product: RoutineProductSnapshot(product))
        }
    }

    private var inputKey: Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(currentSteps)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(currentRoutine?.name ?? routineName).font(.title2.bold())
                    if currentSteps.isEmpty {
                        Text("Add products to your routine to prepare for analysis.")
                    } else {
                        ForEach(currentSteps) { step in
                            Text("\(step.stepNumber). \(step.title)")
                        }
                    }
                    Text("Analyze the ingredient details attached to this routine. Missing lists and unverified manual lists remain incomplete. Ingredient-avoidance preferences are not treated as confirmed allergies.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if currentSteps.contains(where: { $0.product?.provenance == "Fictional demo catalog" }) {
                        Text("This routine contains fictional catalog products. Findings for those products are illustrative.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if (try? ProtectedAPIConfiguration.baseURL()) == nil {
                        Text("Personal analysis is awaiting a secure backend connection. Your routine remains on this device.")
                            .foregroundStyle(.secondary)
                    }
                    if busy { ProgressView("Contacting the backend…") }
                    if let message { Text(message).accessibilityIdentifier("personal-analysis-message") }
                    if needsSignIn || auth.userId == nil || auth.isAnonymous {
                        Button("Sign in") { showSignIn = true }
                            .accessibilityIdentifier("personal-analysis-sign-in")
                    }
                    Button("Analyze routine") { perform(.analyze) }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy || currentSteps.isEmpty)
                        .accessibilityIdentifier("run-personal-analysis")
                    if let result {
                        PersonalAnalysisResultView(result: result.response, names: result.productNames)
                    } else {
                        Text("No compatibility assessment has been generated for this routine.")
                            .foregroundStyle(.secondary)
                    }
                    if routineID != nil {
                        HStack {
                            Button("Save analysis to account") { perform(.save) }
                                .disabled(busy || result == nil)
                                .accessibilityIdentifier("save-personal-analysis")
                            Button("Load saved analysis") { perform(.load) }
                                .disabled(busy || currentSteps.isEmpty)
                                .accessibilityIdentifier("load-personal-analysis")
                        }
                        Text("Saving replaces the previous saved analysis for this routine. A saved analysis is displayed only when its inputs match this routine.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Demo / Dev Mode") { showDemo = true }
                        .accessibilityIdentifier("open-analysis-demo")
                    Text("Explore fictional scenarios using a local demo server or bundled sample findings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Routine analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Back", action: onDismiss) } }
            .sheet(isPresented: $showDemo) { LiveAnalysisView(onDismiss: { showDemo = false }) }
            .sheet(isPresented: $showSignIn) {
                AuthSignInView(onSuccess: { showSignIn = false }, onContinueWithoutAccount: { showSignIn = false })
            }
        }
        .onChange(of: inputKey) { _, _ in invalidate() }
        .onChange(of: currentRoutine?.period ?? period) { _, _ in invalidate() }
        .onChange(of: auth.apiSessionRevision) { _, _ in invalidate() }
        .onChange(of: auth.userId) { _, _ in invalidate() }
        .onChange(of: auth.isAnonymous) { _, _ in invalidate() }
        .onDisappear { invalidate() }
    }

    private enum Action { case analyze, save, load }

    private func perform(_ action: Action) {
        task?.cancel()
        let id = UUID()
        operation = id
        busy = true
        message = nil
        needsSignIn = false
        let key = inputKey
        let selectedSteps = currentSteps
        let selectedPeriod = currentRoutine?.period ?? period
        let previous = result
        if action != .save { result = nil }
        task = Task { @MainActor in
            defer { if operation == id { busy = false } }
            do {
                let api = try AccountDataAPI.configured()
                let normalizer = try IngredientNormalizer(catalog: .loadBundled())
                let payload = PersonalAnalysisInput.make(steps: selectedSteps, period: selectedPeriod, normalizer: normalizer)
                let names = Dictionary(uniqueKeysWithValues: selectedSteps.map { ($0.id.uuidString, $0.title) })
                let value: SavedPersonalAnalysis
                switch action {
                case .analyze:
                    let response = try await api.analyze(payload, catalogVersion: normalizer.catalogVersion)
                    value = SavedPersonalAnalysis(schemaVersion: 1, routineID: routineID ?? UUID(), request: payload,
                                                  response: response, productNames: names, savedAt: Date())
                case .save:
                    guard let routineID, let previous, previous.request == payload else { throw APIClientError.invalidResponse }
                    try await api.save(previous, kind: "analyses", id: routineID.uuidString)
                    value = previous
                case .load:
                    guard let routineID else { throw APIClientError.invalidResponse }
                    value = try await api.load("analyses", id: routineID.uuidString, as: SavedPersonalAnalysis.self)
                    guard value.schemaVersion == 1, value.routineID == routineID,
                          value.request == payload, value.productNames == names else {
                        message = "The saved analysis uses different inputs. Analyze this routine again."
                        return
                    }
                    try AccountDataAPI.validate(value.response, for: payload, catalogVersion: normalizer.catalogVersion)
                }
                try api.checkSession()
                guard operation == id, key == inputKey else { return }
                result = value
                if action == .save { message = "Analysis saved to your account." }
                if action == .load { message = "Saved analysis loaded. Rules may have changed since this assessment." }
            } catch is CancellationError {
            } catch {
                guard operation == id else { return }
                if (error as? APIClientError) == .invalidResponse {
                    message = AnalysisResponsePayload.incompleteTitle + ". The response could not be verified. Try analyzing again."
                } else {
                    message = error.localizedDescription
                }
                needsSignIn = (error as? APIClientError) == .signInRequired
            }
        }
    }

    private func invalidate() {
        task?.cancel()
        operation = UUID()
        busy = false
        result = nil
        message = nil
        needsSignIn = false
    }
}

private struct PersonalAnalysisResultView: View {
    let result: AnalysisResponsePayload
    let names: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(result.hasIncompleteAssessment ? AnalysisResponsePayload.incompleteTitle : "Assessment")
                .font(.headline)
            if result.hasIncompleteAssessment && result.findings.isEmpty {
                Text("Some information needed for the assessment was unavailable.")
            }
            if result.showsNoFindings {
                Text(result.displayLabel ?? "No findings under the current rules")
                Text("No rule matched the available data. This is not a safety guarantee.")
            }
            ForEach(Array(result.findings.enumerated()), id: \.offset) { _, finding in
                VStack(alignment: .leading, spacing: 6) {
                    Text(finding.outcomeTitle).font(.headline)
                    if let severity = finding.severityLabel {
                        Text(severity).font(.subheadline)
                    }
                    Text(finding.productIDs.map { names[$0] ?? "Product" }.joined(separator: " · "))
                        .font(.subheadline)
                    Text(finding.explanation)
                    Text(finding.reason).font(.caption).foregroundStyle(.secondary)
                    AnalysisFindingDetails(finding: finding)
                }
                .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(result.limitations + (result.coverage?.limitations ?? []), id: \.self) { Text($0).font(.caption) }
            Text("Rules \(result.ruleVersion) · Ingredient reference v\(result.activeCatalogVersion)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("personal-analysis-result")
    }
}


struct AnalysisFindingDetails: View {
    let finding: AnalysisFindingPayload

    var body: some View {
        if !finding.ingredientLabel.isEmpty {
            Text("Affected ingredients: " + finding.ingredientLabel)
                .font(.caption)
        }
        ForEach(Array((finding.evidence ?? []).enumerated()), id: \.offset) { _, reference in
            VStack(alignment: .leading, spacing: 3) {
                Text(reference.source.title).font(.caption.weight(.semibold))
                Text(reference.source.publisher).font(.caption)
                Text(reference.claim).font(.caption)
            }
            .accessibilityElement(children: .combine)
        }
        ForEach(finding.limitations, id: \.self) { Text($0).font(.caption) }
    }
}
