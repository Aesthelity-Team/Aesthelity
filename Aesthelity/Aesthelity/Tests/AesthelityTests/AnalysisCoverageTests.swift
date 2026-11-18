//
//  AnalysisCoverageTests.swift
//  AesthelityTests
//
//  Unit tests for analysis coverage states, detection of missing/unmatched data,
//  fail-closed safety handling, and consistent presentation of normal, caution,
//  conflict, and unknown results.
//

import Testing
import Foundation
@testable import Aesthelity

struct AnalysisCoverageTests {

    // MARK: - Scenario 1: Complete Coverage (Normal / Low-Concern)

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

    @Test func normalResultDisplaysClearLowConcernExplanationWithoutGuarantees() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "am",
            "activeCatalogVersion": 1,
            "outcome": "noFindings",
            "completeness": "complete",
            "productIDs": ["cleanser_gel", "serum_vitamin_c", "moisturizer_gel", "sunscreen_mineral"],
            "findings": [],
            "coverage": {
                "status": "complete",
                "unknownIngredientCount": 0,
                "missingReferenceCount": 0,
                "limitations": ["Only approved v1 reference rules evaluated."]
            },
            "summary": "No interactions or cautions detected among verified ingredients.",
            "limitations": [
                "Informational only. This is not a medical diagnosis or a safety guarantee."
            ],
            "displayLabel": "No recorded concerns"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.outcome == "noFindings")
        #expect(payload.hasCompleteCoverage == true)
        #expect(payload.findings.isEmpty)
        #expect(payload.displayLabel == "No recorded concerns")
        #expect(payload.summary?.contains("No interactions or cautions detected") == true)

        // Verifies absence of unsupported medical safety claims
        let limitationJoined = payload.limitations.joined(separator: " ")
        #expect(limitationJoined.contains("not a medical diagnosis or a safety guarantee"))
    }

    // MARK: - Scenario 2: Caution Results (Ingredient Combinations)

    @Test func cautionResultPresentsAffectedProductsIngredientsSeverityAndReason() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "pm",
            "activeCatalogVersion": 3,
            "outcome": "findings",
            "completeness": "complete",
            "productIDs": ["serum_retinol", "treatment_exfoliant"],
            "findings": [
                {
                    "ruleID": "irritation.retinol-benzoyl-peroxide-with-exfoliant",
                    "ruleStatus": "approved",
                    "outcome": "caution",
                    "categoryID": "ingredient-combination",
                    "severity": "moderate",
                    "productIDs": ["serum_retinol", "treatment_exfoliant"],
                    "ingredientIDs": ["retinol", "glycolic-acid"],
                    "matchedClassIDs": ["exfoliant"],
                    "explanation": "The American Academy of Dermatology notes exfoliating while using retinol may increase irritation or dryness.",
                    "reason": "The rule matches retinol or benzoyl peroxide with class exfoliant.",
                    "limitations": [
                        "Team-approved v1 rules. Severity is display priority and not a clinical grade."
                    ],
                    "originalText": null,
                    "rowIndex": null
                }
            ],
            "coverage": {
                "status": "complete",
                "unknownIngredientCount": 0,
                "missingReferenceCount": 0,
                "limitations": []
            },
            "summary": "1 caution identified in routine.",
            "limitations": [
                "Team-approved v1 rules. This is not clinically validated or a safety guarantee."
            ],
            "displayLabel": "1 Caution"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.outcome == "findings")
        #expect(payload.findings.count == 1)

        let finding = try #require(payload.findings.first)
        #expect(finding.outcome == "caution")
        #expect(finding.severity == "moderate")
        #expect(finding.categoryID == "ingredient-combination")
        #expect(finding.productIDs == ["serum_retinol", "treatment_exfoliant"])
        #expect(finding.ingredientIDs == ["retinol", "glycolic-acid"])
        #expect(finding.matchedClassIDs == ["exfoliant"])
        #expect(finding.isUnknownOrCoverageGap == false)
        #expect(finding.explanation.contains("exfoliating while using retinol may increase irritation"))
        #expect(finding.reason.contains("matches retinol or benzoyl peroxide with class exfoliant"))

        // Verifies non-technical, supported claims disclaimer
        #expect(finding.limitations.contains { $0.contains("display priority and not a clinical grade") })
    }

    // MARK: - Scenario 3: Conflict Results (Ingredient Interactions)

    @Test func conflictResultPresentsAffectedProductsIngredientsHighSeverityAndReason() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "pm",
            "activeCatalogVersion": 3,
            "outcome": "findings",
            "completeness": "complete",
            "productIDs": ["example-benzoyl-peroxide", "example-tretinoin"],
            "findings": [
                {
                    "ruleID": "interaction.benzoyl-peroxide-with-tretinoin",
                    "ruleStatus": "approved",
                    "outcome": "conflict",
                    "categoryID": "ingredient-interaction",
                    "severity": "high",
                    "productIDs": ["example-benzoyl-peroxide", "example-tretinoin"],
                    "ingredientIDs": ["benzoyl-peroxide", "tretinoin"],
                    "matchedClassIDs": null,
                    "explanation": "Studies show conventional tretinoin gel degrades significantly when co-applied with benzoyl peroxide lotion under light.",
                    "reason": "Conflict means that studied mixture changed the active ingredient. It does not apply to all formulations.",
                    "limitations": [
                        "Team-approved v1 rules. Severity is display priority and not a clinical grade."
                    ],
                    "originalText": null,
                    "rowIndex": null
                }
            ],
            "coverage": {
                "status": "complete",
                "unknownIngredientCount": 0,
                "missingReferenceCount": 0,
                "limitations": []
            },
            "summary": "1 conflict identified in routine.",
            "limitations": [
                "Team-approved v1 rules. This is not clinically validated or a safety guarantee."
            ],
            "displayLabel": "1 Conflict"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.outcome == "findings")
        #expect(payload.findings.count == 1)

        let finding = try #require(payload.findings.first)
        #expect(finding.outcome == "conflict")
        #expect(finding.severity == "high")
        #expect(finding.categoryID == "ingredient-interaction")
        #expect(finding.productIDs == ["example-benzoyl-peroxide", "example-tretinoin"])
        #expect(finding.ingredientIDs == ["benzoyl-peroxide", "tretinoin"])
        #expect(finding.explanation.contains("conventional tretinoin gel degrades significantly"))
        #expect(finding.reason.contains("Conflict means that studied mixture changed the active ingredient"))

        // Verifies no unsupported medical claims are made
        #expect(finding.limitations.contains { $0.contains("display priority and not a clinical grade") })
    }

    // MARK: - Scenario 4: Partial & Incomplete Ingredient Information

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

    // MARK: - Scenario 5: Unmatched / Unverified Ingredient Data (Unknown Results)

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
                    "explanation": "Ingredient 'Mystic Botanical Herb Extract' could not be confirmed.",
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
                "limitations": ["1 ingredient was not recognized in the approved references."]
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

    @Test func unknownResultCommunicatesLimitationAndAvoidsDefinitiveConclusion() throws {
        let json = """
        {
            "contractVersion": 1,
            "ruleVersion": "1.0.0",
            "period": "pm",
            "activeCatalogVersion": 1,
            "outcome": "unknown",
            "completeness": "incomplete",
            "productIDs": ["unverified_serum"],
            "findings": [
                {
                    "ruleID": "coverage.unresolved-input",
                    "ruleStatus": "system-coverage",
                    "outcome": "unknown",
                    "categoryID": "coverage-gap",
                    "severity": null,
                    "productIDs": ["unverified_serum"],
                    "ingredientIDs": [],
                    "matchedClassIDs": null,
                    "explanation": "Unverified botanical components cannot be safely assessed.",
                    "reason": "normalization-uncertain",
                    "limitations": [
                        "Data is missing or uncertain. Do not interpret as safe or definitive."
                    ],
                    "originalText": "Special Compound X",
                    "rowIndex": 1
                }
            ],
            "coverage": {
                "status": "incomplete",
                "unknownIngredientCount": 1,
                "missingReferenceCount": 1,
                "limitations": ["Unverified ingredients present."]
            },
            "summary": "Assessment incomplete due to uncertain ingredient entries.",
            "limitations": [
                "Informational only. This is not a diagnosis or a safety guarantee."
            ],
            "displayLabel": "Incomplete data"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let payload = try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)

        #expect(payload.outcome == "unknown")
        #expect(payload.isLimitedCoverage == true)
        #expect(payload.hasCompleteCoverage == false)

        let finding = try #require(payload.findings.first)
        #expect(finding.severity == nil)
        #expect(finding.isUnknownOrCoverageGap == true)
        #expect(finding.limitations.contains { $0.contains("Do not interpret as safe or definitive") })
    }

    // MARK: - Scenario 6: Demo Scenarios & Legacy Fallback

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
