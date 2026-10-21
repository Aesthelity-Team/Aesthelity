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

    @Test func vitaminB3IsNotAConfirmedNiacinamideAlias() {
        let result = normalizer.normalize("Vitamin B3")
        #expect(result.ingredientID == nil)
        #expect(result.needsReview)
        #expect(result.mapping != .confirmed)
        #expect(result.suggestedID != "niacinamide")
        #expect(!result.candidateIDs.contains("niacinamide"))
    }

    @Test func aliasFormsStayDistinctRowsWithTheSameConfirmedID() {
        let product = normalizer.normalizeStoredProduct(
            id: "pd03-alias-pair",
            ingredientTexts: ["Nicotinamide", "Niacinamide"],
            listStatus: .complete
        )
        #expect(product.productID == "pd03-alias-pair")
        #expect(product.catalogVersion == catalog.version)
        #expect(product.ingredients.map(\.originalText) == ["Nicotinamide", "Niacinamide"])
        #expect(product.confirmedIngredientIDs(using: normalizer) == ["niacinamide", "niacinamide"])
        #expect(product.isFullyResolved(using: normalizer))
        #expect(!product.analysisInput(using: normalizer).uncertaintyPreserved)
    }

    @Test func productExampleMatchesTheNormalizerAndRoundTrips() throws {
        let fixture = try PD03ProductExample.load()
        #expect(fixture.schemaVersion == 1)
        #expect(fixture.contractStatus == "proposed")
        #expect(fixture.productID == "pd03-example-serum")
        #expect(fixture.displayName == "PD-03 Example Serum (Fictional)")

        let product = normalizer.normalizeStoredProduct(
            id: fixture.productID,
            ingredientTexts: fixture.ingredients,
            listStatus: fixture.listStatus
        )
        #expect(product.productID == fixture.productID)
        #expect(product.catalogVersion == catalog.version)
        #expect(product.listStatus == .complete)
        #expect(product.ingredients.map(\.originalText) == fixture.ingredients)
        #expect(product.ingredients.map(\.status) == fixture.expected.map(\.status))
        #expect(product.confirmedIngredientIDs(using: normalizer) == ["niacinamide"])
        #expect(product.ingredients[0].warning == nil)
        #expect(product.ingredients[1].ingredientID == nil)
        #expect(product.ingredients[1].candidateIDs == [
            "ascorbic-acid", "ascorbyl-glucoside", "magnesium-ascorbyl-phosphate", "sodium-ascorbyl-phosphate"
        ])
        #expect(product.ingredients[2].status == .unmatched)
        #expect(product.ingredients[2].ingredientID == nil)
        #expect(product.ingredients.dropFirst().allSatisfy { $0.warning?.input == $0.originalText })
        #expect(!product.isFullyResolved(using: normalizer))

        let analysis = product.analysisInput(using: normalizer)
        #expect(analysis.confirmedIDs == ["niacinamide"])
        #expect(analysis.uncertaintyPreserved)
        #expect(analysis.listStatus == .complete)

        let data = try JSONEncoder().encode(product)
        let restored = try JSONDecoder().decode(NormalizedProductIngredients.self, from: data)
        #expect(restored == product)

        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["catalogVersion"] as? Int == catalog.version)
        #expect(object["uncertaintyPreserved"] == nil)
        #expect(object["isFullyResolved"] == nil)
        let rows = try #require(object["ingredients"] as? [[String: Any]])
        #expect(rows[0]["mapping"] as? String == "confirmed")
        #expect(rows[0]["ingredientID"] as? String == "niacinamide")
        #expect(rows[0]["suggestedID"] == nil)
        #expect(rows[0]["status"] == nil)
        #expect(rows[1]["mapping"] as? String == "ambiguous")
        #expect(rows[1]["ingredientID"] == nil)
        #expect(rows[1]["suggestedID"] == nil)
        #expect(rows[2]["mapping"] as? String == "unmatched")
        #expect(rows[2]["ingredientID"] == nil)
        #expect(rows[2]["candidateIDs"] == nil)
    }

    @Test func suggestionsCannotDecodeAsConfirmedIDs() {
        let payloads = [
            #"{"originalText":"Niacinimide","mapping":"uncertain","suggestedID":"niacinamide","ingredientID":"niacinamide"}"#,
            #"{"originalText":"Vitamin C","mapping":"ambiguous","candidateIDs":["ascorbic-acid"],"ingredientID":"ascorbic-acid"}"#,
            #"{"originalText":"Nope","mapping":"unmatched","ingredientID":"water"}"#,
            #"{"originalText":"Water","mapping":"confirmed"}"#,
        ]
        for payload in payloads {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(NormalizedIngredient.self, from: Data(payload.utf8))
            }
        }
    }

    @Test func legacyStatusEncodingStillDecodesWithoutConfirmingSuggestions() throws {
        let payload = """
        {"originalText":"Niacinimide","status":{"uncertain":{"suggestedID":"niacinamide"}},"warning":{"input":"Niacinimide","message":"review"}}
        """
        let ingredient = try JSONDecoder().decode(NormalizedIngredient.self, from: Data(payload.utf8))
        #expect(ingredient.status == .uncertain(suggestedID: "niacinamide"))
        #expect(ingredient.ingredientID == nil)
        #expect(ingredient.suggestedID == "niacinamide")
        #expect(ingredient.needsReview)
    }

    @Test func listStatusStaysSeparateFromRowMatches() throws {
        let catalog = try DemoCatalog.load()
        let serum = try #require(catalog.product(id: "serum_niacinamide"))
        let partial = try #require(catalog.product(id: "mask_partial"))
        let unavailable = try #require(catalog.product(id: "sunscreen_unknown"))

        let mappedSerum = normalizer.normalizeCatalogProduct(serum)
        #expect(mappedSerum.productID == "serum_niacinamide")
        #expect(mappedSerum.catalogVersion == self.catalog.version)
        #expect(mappedSerum.ingredients.map(\.originalText) == serum.ingredients)
        #expect(mappedSerum.confirmedIngredientIDs(using: normalizer) == ["water", "niacinamide", "glycerin", "phenoxyethanol"])
        #expect(mappedSerum.isFullyResolved(using: normalizer))
        #expect(!mappedSerum.analysisInput(using: normalizer).uncertaintyPreserved)

        let mappedPartial = normalizer.normalizeCatalogProduct(partial)
        #expect(mappedPartial.listStatus == .partial)
        #expect(mappedPartial.ingredients.map(\.originalText) == ["Water", "Glycerin"])
        #expect(mappedPartial.confirmedIngredientIDs(using: normalizer) == ["water", "glycerin"])
        #expect(mappedPartial.listStatusAgreesWithRowCount)
        #expect(!mappedPartial.isFullyResolved(using: normalizer))
        #expect(mappedPartial.analysisInput(using: normalizer).uncertaintyPreserved)

        let mappedUnavailable = normalizer.normalizeCatalogProduct(unavailable)
        #expect(mappedUnavailable.listStatus == .unavailable)
        #expect(mappedUnavailable.ingredients.isEmpty)
        #expect(mappedUnavailable.confirmedIngredientIDs(using: normalizer).isEmpty)
        #expect(mappedUnavailable.analysisInput(using: normalizer).uncertaintyPreserved)
        #expect(!mappedUnavailable.isFullyResolved(using: normalizer))

        let contradictory = normalizer.normalizeStoredProduct(
            id: "missing-list",
            ingredientTexts: ["Nicotinamide"],
            listStatus: .unavailable
        )
        #expect(contradictory.ingredients.map(\.originalText) == ["Nicotinamide"])
        #expect(contradictory.ingredients.map(\.ingredientID) == ["niacinamide"])
        #expect(!contradictory.listStatusAgreesWithRowCount)
        #expect(contradictory.analysisInput(using: normalizer).uncertaintyPreserved)
        #expect(!contradictory.isFullyResolved(using: normalizer))

        let emptyComplete = normalizer.normalizeStoredProduct(id: "empty", ingredientTexts: [], listStatus: .complete)
        #expect(emptyComplete.ingredients.isEmpty)
        #expect(!emptyComplete.listStatusAgreesWithRowCount)
        #expect(!emptyComplete.isFullyResolved(using: normalizer))
        #expect(emptyComplete.analysisInput(using: normalizer).uncertaintyPreserved)
    }

    @Test(arguments: ["", "   ", " water ", "Niacinamide", "ascorbic acid", "-water", "water-", "water--test"])
    func confirmedIngredientIDMustBeACanonicalSlug(_ id: String) {
        #expect(throws: DecodingError.self) {
            try self.decodeIngredient(
                #"{"originalText":"Water","mapping":"confirmed","ingredientID":"\#(id)"}"#
            )
        }
    }

    @Test func malformedSuggestionAndCandidateIDsAreRejected() {
        let payloads = [
            #"{"originalText":"Niacinimide","mapping":"uncertain","suggestedID":" Niacinamide "}"#,
            #"{"originalText":"Niacinimide","mapping":"uncertain","suggestedID":""}"#,
            #"{"originalText":"Vitamin C","mapping":"ambiguous","candidateIDs":["ascorbic-acid","Ascorbic Acid"]}"#,
            #"{"originalText":"Vitamin C","mapping":"ambiguous","candidateIDs":["ascorbic-acid"]}"#,
            #"{"originalText":"Vitamin C","mapping":"ambiguous","candidateIDs":["ascorbic-acid","ascorbic-acid"]}"#,
            #"{"originalText":"Vitamin C","mapping":"ambiguous","candidateIDs":[]}"#,
        ]
        for payload in payloads {
            #expect(throws: DecodingError.self) {
                try self.decodeIngredient(payload)
            }
        }
    }

    @Test func contradictoryMappingFieldsCannotConfirmAnIngredient() {
        let payloads = [
            #"{"originalText":"Water","mapping":"confirmed","ingredientID":"water","suggestedID":"niacinamide"}"#,
            #"{"originalText":"Water","mapping":"confirmed","ingredientID":"water","candidateIDs":["water","glycerin"]}"#,
            #"{"originalText":"Water","mapping":"uncertain","suggestedID":"water","ingredientID":"water"}"#,
            #"{"originalText":"Niacinimide","mapping":"uncertain","suggestedID":"niacinamide","candidateIDs":["water","glycerin"]}"#,
            #"{"originalText":"Nope","mapping":"unmatched","suggestedID":"water"}"#,
            #"{"originalText":"Water","mapping":"confirmed","ingredientID":"water","status":{"unmatched":{}}}"#,
            #"{"originalText":"Water","mapping":"unmatched","status":{"matched":{"ingredientID":"water"}}}"#,
        ]
        for payload in payloads {
            #expect(throws: DecodingError.self) {
                try self.decodeIngredient(payload)
            }
        }
    }

    @Test func legacyStatusesRemainReadableWhenTheirIDsAreValid() throws {
        let confirmed = try decodeIngredient(
            #"{"originalText":" Water ","status":{"matched":{"ingredientID":"water"}}}"#
        )
        #expect(confirmed.originalText == " Water ")
        #expect(confirmed.status == .matched(ingredientID: "water"))

        let uncertain = try decodeIngredient(
            #"{"originalText":"Niacinimide","status":{"uncertain":{"suggestedID":"niacinamide"}}}"#
        )
        #expect(uncertain.ingredientID == nil)
        #expect(uncertain.suggestedID == "niacinamide")
        #expect(uncertain.needsReview)

        let ambiguous = try decodeIngredient(
            #"{"originalText":"Vitamin C","status":{"ambiguous":{"candidateIDs":["ascorbic-acid","ascorbyl-glucoside"]}}}"#
        )
        #expect(ambiguous.ingredientID == nil)
        #expect(ambiguous.candidateIDs == ["ascorbic-acid", "ascorbyl-glucoside"])

        let unmatched = try decodeIngredient(#"{"originalText":"Nope","status":{"unmatched":{}}}"#)
        #expect(unmatched.status == .unmatched)
        #expect(unmatched.ingredientID == nil)

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(confirmed)) as? [String: Any]
        #expect(encoded?["mapping"] as? String == "confirmed")
        #expect(encoded?["status"] == nil)
        #expect(encoded?["originalText"] as? String == " Water ")
    }

    @Test(arguments: ["", "   ", "Water", "water--x"])
    func legacyMatchedIDsCannotBypassSlugValidation(_ id: String) {
        #expect(throws: DecodingError.self) {
            try self.decodeIngredient(
                #"{"originalText":"Water","status":{"matched":{"ingredientID":"\#(id)"}}}"#
            )
        }
    }

    @Test func legacySuggestionsAndCandidatesUseTheSameRules() {
        let payloads = [
            #"{"originalText":"Niacinimide","status":{"uncertain":{"suggestedID":"Niacinamide"}}}"#,
            #"{"originalText":"Vitamin C","status":{"ambiguous":{"candidateIDs":["ascorbic-acid"]}}}"#,
            #"{"originalText":"Vitamin C","status":{"ambiguous":{"candidateIDs":["ascorbic-acid","ascorbic-acid"]}}}"#,
            #"{"originalText":"Nope","status":{"ambiguous":{"candidateIDs":[" water ","glycerin"]}}}"#,
        ]
        for payload in payloads {
            #expect(throws: DecodingError.self) {
                try self.decodeIngredient(payload)
            }
        }
    }

    @Test func reviewCasesDoNotBecomeFullyResolvedAnalysisInput() throws {
        let whitespace = """
        {"productID":"test","listStatus":"complete","ingredients":[
          {"originalText":"Water","mapping":"confirmed","ingredientID":"   "}
        ]}
        """
        let legacyEmpty = """
        {"productID":"test","listStatus":"complete","ingredients":[
          {"originalText":"Water","status":{"matched":{"ingredientID":""}}}
        ]}
        """
        for payload in [whitespace, legacyEmpty] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(NormalizedProductIngredients.self, from: Data(payload.utf8))
            }
        }

        let unknown = """
        {"productID":"test","listStatus":"complete","catalogVersion":\(catalog.version),"uncertaintyPreserved":false,"isFullyResolved":true,"ingredients":[
          {"originalText":"Water","mapping":"confirmed","ingredientID":"nonexistent-id"}
        ]}
        """
        let stored = try JSONDecoder().decode(NormalizedProductIngredients.self, from: Data(unknown.utf8))
        let analysis = stored.analysisInput(using: normalizer)
        #expect(stored.ingredients.map(\.originalText) == ["Water"])
        #expect(stored.ingredients.map(\.ingredientID) == ["nonexistent-id"])
        #expect(analysis.confirmedIDs.isEmpty)
        #expect(analysis.uncertaintyPreserved)
        #expect(!stored.isFullyResolved(using: normalizer))

        let substituted = """
        {"productID":"mismatch","listStatus":"complete","catalogVersion":\(catalog.version),"ingredients":[
          {"originalText":"Nicotinamide","mapping":"confirmed","ingredientID":"water"}
        ]}
        """
        let kept = try JSONDecoder().decode(NormalizedProductIngredients.self, from: Data(substituted.utf8))
        #expect(kept.ingredients.map(\.originalText) == ["Nicotinamide"])
        #expect(kept.confirmedIngredientIDs(using: normalizer) == ["water"])
        #expect(kept.isFullyResolved(using: normalizer))
    }

    @Test func knownStoredIDIsAnalysisReadyOnlyWhenItBelongsToTheActiveCatalog() throws {
        let payload = """
        {"productID":"known","listStatus":"complete","catalogVersion":\(catalog.version),"ingredients":[
          {"originalText":" Water ","mapping":"confirmed","ingredientID":"water"},
          {"originalText":"Niacinamide","mapping":"confirmed","ingredientID":"niacinamide"}
        ]}
        """
        let stored = try JSONDecoder().decode(NormalizedProductIngredients.self, from: Data(payload.utf8))
        let analysis = stored.analysisInput(using: normalizer)
        #expect(stored.ingredients.map(\.originalText) == [" Water ", "Niacinamide"])
        #expect(analysis.confirmedIDs == ["water", "niacinamide"])
        #expect(stored.isFullyResolved(using: normalizer))
        #expect(!analysis.uncertaintyPreserved)
    }

    @Test func missingAndStaleCatalogVersionsStayUnverifiedUntilRenormalized() throws {
        let missingVersion = """
        {"productID":"historical","listStatus":"complete","ingredients":[
          {"originalText":"Water","mapping":"confirmed","ingredientID":"water"}
        ]}
        """
        let historical = try JSONDecoder().decode(NormalizedProductIngredients.self, from: Data(missingVersion.utf8))
        #expect(historical.catalogVersion == nil)
        #expect(historical.confirmedIngredientIDs(using: normalizer) == ["water"])
        #expect(!historical.isFullyResolved(using: normalizer))
        #expect(historical.analysisInput(using: normalizer).uncertaintyPreserved)
        let rewritten = try JSONDecoder().decode(
            NormalizedProductIngredients.self,
            from: JSONEncoder().encode(historical)
        )
        #expect(rewritten.catalogVersion == nil)

        let staleVersion = catalog.version + 1
        let stale = """
        {"productID":"stale","listStatus":"complete","catalogVersion":\(staleVersion),"ingredients":[
          {"originalText":"Water","mapping":"confirmed","ingredientID":"water"}
        ]}
        """
        let stored = try JSONDecoder().decode(NormalizedProductIngredients.self, from: Data(stale.utf8))
        #expect(stored.catalogVersion == staleVersion)
        #expect(stored.confirmedIngredientIDs(using: normalizer) == ["water"])
        #expect(!stored.isFullyResolved(using: normalizer))
        #expect(stored.analysisInput(using: normalizer).uncertaintyPreserved)

        let refreshed = normalizer.normalizeStoredProduct(
            id: stored.productID,
            ingredientTexts: stored.ingredients.map(\.originalText),
            listStatus: stored.listStatus
        )
        #expect(refreshed.catalogVersion == catalog.version)
        #expect(refreshed.ingredients.map(\.originalText) == ["Water"])
        #expect(refreshed.confirmedIngredientIDs(using: normalizer) == ["water"])
        #expect(refreshed.isFullyResolved(using: normalizer))
    }

    private func decodeIngredient(_ payload: String) throws -> NormalizedIngredient {
        try JSONDecoder().decode(NormalizedIngredient.self, from: Data(payload.utf8))
    }
}

private final class AliasResourceProbe {}
