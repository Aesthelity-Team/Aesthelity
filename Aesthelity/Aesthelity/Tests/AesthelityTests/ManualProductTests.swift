import Foundation
import Testing
@testable import Aesthelity

struct ManualProductTests {
    private func roundTrip(_ product: ManualProduct) throws -> ManualProduct {
        try JSONDecoder().decode(ManualProduct.self, from: JSONEncoder().encode(product))
    }

    @Test func roundTripPreservesIdentityLabelOrderDuplicatesAndWarnings() throws {
        let normalizer = IngredientNormalizer(catalog: try .loadBundled())
        let names = ["  Aqua  ", "Niacinimide", "Vitamin C", "Unobtainium Extract", "Water"]
        let label = "  Aqua  , Niacinimide\nVitamin C\nUnobtainium Extract, Water  "
        let product = ManualProduct(
            name: "Sample serum",
            brand: "Sample brand",
            category: .serum,
            rawIngredientList: label,
            ingredients: normalizer.normalize(names)
        )

        let restored = try roundTrip(product)

        #expect(restored == product)
        #expect(restored.id == product.id)
        #expect(restored.rawIngredientList == label)
        #expect(restored.ingredients.map(\.originalText) == names)
        #expect(restored.ingredients.map(\.ingredientID) == ["water", nil, nil, nil, "water"])
        #expect(restored.ingredients.warnings.map(\.input) == Array(names[1...3]))
    }

    @Test func optionalMetadataDoesNotInventDefaults() throws {
        let product = ManualProduct(name: "Sample product", rawIngredientList: "Water", ingredients: [])
        let restored = try roundTrip(product)

        #expect(restored.brand == nil)
        #expect(restored.category == nil)
        let data = try JSONEncoder().encode(product)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["source"] as? String == "manual")
        #expect(object["schemaVersion"] as? Int == 1)
    }

    @Test func separatelyCreatedProductsHaveDistinctIdentities() throws {
        let first = ManualProduct(name: "Sample product", rawIngredientList: "Water", ingredients: [])
        let second = ManualProduct(name: "Sample product", rawIngredientList: "Water", ingredients: [])

        #expect(first.id != second.id)
        #expect(try roundTrip(first).id == first.id)
    }

    @Test(arguments: DemoProductCategory.allCases)
    func catalogCategoriesRoundTripWithoutChangingTheirRawValues(category: DemoProductCategory) throws {
        let product = ManualProduct(name: "Sample product", category: category, rawIngredientList: "Water", ingredients: [])
        #expect(try roundTrip(product).category == category)
        let data = try JSONEncoder().encode(category)
        #expect(try JSONDecoder().decode(String.self, from: data) == category.rawValue)
    }

    @Test func schemaVersionDefaultsWhenMissingAndPreservesExplicitValues() throws {
        let product = ManualProduct(name: "Sample product", rawIngredientList: "Water", ingredients: [], schemaVersion: 2)
        #expect(try roundTrip(product).schemaVersion == 2)

        let data = try JSONEncoder().encode(product)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "schemaVersion")
        let olderData = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(ManualProduct.self, from: olderData).schemaVersion == 1)
    }

    @Test func unknownCategoryOrSourceDoesNotDecodeAsAKnownValue() throws {
        let product = ManualProduct(name: "Sample product", rawIngredientList: "Water", ingredients: [])
        let data = try JSONEncoder().encode(product)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        for (key, value) in [("category", "all"), ("source", "verified-catalog")] {
            var invalid = object
            invalid[key] = value
            let invalidData = try JSONSerialization.data(withJSONObject: invalid)
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(ManualProduct.self, from: invalidData)
            }
        }
    }
}

struct ManualProductDraftTests {
    @Test func newDraftStartsWithoutProductInformation() {
        let draft = ManualProductDraft()
        #expect(draft.name.isEmpty)
        #expect(draft.brand.isEmpty)
        #expect(draft.category == nil)
        #expect(draft.rawIngredientList.isEmpty)
    }

    @Test func editingRetainsUnprocessedText() {
        var draft = ManualProductDraft()
        draft.name = "  Sample product  "
        draft.brand = "  Sample brand  "
        draft.category = .moisturizer
        draft.rawIngredientList = " Aqua, !!!\nVitamin C\u{200B}\nWater, Water "

        #expect(draft.name == "  Sample product  ")
        #expect(draft.brand == "  Sample brand  ")
        #expect(draft.category == .moisturizer)
        #expect(draft.rawIngredientList == " Aqua, !!!\nVitamin C\u{200B}\nWater, Water ")
    }
}
