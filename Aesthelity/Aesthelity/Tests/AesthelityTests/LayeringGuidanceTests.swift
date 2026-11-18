import Foundation
import Testing
@testable import Aesthelity

struct LayeringGuidanceTests {
    private func step(_ name: String, _ category: DemoProductCategory,
                      status: IngredientListStatus = .complete) -> RoutineStepItem {
        RoutineProductSnapshot(DemoProduct(id: name, name: name, brand: "Fixture", category: category,
                                          subtype: "fixture", ingredients: ["Water"],
                                          ingredientListStatus: status)).step
    }

    @Test func suggestsCategoryOrderAndPreservesStepIdentity() {
        let inputs = [step("SPF", .sunscreen), step("Cream", .moisturizer),
                      step("Serum", .serum), step("Wash", .cleanser)]
        let result = LayeringGuidance.evaluate(inputs, period: .am)
        #expect(!result.isIncomplete)
        #expect(result.steps.map(\.name) == ["Wash", "Serum", "Cream", "SPF"])
        #expect(result.steps.map(\.id) == inputs.reversed().map(\.id))
        #expect(result.steps.allSatisfy { !$0.explanation.isEmpty })
        #expect(inputs.first?.title == "SPF")
    }

    @Test func multipleTreatmentsRetainRelativeOrderWithCaution() {
        let inputs = [step("Retinol", .treatment), step("Exfoliant", .treatment), step("Wash", .cleanser)]
        let result = LayeringGuidance.evaluate(inputs, period: .pm)
        #expect(result.steps.map(\.name) == ["Wash", "Retinol", "Exfoliant"])
        #expect(result.cautions.contains { $0.contains("combined use have not been established") })
    }

    @Test(arguments: [IngredientListStatus.partial, .unavailable])
    func incompleteListsKeepSavedOrder(_ status: IngredientListStatus) {
        let inputs = [step("Cream", .moisturizer), step("Wash", .cleanser, status: status)]
        let result = LayeringGuidance.evaluate(inputs, period: .am)
        #expect(result.isIncomplete)
        #expect(result.steps.map(\.id) == inputs.map(\.id))
        #expect(result.steps.last?.explanation.contains("Order unknown") == true)
    }

    @Test(arguments: [DemoProductCategory.toner, .mist, .mask])
    func unsupportedCategoriesStayUncertain(_ category: DemoProductCategory) {
        #expect(LayeringGuidance.evaluate([step("Other", category)], period: .am).isIncomplete)
    }

    @Test func missingSnapshotAndEmptyRoutineStayUncertain() {
        let legacy = RoutineStepItem(stepNumber: 1, title: "Cleanser", subtitle: "", state: .incomplete)
        #expect(LayeringGuidance.evaluate([legacy], period: .am).isIncomplete)
        #expect(LayeringGuidance.evaluate([], period: .am).isIncomplete)
        #expect(LayeringGuidance.evaluate([step("SPF", .sunscreen)], period: .pm).isIncomplete)
    }

    @Test func legacySnapshotsDecodeWithoutCategory() throws {
        let product = try #require(step("Wash", .cleanser).product)
        var body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(product)) as? [String: Any])
        body.removeValue(forKey: "category")
        let legacy = try JSONDecoder().decode(RoutineProductSnapshot.self, from: JSONSerialization.data(withJSONObject: body))
        #expect(legacy.category == nil)
        #expect(LayeringGuidance.evaluate([legacy.step], period: .am).isIncomplete)
    }

    @Test func manualProductCoverageRemainsUnverified() throws {
        let normalizer = try IngredientNormalizer(catalog: .loadBundled())
        let draft = ManualProductDraft(name: "Manual", rawIngredientList: "Water")
        guard case .completed(let manual) = draft.submit(using: normalizer) else {
            Issue.record("Expected a valid manual product")
            return
        }
        #expect(LayeringGuidance.evaluate([RoutineProductSnapshot(manual).step], period: .am).isIncomplete)
    }
}
