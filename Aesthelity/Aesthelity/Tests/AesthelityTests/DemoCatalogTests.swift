//
//  DemoCatalogTests.swift
//  AesthelityTests
//

import Testing
@testable import Aesthelity

struct DemoCatalogTests {
    let catalog: DemoCatalog

    init() throws {
        catalog = try DemoCatalog.load()
    }

    @Test func loadsBundledDemoData() {
        #expect(catalog.products.count == 17)
        #expect(catalog.profiles.count == 2)
        #expect(catalog.scenarios.count == 5)
    }

    @Test func productsAreLabeledFictional() {
        #expect(catalog.products.allSatisfy { $0.isFictional && $0.name.contains("Fictional") })
    }

    @Test func coversEveryScenarioType() {
        let types = Set(catalog.scenarios.map(\.scenarioType))
        #expect(types == ["normal", "caution", "allergen", "unknown"])
    }

    @Test func scenarioReferencesResolve() {
        for scenario in catalog.scenarios {
            #expect(catalog.profile(id: scenario.profileId) != nil, "\(scenario.id): missing profile")
            for productID in scenario.productIds {
                #expect(catalog.product(id: productID) != nil, "\(scenario.id): missing product \(productID)")
            }
            for finding in scenario.expectedFindings {
                #expect(finding.productIds.allSatisfy { catalog.product(id: $0) != nil })
            }
        }
    }

    @Test func findingsHaveUserFacingText() {
        let findings = catalog.scenarios.flatMap(\.expectedFindings)
        #expect(!findings.isEmpty)
        for finding in findings {
            #expect(!finding.category.isEmpty)
            #expect(!finding.explanation.isEmpty)
            #expect(!finding.reason.isEmpty)
        }
    }

    @Test func normalScenarioHasNoFindings() throws {
        let normal = try #require(catalog.scenarios.first { $0.scenarioType == "normal" })
        #expect(normal.expectedFindings.isEmpty)
    }

    @Test func allergenFindingNamesTheIngredient() throws {
        let allergen = try #require(catalog.scenarios.flatMap(\.expectedFindings).first { $0.kind == "allergen" })
        #expect(allergen.ingredient == "Limonene")
    }
}
