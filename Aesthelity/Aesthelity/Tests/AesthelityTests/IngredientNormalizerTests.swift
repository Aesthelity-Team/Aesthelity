//
//  IngredientNormalizerTests.swift
//  AesthelityTests
//
//  Created by Gaurav Pandey on 10/8/26.
//

import Testing
@testable import Aesthelity

struct IngredientNormalizerTests {
    let catalog: IngredientAliasCatalog
    let normalizer: IngredientNormalizer

    init() throws {
        catalog = try IngredientAliasCatalog.loadBundled()
        normalizer = IngredientNormalizer(catalog: catalog)
    }

    @Test func bundledCatalogIsConsistent() {
        #expect(catalog.validationIssues() == [])
        #expect(catalog.ingredients.count >= 20)
    }

    @Test func everyIngredientHasAClass() {
        #expect(catalog.ingredients.filter(\.classes.isEmpty).map(\.id) == [])
    }

    @Test func familiesGroupRelatedIngredients() {
        let retinoids = catalog.ingredients.filter { $0.classes.contains("retinoid") }.map(\.id).sorted()
        #expect(retinoids == ["retinal", "retinol", "retinyl-palmitate"])
        #expect(normalizer.ingredient(withID: "glycolic-acid")?.classes.contains("aha") == true)
    }

    @Test func validationRejectsMalformedIDsAndClasses() {
        let broken = IngredientAliasCatalog(
            version: 1,
            ingredients: [
                CanonicalIngredient(id: "Retinol", name: "Retinol", aliases: [], classes: ["Retinoid"]),
                CanonicalIngredient(id: "retinal", name: "Retinal", aliases: ["Retinol"], classes: ["retinoid"]),
            ],
            ambiguousTerms: []
        )
        #expect(broken.validationIssues().count == 3)
    }

    // MARK: Scenario 1: spelling variations and aliases map to the canonical ID

    @Test(arguments: [
        ("Water", "water"),
        ("Aqua", "water"),
        ("Aqua/Water/Eau", "water"),
        ("Glycerine", "glycerin"),
        ("NICOTINAMIDE", "niacinamide"),
        ("  niacinamide ", "niacinamide"),
        ("Parfum", "fragrance"),
        ("Fragrance (Parfum)", "fragrance"),
        ("Tocopherol (Vitamin E)", "tocopherol"),
        ("Vitamin E (Tocopherol)", "tocopherol"),
        ("Ceramide 3", "ceramide-np"),
        ("CI 77891", "titanium-dioxide"),
        ("Retinaldehyde", "retinal"),
        ("Alcohol Denat.", "alcohol-denat"),
        ("Sodium Hyaluronate", "sodium-hyaluronate"),
    ])
    func mapsAliasToCanonicalID(input: String, expectedID: String) {
        let result = normalizer.normalize(input)
        #expect(result.status == .matched(ingredientID: expectedID))
        #expect(result.ingredientID == expectedID)
        #expect(result.warning == nil)
        #expect(result.originalText == input)
    }

    @Test func spellingVariantsConverge() {
        let variants = ["Ascorbic Acid", "L-Ascorbic Acid", "l ascorbic acid", "ASCORBIC ACID", "Ascórbic Acid"]
        let ids = Set(variants.map { normalizer.normalize($0).ingredientID })
        #expect(ids == ["ascorbic-acid"])
    }

    // MARK: Scenario 2: values that cannot be confidently matched are never treated as known

    @Test(arguments: ["Unobtainium Extract", "Aqau", "", "   "])
    func unmatchedValuesNeedReview(input: String) {
        let result = normalizer.normalize(input)
        #expect(result.status == .unmatched)
        #expect(result.ingredientID == nil)
        #expect(result.needsReview)
        #expect(result.warning?.input == input)
    }

    @Test(arguments: [
        ("Niacinimide", "niacinamide"),
        ("Glycolc Acid", "glycolic-acid"),
        ("Salicylc Acid", "salicylic-acid"),
    ])
    func typosAreUncertainNotMatched(input: String, suggestedID: String) {
        let result = normalizer.normalize(input)
        #expect(result.status == .uncertain(suggestedID: suggestedID))
        #expect(result.ingredientID == nil)
        #expect(result.needsReview)
        #expect(result.warning?.input == input)
    }

    // MARK: Scenario 3: inputs with several possible matches record the ambiguity

    @Test(arguments: [
        ("Vitamin C", ["ascorbic-acid", "ascorbyl-glucoside", "magnesium-ascorbyl-phosphate", "sodium-ascorbyl-phosphate"]),
        ("Vitamin E", ["tocopherol", "tocopheryl-acetate"]),
        ("AHA", ["glycolic-acid", "lactic-acid", "mandelic-acid"]),
        ("BHA", ["butylated-hydroxyanisole", "salicylic-acid"]),
        ("Retinl", ["retinal", "retinol"]),
        ("Water (Glycerin)", ["glycerin", "water"]),
    ])
    func ambiguousInputsListCandidates(input: String, candidateIDs: [String]) {
        let result = normalizer.normalize(input)
        #expect(result.status == .ambiguous(candidateIDs: candidateIDs))
        #expect(result.ingredientID == nil)
        #expect(result.needsReview)
        #expect(result.warning?.input == input)
    }

    @Test func listNormalizationKeepsOrderAndCollectsWarnings() {
        let inputs = ["Water", "Vitamin C", "Unobtainium Extract", "Niacinamide"]
        let results = normalizer.normalize(inputs)

        #expect(results.map(\.originalText) == inputs)
        #expect(results.map(\.ingredientID) == ["water", nil, nil, "niacinamide"])
        #expect(results.warnings.map(\.input) == ["Vitamin C", "Unobtainium Extract"])
    }

    @Test func normalizesAWholeLabel() {
        let label = "Ingredients: Aqua, Glycerine, Retinol (0.3%), Glycolic Acid, Vitamin C, Unobtainium Extract."
        let results = normalizer.normalize(label: label)

        #expect(results.map(\.ingredientID) == ["water", "glycerin", "retinol", "glycolic-acid", nil, nil])
        #expect(results.warnings.map(\.input) == ["Vitamin C", "Unobtainium Extract"])
    }
}
