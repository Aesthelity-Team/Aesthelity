//
//  IngredientNormalizerTests.swift
//  AesthelityTests
//
//  Created by Gaurav Pandey on 10/8/26.
//

import Foundation
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
        ("Glycerol", "glycerin"),
        ("Nicotinamide", "niacinamide"),
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
        ("Water (Vitamin C)", ["ascorbic-acid", "ascorbyl-glucoside", "magnesium-ascorbyl-phosphate", "sodium-ascorbyl-phosphate", "water"]),
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

    @Test func sampleOutputsKeepMatchStatusSeparate() {
        let exact = normalizer.normalize("Glycerin")
        let alias = normalizer.normalize("Glycerol")
        let unknown = normalizer.normalize("Unobtainium Extract")
        let ambiguous = normalizer.normalize("Vitamin C")
        let typo = normalizer.normalize("Niacinimide")

        #expect(exact.status == .matched(ingredientID: "glycerin"))
        #expect(exact.warning == nil)
        #expect(alias.status == .matched(ingredientID: "glycerin"))
        #expect(alias.originalText == "Glycerol")
        #expect(alias.ingredientID == "glycerin")
        #expect(unknown.status == .unmatched)
        #expect(unknown.ingredientID == nil)
        #expect(unknown.needsReview)
        #expect(ambiguous.ingredientID == nil)
        #expect(ambiguous.status == .ambiguous(candidateIDs: [
            "ascorbic-acid", "ascorbyl-glucoside", "magnesium-ascorbyl-phosphate", "sodium-ascorbyl-phosphate"
        ]))
        #expect(typo.status == .uncertain(suggestedID: "niacinamide"))
        #expect(typo.ingredientID == nil)
        #expect(typo.needsReview)
    }

    @Test func conflictingAliasIsAmbiguousInsteadOfTheFirstRecord() throws {
        let data = Data("""
        {"version":1,"ingredients":[
          {"id":"water","name":"Water","aliases":["Aqua"],"classes":["solvent"]},
          {"id":"aqua-extract","name":"Aqua Extract","aliases":["Aqua"],"classes":["extract"]}
        ],"ambiguousTerms":[]}
        """.utf8)
        let decoded = try JSONDecoder().decode(IngredientAliasCatalog.self, from: data)
        let result = IngredientNormalizer(catalog: decoded).normalize("Aqua")

        #expect(result.ingredientID == nil)
        #expect(result.status == .ambiguous(candidateIDs: ["aqua-extract", "water"]))
        #expect(decoded.validationIssues().contains { $0.contains("both water and aqua-extract") })

        do {
            _ = try IngredientAliasCatalog.load(data: data)
            Issue.record("Conflicting reference data should not load")
        } catch let error as IngredientAliasCatalog.LoadError {
            #expect(error.localizedDescription.contains("inconsistent"))
            #expect(error.localizedDescription.contains("Aqua"))
        }
    }

    @Test func unreviewedReferenceCannotBecomeAnApprovedAlias() throws {
        let ingredient = CanonicalIngredient(
            id: "squalene",
            name: "Squalene",
            aliases: ["Spinacene"],
            classes: ["emollient"],
            references: [IngredientReference(
                source: "PubChem",
                url: nil,
                identifier: nil,
                retrievedOn: "2026-10-18",
                datasetVersion: nil,
                reviewStatus: "unreviewed"
            )]
        )
        let catalog = IngredientAliasCatalog(version: 1, ingredients: [ingredient], ambiguousTerms: [])
        #expect(catalog.validationIssues().contains { $0.contains("unreviewed") })
        let data = try JSONEncoder().encode(catalog)
        do {
            _ = try IngredientAliasCatalog.load(data: data)
            Issue.record("Unreviewed reference data should not load")
        } catch is IngredientAliasCatalog.LoadError {
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func invalidCatalogJSONDoesNotLoadAnEmptyDictionary() {
        do {
            _ = try IngredientAliasCatalog.load(data: Data("{}".utf8))
            Issue.record("Invalid JSON should not become a catalog")
        } catch let error as IngredientAliasCatalog.LoadError {
            #expect(error.localizedDescription.contains("ingredient-aliases.json"))
            #expect(error.localizedDescription.contains("not valid catalog JSON"))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func missingReferenceFileNamesTheResource() {
        do {
            _ = try IngredientAliasCatalog.loadBundled(from: Bundle(for: AliasResourceProbe.self))
            Issue.record("The unit-test bundle should not contain the ingredient catalog")
        } catch let error as IngredientAliasCatalog.LoadError {
            #expect(error.localizedDescription.contains("ingredient-aliases.json"))
            #expect(error.localizedDescription.contains("missing"))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func curatedProductLabelsUseTheSameNormalizer() throws {
        let products = try DemoCatalog.load().products
        let occurrences = products.flatMap(\.ingredients)
        let results = normalizer.normalize(occurrences)
        var unique: [String] = []
        var seen = Set<String>()
        for name in occurrences where seen.insert(name).inserted {
            unique.append(name)
        }

        #expect(occurrences.count == 62)
        #expect(unique.count == 18)
        #expect(results.map(\.originalText) == occurrences)
        #expect(results.allSatisfy { if case .matched = $0.status { return true } else { return false } })
        #expect(results.filter { $0.status == .unmatched }.map(\.originalText) == [])

        let expectedIDs = [
            "Cocamidopropyl Betaine": "cocamidopropyl-betaine",
            "Sodium Chloride": "sodium-chloride",
            "Caprylic/Capric Triglyceride": "caprylic-capric-triglyceride",
            "Squalane": "squalane",
            "Polysorbate 80": "polysorbate-80",
            "Cetyl Alcohol": "cetyl-alcohol",
            "Aqua": "water",
            "Glycerol": "glycerin",
            "Nicotinamide": "niacinamide"
        ]
        for (name, id) in expectedIDs {
            #expect(normalizer.normalize(name).status == .matched(ingredientID: id))
        }

        let reviewedIDs = [
            "cocamidopropyl-betaine", "sodium-chloride", "caprylic-capric-triglyceride",
            "squalane", "polysorbate-80", "cetyl-alcohol"
        ]
        for id in reviewedIDs {
            let references = normalizer.ingredient(withID: id)?.references ?? []
            #expect(!references.isEmpty)
            #expect(references.allSatisfy { $0.reviewStatus == "reviewed" && !$0.source.isEmpty && !$0.retrievedOn.isEmpty })
        }

        for product in products where !product.ingredients.isEmpty {
            let label = product.ingredients.joined(separator: ", ")
            let parsed = normalizer.normalize(label: label)
            #expect(parsed.map(\.originalText) == product.ingredients)
            #expect(parsed.map(\.ingredientID) == normalizer.normalize(product.ingredients).map(\.ingredientID))
        }
    }

    @Test func similarIngredientsStayDistinct() {
        let neighbors = [
            "Squalene",
            "Polysorbate 20",
            "Cetearyl Alcohol",
            "Caprylic Triglyceride",
            "Cocamidopropyl Hydroxysultaine",
            "Cetyl Palmitate"
        ]
        for name in neighbors {
            let result = normalizer.normalize(name)
            #expect(result.ingredientID == nil)
            #expect(result.needsReview)
        }
        #expect(normalizer.normalize("Squalene").status == .uncertain(suggestedID: "squalane"))
        #expect(normalizer.normalize("Polysorbate 20").status == .uncertain(suggestedID: "polysorbate-80"))
        #expect(normalizer.normalize("Cetearyl Alcohol").status == .unmatched)
        #expect(normalizer.normalize("Sodium Hyaluronate").status == .matched(ingredientID: "sodium-hyaluronate"))
        #expect(normalizer.normalize("Hyaluronic Acid").status == .matched(ingredientID: "hyaluronic-acid"))
        #expect(normalizer.normalize("1-Hexadecanol").status == .matched(ingredientID: "cetyl-alcohol"))
        #expect(normalizer.normalize("Perhydrosqualene").status == .matched(ingredientID: "squalane"))
    }
}

private final class AliasResourceProbe {}
