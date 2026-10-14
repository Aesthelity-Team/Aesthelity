//
//  AnalysisFindingTests.swift
//  AesthelityTests
//
//  Created by Gaurav Pandey on 10/13/26.
//

import Testing
@testable import Aesthelity

struct AnalysisFindingTests {

    @Test func mockFindingsCoverEverySeverity() {
        let severities = Set(MockAnalysisFindings.all.map(\.severity))
        #expect(severities == Set(FindingSeverity.allCases))
    }

    @Test func mockFindingIDsAreUnique() {
        let ids = MockAnalysisFindings.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test(arguments: MockAnalysisFindings.all)
    func findingShowsProductIngredientCategoryAndSeverity(_ finding: AnalysisFinding) {
        #expect(!finding.productName.isEmpty)
        #expect(!finding.ingredientName.isEmpty)
        #expect(!finding.category.isEmpty)
        #expect(!finding.severity.label.isEmpty)
    }

    @Test(arguments: MockAnalysisFindings.all)
    func findingExplainsConcernAndReason(_ finding: AnalysisFinding) {
        #expect(!finding.headline.isEmpty)
        #expect(!finding.explanation.isEmpty)
        #expect(!finding.reason.isEmpty)
    }

    @Test func cautionFindingIdentifiesVitaminCConcern() {
        let finding = MockAnalysisFindings.vitaminCWithRetinol
        #expect(finding.severity == .caution)
        #expect(finding.productName == "Vitamin C Serum")
        #expect(finding.ingredientName == "L-Ascorbic Acid")
        #expect(finding.severity.isDefinitive)
    }

    @Test func unknownFindingIsNotDefinitiveAndStatesLimitation() {
        let unknown = MockAnalysisFindings.all.filter { $0.severity == .unknown }
        #expect(!unknown.isEmpty)
        for finding in unknown {
            #expect(finding.severity.isDefinitive == false)
            #expect(finding.limitation?.isEmpty == false)
        }
    }

    @Test func severityPresentation() {
        #expect(FindingSeverity.normal.label == "Normal")
        #expect(FindingSeverity.caution.label == "Caution")
        #expect(FindingSeverity.unknown.label == "Unknown")
        #expect(FindingSeverity.caution.iconName == "exclamationmark.triangle.fill")
        #expect(FindingSeverity.unknown.iconName == "questionmark.circle.fill")
    }

    @Test func clashDemoLeadsWithCautionFinding() {
        let findings = MockAnalysisFindings.forClashDemo(true)
        #expect(findings.first?.severity == .caution)
        #expect(findings.count == MockAnalysisFindings.all.count)
    }

    @Test func nonClashDemoOmitsCautionFinding() {
        let findings = MockAnalysisFindings.forClashDemo(false)
        #expect(!findings.isEmpty)
        #expect(findings.allSatisfy { $0.severity != .caution })
    }

    @Test func confidenceScoreViewDefaultsToMockFindings() {
        let view = ConfidenceScoreView()
        #expect(view.findings == MockAnalysisFindings.all)
    }

    @Test func confidenceScoreViewUsesProvidedFindings() {
        let findings = [MockAnalysisFindings.incompleteIngredientList]
        let view = ConfidenceScoreView(score: 64, findings: findings)
        #expect(view.findings == findings)
    }

    @Test func analysisFindingCardAcceptsFinding() {
        let card = AnalysisFindingCard(finding: MockAnalysisFindings.vitaminCWithRetinol)
        #expect(card.finding == MockAnalysisFindings.vitaminCWithRetinol)
        #expect(card.headline == MockAnalysisFindings.vitaminCWithRetinol.headline)
        #expect(card.tag == MockAnalysisFindings.vitaminCWithRetinol.category)
    }
}
