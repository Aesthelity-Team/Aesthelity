//
//  AnalysisCoverageTests.swift
//  AesthelityTests
//
//  Unit tests for analysis coverage states, detection of missing/unmatched data,
//  and fail-closed safety handling.
//

import Testing
import Foundation
@testable import Aesthelity

struct AnalysisCoverageTests {

    // MARK: - Scenario 1: Complete Coverage

    @Test func completeInputReportsCompleteCoverage() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "am",
            "activeCatalogVersion": 1,
            "outcome": "noFindings",
            "completeness": "complete",
            "productIDs": ["cleanser_gel", "serum_vitamin_c"],
            "findings": [],
            "coverage": {
                "status": "complete",
                "unknownIngredientCount": 0,
                "missingReferenceCount": 0,
                "limitations": ["Only currently approved reference records were considered."]
            },
            "summary": "Full analysis completed with all ingredient data verified.",
            "limitations": ["Informational only. This is not a diagnosis or a safety guarantee."],
            "displayLabel": "No findings"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.contractVersion == 1)
        #expect(payload.completeness == "complete")
        #expect(payload.hasCompleteCoverage == true)
        #expect(payload.isLimitedCoverage == false)
        #expect(payload.coverage != nil)
        #expect(payload.coverage?.status == "complete")
        #expect(payload.coverage?.isComplete == true)
        #expect(payload.coverage?.unknownIngredientCount == 0)
        #expect(payload.coverage?.missingReferenceCount == 0)
        #expect(payload.findings.isEmpty)
        #expect(payload.summary == "Full analysis completed with all ingredient data verified.")
    }

    // MARK: - Scenario 2: Partial & Incomplete Ingredient Information

    @Test func partialListReportsLimitedCoverageAndIdentifiesAffectedProduct() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "pm",
            "activeCatalogVersion": 1,
            "outcome": "unknown",
            "completeness": "incomplete",
            "productIDs": ["mask_partial"],
            "findings": [
                {
                    "ruleID": "coverage.unresolved-input",
                    "ruleStatus": "system-coverage",
                    "outcome": "unknown",
                    "categoryID": "coverage-gap",
                    "severity": null,
                    "productIDs": ["mask_partial"],
                    "ingredientIDs": [],
                    "matchedClassIDs": null,
                    "explanation": "This product has a partial ingredient list.",
                    "reason": "partial-list",
                    "limitations": ["Unresolved input is not treated as safe or as a confirmed ingredient."],
                    "originalText": null,
                    "rowIndex": null
                }
            ],
            "coverage": {
                "status": "incomplete",
                "unknownIngredientCount": 0,
                "missingReferenceCount": 0,
                "limitations": ["One or more products have incomplete ingredient lists."]
            },
            "summary": "Analysis coverage is limited due to incomplete ingredient data.",
            "limitations": ["Informational only. This is not a diagnosis or a safety guarantee."],
            "displayLabel": null
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.hasCompleteCoverage == false)
        #expect(payload.isLimitedCoverage == true)
        #expect(payload.coverage?.status == "incomplete")
        #expect(payload.coverage?.isComplete == false)
        #expect(payload.findings.count == 1)

        let finding = try #require(payload.findings.first)
        #expect(finding.productIDs == ["mask_partial"])
        #expect(finding.reason == "partial-list")
        #expect(finding.outcome == "unknown")
        #expect(finding.categoryID == "coverage-gap")
        #expect(finding.isUnknownOrCoverageGap == true)
    }

    @Test func unavailableListReportsLimitedCoverageAndIdentifiesAffectedProduct() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "pm",
            "activeCatalogVersion": 1,
            "outcome": "unknown",
            "completeness": "incomplete",
            "productIDs": ["sunscreen_unknown"],
            "findings": [
                {
                    "ruleID": "coverage.unresolved-input",
                    "ruleStatus": "system-coverage",
                    "outcome": "unknown",
                    "categoryID": "coverage-gap",
                    "severity": null,
                    "productIDs": ["sunscreen_unknown"],
                    "ingredientIDs": [],
                    "matchedClassIDs": null,
                    "explanation": "This product's ingredient list is unavailable.",
                    "reason": "unavailable-list",
                    "limitations": ["Unresolved input is not treated as safe or as a confirmed ingredient."],
                    "originalText": null,
                    "rowIndex": null
                }
            ],
            "coverage": {
                "status": "incomplete",
                "unknownIngredientCount": 0,
                "missingReferenceCount": 0,
                "limitations": ["One or more products have unavailable ingredient lists."]
            },
            "summary": "Analysis coverage is limited.",
            "limitations": ["Informational only. This is not a diagnosis or a safety guarantee."],
            "displayLabel": null
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.hasCompleteCoverage == false)
        #expect(payload.isLimitedCoverage == true)
        #expect(payload.findings.count == 1)

        let finding = try #require(payload.findings.first)
        #expect(finding.productIDs == ["sunscreen_unknown"])
        #expect(finding.reason == "unavailable-list")
        #expect(finding.isUnknownOrCoverageGap == true)
    }

    // MARK: - Scenario 3: Unmatched / Unverified Ingredient Data

    @Test func unmatchedIngredientMarkedUnknownAndIdentifiesAffectedIngredient() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "pm",
            "activeCatalogVersion": 1,
            "outcome": "unknown",
            "completeness": "incomplete",
            "productIDs": ["custom_moisturizer"],
            "findings": [
                {
                    "ruleID": "coverage.unresolved-input",
                    "ruleStatus": "system-coverage",
                    "outcome": "unknown",
                    "categoryID": "coverage-gap",
                    "severity": null,
                    "productIDs": ["custom_moisturizer"],
                    "ingredientIDs": [],
                    "matchedClassIDs": null,
                    "explanation": "This row could not be checked against an approved canonical ingredient record.",
                    "reason": "normalization-unknown",
                    "limitations": ["Unresolved input is not treated as safe or as a confirmed ingredient."],
                    "originalText": "Mystic Botanical Herb Extract",
                    "rowIndex": 3
                }
            ],
            "coverage": {
                "status": "incomplete",
                "unknownIngredientCount": 1,
                "missingReferenceCount": 0,
                "limitations": ["Unresolved ingredients cannot be checked against safety rules."]
            },
            "summary": "1 ingredient could not be verified against approved references.",
            "limitations": ["Informational only. This is not a diagnosis or a safety guarantee."],
            "displayLabel": null
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.hasCompleteCoverage == false)
        #expect(payload.coverage?.unknownIngredientCount == 1)

        let finding = try #require(payload.findings.first)
        #expect(finding.outcome == "unknown")
        #expect(finding.categoryID == "coverage-gap")
        #expect(finding.isUnknownOrCoverageGap == true)
        #expect(finding.productIDs == ["custom_moisturizer"])
        #expect(finding.originalText == "Mystic Botanical Herb Extract")
        #expect(finding.rowIndex == 3)
        #expect(finding.reason == "normalization-unknown")

        // Crucial safety check: Unknown items must explicitly state they are not safe
        #expect(finding.limitations.contains { $0.contains("not treated as safe") })
    }

    // MARK: - Demo Scenarios & Legacy Fallback

    @Test func demoScenariosIncludeCompletePartialAndUnavailable() throws {
        let allScenarios = AnalysisDemoScenario.allCases
        #expect(allScenarios.contains(.noFindingAM))
        #expect(allScenarios.contains(.cautionPM))
        #expect(allScenarios.contains(.allergyMatch))
        #expect(allScenarios.contains(.partialProduct))
        #expect(allScenarios.contains(.unavailableProduct))

        let noFinding = AnalysisDemoScenario.noFindingAM
        #expect(noFinding.period == "am")
        #expect(noFinding.productIDs.contains("cleanser_gel"))

        let partial = AnalysisDemoScenario.partialProduct
        #expect(partial.productIDs == ["mask_partial"])
        #expect(partial.period == "pm")

        let unavailable = AnalysisDemoScenario.unavailableProduct
        #expect(unavailable.productIDs == ["sunscreen_unknown"])
        #expect(unavailable.period == "pm")
    }

    @Test func legacyPayloadWithoutCoverageObjectGracefullyFallsBack() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "am",
            "activeCatalogVersion": 1,
            "outcome": "noFindings",
            "completeness": "complete",
            "productIDs": ["cleanser_gel"],
            "findings": [],
            "limitations": [],
            "displayLabel": "No findings"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.coverage == nil)
        #expect(payload.hasCompleteCoverage == true)
        #expect(payload.isLimitedCoverage == false)
    }

    @Test func legacyIncompletePayloadWithoutCoverageFallsBackToLimited() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "am",
            "activeCatalogVersion": 1,
            "outcome": "unknown",
            "completeness": "incomplete",
            "productIDs": ["mask_partial"],
            "findings": [],
            "limitations": [],
            "displayLabel": null
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.coverage == nil)
        #expect(payload.hasCompleteCoverage == false)
        #expect(payload.isLimitedCoverage == true)
    }
}
