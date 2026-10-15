//
//  ConfidenceScoreView.swift
//  Aesthelity
//
//  Confidence Score & Routine Compatibility Analysis Screen.
//

import SwiftUI

/// A dedicated screen displaying the comprehensive routine confidence score,
/// compatibility breakdown, ingredient synergy analysis, and layering guidance.
public struct ConfidenceScoreView: View {
    @Environment(\.dismiss) private var dismiss
    
    // State
    public var score: Int = 82
    public var amStepsCount: Int = 4
    public var pmStepsCount: Int = 5
    public var onDismiss: (() -> Void)? = nil
    private let samples: [DemoAnalysisSample] = DemoAnalysis.bundledSamples
    @State private var selectedSampleID: String = DemoAnalysis.scenarioChoices[0].scenarioID
    
    public init(
        score: Int = 82,
        amStepsCount: Int = 4,
        pmStepsCount: Int = 5,
        onDismiss: (() -> Void)? = nil
    ) {
        self.score = score
        self.amStepsCount = amStepsCount
        self.pmStepsCount = pmStepsCount
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Navigation Bar
            navigationBar
            
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Confidence Card
                    ConfidenceCard(
                        score: score,
                        title: "CONFIDENCE SCORE",
                        subtitle: "Routine compatibility",
                        amSteps: amStepsCount,
                        pmSteps: pmStepsCount
                    )
                    
                    // Score Breakdown Section
                    scoreBreakdownSection
                    
                    // Sample Findings from DATA-01 demo scenarios (Sprint 1 AN-01)
                    analysisFindingsSection
                    
                    // Layering & Timing Advice
                    layeringGuidanceSection
                    
                    // Reassurance & Limitations Note
                    disclaimerSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .padding(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.Semantic.surfaceBase.ignoresSafeArea())
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button(action: {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(AppTheme.Typography.bodyMedium)
                }
                .foregroundStyle(AppTheme.Semantic.inkBrand)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Confidence Score")
                .font(AppTheme.Typography.headline17)
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            
            Spacer()
            
            // Placeholder to balance navigation bar
            Color.clear
                .frame(width: 50, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppTheme.Semantic.surfaceBase)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(AppTheme.Semantic.lineHairline.opacity(0.6)),
            alignment: .bottom
        )
    }
    
    // MARK: - Score Breakdown Section
    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Score Breakdown")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            
            VStack(spacing: 12) {
                metricRow(title: "Active Ingredient Harmony", percentage: 92, status: "Optimal")
                metricRow(title: "Skin Barrier Support", percentage: 86, status: "Strong")
                metricRow(title: "Step Order & Layering", percentage: 78, status: "Good")
                metricRow(title: "UV Protection Coverage", percentage: 95, status: "Protected")
            }
            .padding(16)
            .background(AppTheme.Semantic.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .stroke(AppTheme.Semantic.lineHairline, lineWidth: 1)
            )
        }
    }
    
    private func metricRow(title: String, percentage: Int, status: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                
                Spacer()
                
                Text("\(percentage)% · \(status)")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(AppTheme.Semantic.inkAccent)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.Semantic.surfaceSubtle.opacity(0.5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.Semantic.inkAccent)
                        .frame(width: geometry.size.width * CGFloat(percentage) / 100.0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Analysis Findings (Sprint 1 AN-01)
    private var analysisFindingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sample Findings")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            
            Text("Mocked results for sample scenarios built from demo products. They are not an analysis of your routine or profile.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Semantic.inkSecondary)

            Picker("Sample scenario", selection: $selectedSampleID) {
                ForEach(samples) { sample in
                    Text(sample.title).tag(sample.id)
                }
            }
            .pickerStyle(.segmented)
            
            if let sample = samples.first(where: { $0.id == selectedSampleID }) {
                Text(sample.summary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)

                sampleContent(sample.state)
            }
        }
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
    
    // MARK: - Layering Guidance Section
    private var layeringGuidanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layering Guidance")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            
            VStack(alignment: .leading, spacing: 10) {
                guidanceBullet(
                    icon: "clock.arrow.circlepath",
                    title: "Wait 60–90 seconds after Vitamin C",
                    detail: "Allow your antioxidant serum to fully absorb before applying cream to maintain acidic efficacy."
                )
                
                guidanceBullet(
                    icon: "sun.max.fill",
                    title: "Apply SPF as the final AM step",
                    detail: "Sunscreen forms an external protective shield and should never be diluted by subsequent moisturizers."
                )
                
                guidanceBullet(
                    icon: "drop.fill",
                    title: "Double cleanse in PM",
                    detail: "Oil cleanser dissolves water-resistant SPF and sebum, allowing your gentle cleanser to deeply purify."
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Semantic.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .stroke(AppTheme.Semantic.lineHairline, lineWidth: 1)
            )
        }
    }
    
    private func guidanceBullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Semantic.inkAccent)
                .frame(width: 22, height: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                
                Text(detail)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                    .lineSpacing(2)
            }
        }
    }
    
    // MARK: - Educational Disclaimer Section
    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
                .padding(.top, 1)
            
            Text("Aesthelity confidence scores reflect known ingredient compatibility and layering principles. Individual skin sensitivities may vary.")
                .font(AppTheme.Typography.tiny11)
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Previews

#Preview("Confidence Score Screen - Standard") {
    ConfidenceScoreView(
        score: 82,
        amStepsCount: 4,
        pmStepsCount: 5
    )
}

#Preview("Confidence Score Screen - 390x844 Frame") {
    VStack(alignment: .leading, spacing: 0) {
        ConfidenceScoreView(
            score: 82,
            amStepsCount: 4,
            pmStepsCount: 5
        )
    }
    .padding(0)
    .frame(width: 390, height: 844, alignment: .topLeading)
    .background(AppTheme.Semantic.surfaceBase)
}
