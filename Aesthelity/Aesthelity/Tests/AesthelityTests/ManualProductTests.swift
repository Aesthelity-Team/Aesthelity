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
    private func submitted(_ draft: ManualProductDraft) throws -> ManualProduct {
        let normalizer = IngredientNormalizer(catalog: try .loadBundled())
        guard case .completed(let product) = draft.submit(using: normalizer) else {
            Issue.record("Expected a valid product")
            throw NSError(domain: "ManualProductDraftTests", code: 1)
        }
        return product
    }

    @Test func missingFieldsAreReportedTogether() throws {
        let draft = ManualProductDraft()
        #expect(draft.validationErrors().map(\.field) == [.name, .ingredientList])
        let normalizer = IngredientNormalizer(catalog: try .loadBundled())
        #expect(draft.submit(using: normalizer) == .invalid(draft.validationErrors()))
        #expect(draft.validationErrors().allSatisfy { !$0.message.isEmpty })
    }

    @Test func submissionTrimsMetadataAndPreservesLabelOrderAndDuplicates() throws {
        let label = "Ingredients: Aqua, Glycerin\nWater, Water"
        let product = try submitted(ManualProductDraft(name: "  Serum  ", brand: " Brand ", category: .serum, rawIngredientList: label))
        #expect(product.name == "Serum")
        #expect(product.brand == "Brand")
        #expect(product.category == .serum)
        #expect(product.rawIngredientList == label)
        #expect(product.ingredients.map(\.ingredientID) == ["water", "glycerin", "water", "water"])
    }

    @Test func optionalMetadataStaysAbsent() throws {
        let product = try submitted(ManualProductDraft(name: "Serum", brand: "   ", rawIngredientList: "Water"))
        #expect(product.brand == nil)
        #expect(product.category == nil)
    }

    @Test func unresolvedEntriesKeepTheirStatusesAndWarnings() throws {
        let product = try submitted(ManualProductDraft(name: "Serum", rawIngredientList: "Niacinimide, Vitamin C, Unobtainium Extract, Vitamin C"))
        #expect(product.ingredients[0].status == .uncertain(suggestedID: "niacinamide"))
        guard case .ambiguous = product.ingredients[1].status else {
            Issue.record("Vitamin C must remain ambiguous")
            return
        }
        #expect(product.ingredients[2].status == .unmatched)
        #expect(product.ingredients[3] == product.ingredients[1])
        #expect(product.ingredients.warnings.count == 4)
        #expect(product.ingredients.allSatisfy { $0.ingredientID == nil })
    }

    @Test(arguments: ["!!!", "123", "2%", "***", ":"])
    func malformedEntryCannotDisappear(input: String) throws {
        let draft = ManualProductDraft(name: "Serum", rawIngredientList: "Water, \(input), Glycerin")
        let error = try #require(draft.validationErrors().first)
        #expect(error.field == .ingredientList)
        #expect(error.entryIndex == 1)
        #expect(error.input == " \(input)")
        #expect(error.reason == .missingLetters)
        let normalizer = IngredientNormalizer(catalog: try .loadBundled())
        #expect(draft.submit(using: normalizer) == .invalid(draft.validationErrors()))
    }

    @Test(arguments: ["", " \n ", ",,;\n", "Ingredients:", "\u{200B}"])
    func emptyIngredientListsAreRejected(label: String) {
        let errors = ManualProductDraft(name: "Serum", rawIngredientList: label).validationErrors()
        #expect(errors.contains { $0.field == .ingredientList && $0.reason == .required })
    }

    @Test func ingredientLengthUsesCleanedText() throws {
        let name = String(repeating: "a", count: 120)
        let product = try submitted(ManualProductDraft(name: "Serum", rawIngredientList: "  \(name)  "))
        #expect(product.ingredients.first?.originalText == name)
        let invalid = ManualProductDraft(name: "Serum", rawIngredientList: name + "a")
        #expect(invalid.validationErrors().map(\.reason) == [.tooLong])
    }

    @Test func pastedFormatCharactersAreRemovedOnlyFromPreparedValues() throws {
        let draft = ManualProductDraft(name: "Serum\u{200B}", rawIngredientList: "Retinol\u{200B}, Wa\u{00AD}ter")
        let product = try submitted(draft)
        #expect(product.name == "Serum")
        #expect(product.ingredients.map(\.ingredientID) == ["retinol", "water"])
        #expect(product.rawIngredientList == draft.rawIngredientList)
    }

    @Test(arguments: ["Water\u{0000}", "Water\tGlycerin", "Water\u{0007}"])
    func realControlsAreRejected(label: String) {
        let errors = ManualProductDraft(name: "Serum", rawIngredientList: label).validationErrors()
        #expect(errors.contains { $0.reason == .controlCharacters })
    }

    @Test func metadataControlsAreRejected() {
        let errors = ManualProductDraft(name: "Serum\nName", brand: "Brand\tName", rawIngredientList: "Water").validationErrors()
        #expect(errors.map(\.field) == [.name, .brand])
        #expect(errors.allSatisfy { $0.reason == .controlCharacters })
    }

    @Test func bracketedNamesAndNumericCommasRemainWhole() throws {
        let product = try submitted(ManualProductDraft(name: "Serum", rawIngredientList: "Water (Aqua, Eau), 1,3-Butylene Glycol, Niacinamide 10%"))
        #expect(product.ingredients.map(\.originalText) == ["Water (Aqua, Eau)", "1,3-Butylene Glycol", "Niacinamide"])
    }

    @Test(arguments: ["Water (Aqua", "Water], Glycerin", "Water ([Aqua)]"])
    func unbalancedBracketsAreReported(label: String) {
        let errors = ManualProductDraft(name: "Serum", rawIngredientList: label).validationErrors()
        #expect(errors.contains { $0.reason == .unbalancedBrackets })
    }

    @Test func correctingInputAllowsResubmission() throws {
        var draft = ManualProductDraft(name: "Serum", rawIngredientList: "Water, !!!")
        #expect(!draft.validationErrors().isEmpty)
        draft.rawIngredientList = "Water, Glycerin"
        let product = try submitted(draft)
        #expect(product.ingredients.map(\.ingredientID) == ["water", "glycerin"])
        #expect(draft.rawIngredientList == "Water, Glycerin")
    }

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
