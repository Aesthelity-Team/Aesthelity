//
//  DemoAnalysisTests.swift
//  AesthelityTests
//

import Testing
@testable import Aesthelity

struct DemoAnalysisTests {
    let catalog: DemoCatalog

    init() throws {
        catalog = try DemoCatalog.load()
    }

    private func state(_ scenarioID: String, in catalog: DemoCatalog? = nil) -> DemoAnalysisState {
        DemoAnalysis.sample(scenarioID: scenarioID, title: "Test", in: catalog ?? self.catalog).state
    }

    private func findings(_ scenarioID: String) throws -> [DemoFindingPresentation] {
        guard case .findings(let findings) = state(scenarioID) else {
            Issue.record("\(scenarioID) did not produce findings")
            return []
        }
        return findings
    }

    private func scenario(_ id: String) throws -> DemoScenario {
        try #require(catalog.scenarios.first { $0.id == id })
    }

    private func replacing(_ scenario: DemoScenario, findings: [DemoFinding]? = nil, profileId: String? = nil) -> DemoCatalog {
        let edited = DemoScenario(
            id: scenario.id,
            scenarioType: scenario.scenarioType,
            productIds: scenario.productIds,
            profileId: profileId ?? scenario.profileId,
            routineTime: scenario.routineTime,
            expectedFindings: findings ?? scenario.expectedFindings
        )
        return DemoCatalog(
            products: catalog.products,
            profiles: catalog.profiles,
            scenarios: catalog.scenarios.map { $0.id == scenario.id ? edited : $0 }
        )
    }

    private func copy(_ finding: DemoFinding, ingredient: String?) -> DemoFinding {
        DemoFinding(
            kind: finding.kind,
            productIds: finding.productIds,
            ingredient: ingredient,
            message: finding.message,
            category: finding.category,
            explanation: finding.explanation,
            reason: finding.reason
        )
    }

    @Test func scenarioProductIDsResolveToCatalogNames() throws {
        let caution = try #require(try findings("caution_pm").first)
        #expect(caution.productNames == ["Retinol Night Serum (Fictional)", "Exfoliating Treatment (Fictional)"])

        let normal = try scenario("normal_am")
        let expectedNames = normal.productIds.compactMap { catalog.product(id: $0)?.name }
        #expect(expectedNames.count == normal.productIds.count)
        #expect(state("normal_am") == .normal(productNames: expectedNames))
    }

    @Test func namedIngredientIsExposedAndLabeledAsSampleAllergy() throws {
        let allergen = try #require(try findings("allergen_mist").first)
        #expect(allergen.ingredient == "Limonene")
        #expect(allergen.ingredientText == "Limonene")
        #expect(allergen.productNames == ["Fragranced Mist (Fictional)"])
        #expect(allergen.status.label.contains("Sample allergy"))
        let limitation = try #require(allergen.limitation)
        #expect(limitation.contains("demo profile"))
        #expect(limitation.contains("not your profile"))
        #expect(limitation.contains("Limonene"))

        let sample = DemoAnalysis.sample(scenarioID: "allergen_mist", title: "Allergy", in: catalog)
        #expect(sample.summary.contains("not your profile"))
    }

    @Test func cautionUsesCatalogUserFacingTextAndWordedStatus() throws {
        let source = try #require(try scenario("caution_pm").expectedFindings.first)
        let caution = try #require(try findings("caution_pm").first)
        #expect(caution.status == .caution)
        #expect(caution.status.label == "Caution")
        #expect(caution.category == source.category)
        #expect(caution.explanation == source.explanation)
        #expect(caution.reason == source.reason)
        #expect(caution.explanation != source.message)
        #expect(caution.limitation == nil)
    }

    @Test(arguments: ["unknown_sunscreen", "unknown_mask"])
    func unknownIsNonDefinitiveWithExplicitLimitation(scenarioID: String) throws {
        let unknown = try #require(try findings(scenarioID).first)
        #expect(unknown.status == .unknown)
        #expect(!unknown.status.isDefinitive)
        #expect(unknown.status.label.contains("Unknown"))
        let limitation = try #require(unknown.limitation)
        #expect(limitation.contains("incomplete"))
        #expect(limitation.contains("no definitive conclusion"))
        #expect(unknown.ingredient == nil)
    }

    @Test func missingIngredientUsesTruthfulFallback() throws {
        let caution = try #require(try findings("caution_pm").first)
        #expect(caution.ingredient == nil)
        #expect(caution.ingredientText == DemoFindingPresentation.missingIngredientText)

        let source = try scenario("caution_pm")
        let blank = try #require(source.expectedFindings.first)
        let edited = replacing(source, findings: [copy(blank, ingredient: "   ")])
        guard case .findings(let mapped) = state("caution_pm", in: edited) else {
            Issue.record("Blank ingredient should still map to a finding")
            return
        }
        #expect(mapped.first?.ingredient == nil)
        #expect(mapped.first?.ingredientText == DemoFindingPresentation.missingIngredientText)
    }

    @Test func emptyNormalScenarioProducesNormalStateWithoutFabricatedFinding() throws {
        guard case .normal(let names) = state("normal_am") else {
            Issue.record("normal_am should map to the normal state")
            return
        }
        #expect(names.count == 4)

        let caution = try scenario("caution_pm")
        #expect(state("caution_pm", in: replacing(caution, findings: [])) == .unavailable(DemoAnalysis.missingReferenceMessage))
    }

    @Test func loadAndReferenceFailuresAreUnavailable() throws {
        struct LoadFailure: Error {}
        let failed = DemoAnalysis.samples(from: .failure(LoadFailure()))
        #expect(failed.count == DemoAnalysis.scenarioChoices.count)
        #expect(failed.allSatisfy { $0.state == .unavailable(DemoAnalysis.loadFailedMessage) })

        let missingProducts = DemoCatalog(
            products: catalog.products.filter { $0.id != "serum_retinol" && $0.id != "cleanser_gel" },
            profiles: catalog.profiles,
            scenarios: catalog.scenarios
        )
        #expect(state("caution_pm", in: missingProducts) == .unavailable(DemoAnalysis.missingReferenceMessage))
        #expect(state("normal_am", in: missingProducts) == .unavailable(DemoAnalysis.missingReferenceMessage))

        #expect(state("no_such_scenario") == .unavailable(DemoAnalysis.missingReferenceMessage))

        let missingProfile = replacing(try scenario("normal_am"), profileId: "no_such_profile")
        #expect(state("normal_am", in: missingProfile) == .unavailable(DemoAnalysis.missingReferenceMessage))

        let allergen = try scenario("allergen_mist")
        let noRecordedAllergy = replacing(allergen, profileId: "profile_no_recorded_allergies")
        #expect(state("allergen_mist", in: noRecordedAllergy) == .unavailable(DemoAnalysis.missingReferenceMessage))
    }

    @Test func bundledSamplesCoverEachDemoStateAndLoadSuccessfully() throws {
        let samples = DemoAnalysis.bundledSamples
        #expect(samples.map(\.title) == ["Normal", "Caution", "Allergy", "Unknown"])
        let types = try samples.map { sample in try #require(catalog.scenarios.first { $0.id == sample.id }).scenarioType }
        #expect(Set(types) == Set(DemoScenarioType.allCases))
        for sample in samples {
            if case .unavailable = sample.state { Issue.record("\(sample.id) unexpectedly unavailable") }
        }
    }
}
