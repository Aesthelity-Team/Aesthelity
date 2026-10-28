import SwiftUI

struct LiveAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    let onDismiss: (() -> Void)?

    @State private var selectedScenario: AnalysisDemoScenario = .cautionPM
    @State private var selectedReferenceSampleID: String = DemoAnalysis.scenarioChoices[0].scenarioID
    @State private var result: LiveAnalysisResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    private let api = BackendAnalysisAPI()

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scenarioPicker
                    Button(action: { Task { await runAnalysis() } }) {
                        HStack(spacing: 8) {
                            if isLoading { ProgressView().tint(.white) }
                            Text(isLoading ? "Analyzing…" : "Analyze with backend")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.Semantic.inkBrand)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .accessibilityIdentifier("run-backend-analysis")

                    if let errorMessage {
                        errorCard(errorMessage)
                    }
                    if let result {
                        resultSection(result)
                    }
                    referenceExamples
                    Text("Demo scenario only. Results use the fictional shared catalog and do not analyze a saved personal routine or profile.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Semantic.inkSecondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
            }
        }
        .background(AppTheme.Semantic.surfaceBase.ignoresSafeArea())
    }

    private var navigationBar: some View {
        HStack {
            Button(action: close) {
                Label("Home", systemImage: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.Semantic.inkBrand)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Routine analysis")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            Spacer()
            Color.clear.frame(width: 50, height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.Semantic.lineHairline.opacity(0.7)).frame(height: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live analysis demo")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            Text("Products load from Firestore through the backend. The app normalizes their ingredient lists, then sends them to the Python rules engine.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Backend connection: local demo server")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Semantic.inkBrand)
        }
    }

    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Demo routine")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            Picker("Demo routine", selection: $selectedScenario) {
                ForEach(AnalysisDemoScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.Semantic.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(selectedScenario.explanation)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
        }
    }

    @ViewBuilder
    private func resultSection(_ live: LiveAnalysisResult) -> some View {
        let response = live.response
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API result")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                Spacer()
                Text(response.completeness == "complete" ? "Complete input" : "Incomplete input")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(response.completeness == "complete" ? Color.green.opacity(0.12) : Color.orange.opacity(0.16))
                    .clipShape(Capsule())
            }

            Text("Products: " + response.productIDs.map { live.productNames[$0] ?? $0 }.joined(separator: " · "))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Semantic.inkBrand)
                .fixedSize(horizontal: false, vertical: true)

            if response.findings.isEmpty {
                findingCard(
                    title: response.displayLabel ?? "No findings",
                    category: "No rule matched",
                    severity: nil,
                    explanation: response.completeness == "complete"
                        ? "No approved v1 rule matched these demo products. This is not a safety guarantee."
                        : "No approved rule matched the confirmed data, but the assessment is incomplete. Do not treat it as safe."
                )
            } else {
                ForEach(Array(response.findings.enumerated()), id: \.offset) { _, finding in
                    findingCard(
                        title: finding.outcome.capitalized,
                        category: finding.categoryID,
                        severity: finding.severity,
                        explanation: finding.explanation,
                        products: finding.productIDs.map { live.productNames[$0] ?? $0 }.joined(separator: " · "),
                        reason: finding.reason
                    )
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Rule version \(response.ruleVersion) · Ingredient catalog v\(response.activeCatalogVersion)")
                    .font(.system(size: 11, weight: .medium))
                ForEach(response.limitations, id: \.self) { limitation in
                    Text(limitation)
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(AppTheme.Semantic.inkSecondary)
            .padding(.top, 3)
        }
        .padding(16)
        .background(AppTheme.Semantic.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("backend-analysis-result")
    }

    private func findingCard(
        title: String,
        category: String,
        severity: String?,
        explanation: String,
        products: String? = nil,
        reason: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                Spacer()
                if let severity {
                    Text(severity.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.Semantic.inkBrand)
                }
            }
            Text(category.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Semantic.inkBrand)
            Text(explanation)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let products, !products.isEmpty {
                detailRow("Affected products", value: products)
            }
            if let reason, !reason.isEmpty {
                detailRow("Why this finding was generated", value: reason)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Semantic.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func detailRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11, weight: .semibold))
            Text(value).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppTheme.Semantic.inkSecondary)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Analysis unavailable", systemImage: "exclamationmark.triangle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
            Text("Start the backend API in the project terminal, then try again.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var referenceExamples: some View {
        let samples = DemoAnalysis.bundledSamples
        return VStack(alignment: .leading, spacing: 12) {
            Text("Sample Findings")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            Text("Bundled reference examples from Sprint 1. These are scripted fixtures, not backend results.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
            Picker("Sample scenario", selection: $selectedReferenceSampleID) {
                ForEach(samples) { sample in
                    Text(sample.title).tag(sample.id)
                }
            }
            .pickerStyle(.segmented)
            if let sample = samples.first(where: { $0.id == selectedReferenceSampleID }) {
                Text(sample.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                sampleContent(sample.state)
            }
        }
        .padding(16)
        .background(AppTheme.Semantic.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func sampleContent(_ state: DemoAnalysisState) -> some View {
        switch state {
        case .normal(let productNames):
            AnalysisFindingCard(
                headline: "No findings in this sample",
                explanation: "The demo rules flagged nothing for these sample products. This is not a safety guarantee.",
                tag: "Normal · No findings",
                tagIcon: "checkmark.circle",
                details: [.init("Sample products", productNames.joined(separator: ", "))]
            )
        case .findings(let findings):
            ForEach(Array(findings.enumerated()), id: \.offset) { _, finding in
                AnalysisFindingCard(
                    headline: "Sample finding",
                    explanation: finding.explanation,
                    tag: finding.status.label,
                    tagIcon: finding.status == .unknown ? "questionmark.circle" : "exclamationmark.triangle",
                    tagStyle: .neutral,
                    details: [
                        .init(finding.productNames.count == 1 ? "Affected product" : "Affected products", finding.productNames.joined(separator: ", ")),
                        .init("Ingredient", finding.ingredientText),
                        .init("Category", finding.category)
                    ],
                    reason: finding.reason,
                    note: finding.limitation
                )
            }
        case .unavailable(let message):
            AnalysisFindingCard(
                headline: "Sample analysis unavailable",
                explanation: message,
                tag: "Unavailable",
                tagIcon: "exclamationmark.circle",
                tagStyle: .neutral
            )
        }
    }

    @MainActor
    private func runAnalysis() async {
        isLoading = true
        errorMessage = nil
        result = nil
        defer { isLoading = false }
        do {
            result = try await api.analyze(scenario: selectedScenario)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func close() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }
}
