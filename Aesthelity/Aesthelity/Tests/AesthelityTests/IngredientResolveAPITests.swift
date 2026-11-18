import Foundation
import Testing
@testable import Aesthelity

struct IngredientResolveAPITests {
    @Test func persistRequestBodyIncludesProductIdAndPersistFlag() throws {
        let request = IngredientResolveRequest(
            ingredients: ["Water", "Niacinimide"],
            ai: true,
            productID: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            persist: true,
            sourceType: "manual",
            format: "analysis-input",
            listStatus: "complete"
        )
        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["contractVersion"] as? Int == 1)
        #expect(object["ai"] as? Bool == true)
        #expect(object["persist"] as? Bool == true)
        #expect(object["productID"] as? String == "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
        #expect(object["sourceType"] as? String == "manual")
        #expect(object["format"] as? String == "analysis-input")
        #expect(object["listStatus"] as? String == "complete")
        #expect(object["ingredients"] as? [String] == ["Water", "Niacinimide"])
    }

    @Test func mapsConfirmedTentativeUnknownAndCoverageAlignedRows() throws {
        let payload = """
        {
          "contractVersion": 1,
          "status": "ok",
          "coverage": "partial",
          "ingredients": [
            {
              "index": 0,
              "originalText": "Aqua",
              "status": "identified",
              "mapping": "confirmed",
              "ingredientID": "water",
              "suggestedID": null,
              "candidateIDs": [],
              "normalizedName": "Water",
              "bestGuess": null,
              "explanation": "approved",
              "canonicalName": "Water"
            },
            {
              "index": 1,
              "originalText": "isobutyl mystery",
              "status": "tentative",
              "mapping": "uncertain",
              "ingredientID": null,
              "suggestedID": "4-isobutylresorcinol",
              "candidateIDs": [],
              "normalizedName": null,
              "bestGuess": "4-ISOBUTYLRESORCINOL",
              "explanation": "reference only",
              "canonicalName": "4-ISOBUTYLRESORCINOL"
            },
            {
              "index": 2,
              "originalText": "maybe niacinamide?",
              "status": "tentative",
              "mapping": "uncertain",
              "ingredientID": null,
              "suggestedID": null,
              "candidateIDs": [],
              "normalizedName": null,
              "bestGuess": "Niacinamide",
              "explanation": "uncertain OCR",
              "canonicalName": null
            },
            {
              "index": 3,
              "originalText": "blurred txt",
              "status": "unknown",
              "mapping": "unmatched",
              "ingredientID": null,
              "suggestedID": null,
              "candidateIDs": [],
              "normalizedName": null,
              "bestGuess": null,
              "explanation": "gibberish",
              "reason": "gibberish",
              "canonicalName": null
            }
          ]
        }
        """
        let response = try JSONDecoder().decode(IngredientResolveResponse.self, from: Data(payload.utf8))
        #expect(response.coverage == "partial")
        let rows = response.ingredients.map { $0.asNormalizedIngredient() }
        #expect(rows[0].status == .matched(ingredientID: "water"))
        #expect(rows[0].warning == nil)
        #expect(rows[1].status == .uncertain(suggestedID: "4-isobutylresorcinol"))
        #expect(rows[1].warning?.message.contains("Best guess") == true)
        #expect(rows[2].status == .unmatched)
        #expect(rows[2].warning?.message.contains("Niacinamide") == true)
        #expect(rows[3].status == .unmatched)
        #expect(rows[3].warning?.message.contains("gibberish") == true)
    }

    @Test func failedResolvePayloadStillDecodesFullList() throws {
        let payload = """
        {
          "contractVersion": 1,
          "status": "failed",
          "failureCode": "provider_unavailable",
          "coverage": "unknown",
          "ingredients": [
            {
              "index": 0,
              "originalText": "Aqua",
              "status": "unknown",
              "mapping": "unmatched",
              "reason": "ai-unavailable",
              "explanation": "ai-unavailable"
            }
          ]
        }
        """
        let response = try JSONDecoder().decode(IngredientResolveResponse.self, from: Data(payload.utf8))
        #expect(response.status == "failed")
        #expect(response.failureCode == "provider_unavailable")
        #expect(response.coverage == "unknown")
        #expect(response.ingredients[0].asNormalizedIngredient().status == .unmatched)
    }
}

@MainActor
struct ManualProductSavingTests {
    private struct WriteFailure: Error {}

    private func product() -> ManualProduct {
        ManualProduct(name: "My serum", brand: "My brand", category: .serum,
            rawIngredientList: "Aqua, mystery",
            ingredients: [
                NormalizedIngredient(originalText: "Aqua", status: .matched(ingredientID: "water"), warning: nil),
                NormalizedIngredient(originalText: "mystery", status: .matched(ingredientID: "retinol"), warning: nil)
            ])
    }

    private func row(_ index: Int, _ text: String, mapping: String = "unmatched", id: String? = nil) -> IngredientResolveRow {
        IngredientResolveRow(index: index, originalText: text, status: mapping == "confirmed" ? "identified" : "unknown",
            mapping: mapping, ingredientID: id, suggestedID: nil, candidateIDs: [], normalizedName: nil,
            bestGuess: nil, explanation: "Latest Save result", reason: nil, canonicalName: nil)
    }

    private func response(_ product: ManualProduct, rows: [IngredientResolveRow]? = nil,
                          coverage: String = "partial", status: String = "ok",
                          path: String? = "correct", version: Int = 1) -> IngredientResolveResponse {
        IngredientResolveResponse(contractVersion: version, status: status, coverage: coverage,
            failureCode: status == "failed" ? "provider_unavailable" : nil, providerStatus: nil,
            ingredients: rows ?? [row(1, "mystery"), row(0, "Aqua", mapping: "confirmed", id: "water")],
            persisted: path.map { .init(productPath: $0 == "correct" ? "productIngredients/\(product.id.uuidString)" : $0) })
    }

    @Test func savesAndReloadsLatestCloudRowsPreservingProductIdentityAndLabel() async throws {
        let reviewed = product()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("products.json")
        let store = ManualProductStore(fileURL: file)
        var calls = 0
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: {
            calls += 1
            return response(reviewed)
        }, writeLocal: { try store.save($0) })
        let saved = try #require(ManualProductStore(fileURL: file).products.first)
        #expect(calls == 1)
        #expect(saved == result.product)
        #expect(saved.id == reviewed.id)
        #expect(saved.name == reviewed.name && saved.brand == reviewed.brand)
        #expect(saved.category == reviewed.category && saved.source == reviewed.source)
        #expect(saved.rawIngredientList == reviewed.rawIngredientList && saved.schemaVersion == reviewed.schemaVersion)
        #expect(saved.ingredients.map(\.originalText) == ["Aqua", "mystery"])
        #expect(saved.ingredients[1].mapping == .unmatched)
        #expect(result.coverage == "partial")
        #expect(result.note?.contains("Matching changed") == true)
        #expect(result.error == nil && !result.shouldDismiss)
    }

    @Test func unchangedSuccessfulSaveDismisses() async {
        let reviewed = product()
        let payload = response(reviewed, rows: [row(0, "Aqua", mapping: "confirmed", id: "water"),
                                              row(1, "mystery", mapping: "confirmed", id: "retinol")], coverage: "complete")
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: { payload }, writeLocal: { stored = $0 })
        #expect(stored == reviewed)
        #expect(result.shouldDismiss)
    }

    @Test func tentativeSaveWithoutCatalogIDRemainsUnresolved() async {
        let reviewed = product()
        let tentative = IngredientResolveRow(index: 1, originalText: "mystery", status: "tentative",
            mapping: "uncertain", ingredientID: nil, suggestedID: nil, candidateIDs: [], normalizedName: nil,
            bestGuess: "Retinol", explanation: "Not confirmed", reason: nil, canonicalName: nil)
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: {
            response(reviewed, rows: [row(0, "Aqua", mapping: "confirmed", id: "water"), tentative])
        }, writeLocal: { stored = $0 })
        #expect(stored?.ingredients[1].ingredientID == nil)
        #expect(stored?.ingredients[1].warning?.message.contains("Best guess: Retinol") == true)
        #expect(result.coverage == "partial" && result.error == nil)
        #expect(result.note?.contains("latest saved matches") == true)
    }

    @Test func duplicateLabelEntriesRemainSeparateAndOrdered() async {
        var reviewed = product()
        reviewed.ingredients = [reviewed.ingredients[0], reviewed.ingredients[0]]
        reviewed.rawIngredientList = "Aqua, Aqua"
        let payload = response(reviewed, rows: [row(1, "Aqua"), row(0, "Aqua", mapping: "confirmed", id: "water")])
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: { payload }, writeLocal: { stored = $0 })
        #expect(stored?.ingredients.count == 2)
        #expect(stored?.ingredients[0].mapping == .confirmed && stored?.ingredients[1].mapping == .unmatched)
        #expect(stored?.rawIngredientList == "Aqua, Aqua" && result.coverage == "partial")
    }

    @Test func failedCloudRequestSavesReviewedCopyAndOffersRetry() async {
        let reviewed = product()
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: {
            throw URLError(.notConnectedToInternet)
        }, writeLocal: { stored = $0 })
        #expect(stored == reviewed && result.product == reviewed)
        #expect(result.coverage == "complete")
        #expect(result.note?.contains("Cloud save could not be confirmed") == true)
        #expect(result.error == nil && !result.shouldDismiss)
    }

    @Test func failedMatchingWithoutPersistenceReceiptKeepsReviewedCopy() async {
        let reviewed = product()
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: {
            response(reviewed, rows: [row(1, "mystery"), row(0, "Aqua")],
                     coverage: "unknown", status: "failed", path: nil)
        }, writeLocal: { stored = $0 })
        #expect(stored == reviewed)
        #expect(result.coverage == "complete")
        #expect(result.note != nil && !result.shouldDismiss)
    }

    @Test func failedMatchingWithValidReceiptSavesAndReloadsPersistedUnresolvedRows() async throws {
        let reviewed = product()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("products.json")
        let store = ManualProductStore(fileURL: file)
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: {
            response(reviewed, rows: [row(1, "mystery"), row(0, "Aqua")],
                     coverage: "unknown", status: "failed")
        }, writeLocal: { try store.save($0) })
        let saved = try #require(ManualProductStore(fileURL: file).products.first)
        #expect(saved == result.product)
        #expect(saved.id == reviewed.id && saved.rawIngredientList == reviewed.rawIngredientList)
        #expect(saved.name == reviewed.name && saved.brand == reviewed.brand && saved.category == reviewed.category)
        #expect(saved.ingredients.map(\.originalText) == ["Aqua", "mystery"])
        #expect(saved.ingredients.allSatisfy { $0.mapping == .unmatched && $0.ingredientID == nil })
        #expect(result.coverage == "unknown")
        #expect(result.note?.contains("Ingredient matching failed") == true)
        #expect(result.note?.contains("on this device and to the cloud") == true)
        #expect(result.note?.contains("could not be confirmed") == false)
        #expect(result.error == nil && !result.shouldDismiss)
    }

    @Test(arguments: ["wrong-receipt", "missing-row", "wrong-text", "wrong-coverage", "confirmed-row"])
    func failedMatchingStillRequiresValidPersistenceAndUnresolvedRows(_ problem: String) async {
        let reviewed = product()
        var rows = [row(0, "Aqua"), row(1, "mystery")]
        switch problem {
        case "missing-row": rows.removeLast()
        case "wrong-text": rows[0] = row(0, "Changed")
        case "confirmed-row": rows[0] = row(0, "Aqua", mapping: "confirmed", id: "water")
        default: break
        }
        let payload = response(reviewed, rows: rows,
            coverage: problem == "wrong-coverage" ? "complete" : (problem == "confirmed-row" ? "partial" : "unknown"),
            status: "failed", path: problem == "wrong-receipt" ? "productIngredients/other" : "correct")
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: { payload }, writeLocal: { stored = $0 })
        #expect(stored == reviewed && result.coverage == "complete")
        #expect(result.note?.contains("Cloud save could not be confirmed") == true)
    }

    @Test func deviceFailureAfterPersistedMatchingFailureRetainsUnresolvedRowsForRetry() async {
        let reviewed = product()
        let payload = response(reviewed, rows: [row(0, "Aqua"), row(1, "mystery")],
                               coverage: "unknown", status: "failed")
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: { payload },
                                                    writeLocal: { _ in throw WriteFailure() })
        #expect(result.product.ingredients.allSatisfy { $0.mapping == .unmatched })
        #expect(result.coverage == "unknown")
        #expect(result.error?.contains("Ingredient matching failed") == true)
        #expect(result.error?.contains("saved to the cloud") == true && !result.shouldDismiss)
        var retried: ManualProduct?
        let retry = await ManualProductSaving.save(result.product, coverage: result.coverage,
            persist: { payload }, writeLocal: { retried = $0 })
        #expect(retried == result.product && retry.coverage == "unknown")
        #expect(retry.note?.contains("Ingredient matching failed") == true && !retry.shouldDismiss)
    }

    @Test(arguments: ["missing-row", "duplicate-index", "negative-index", "wrong-text", "wrong-path",
                      "no-receipt", "bad-coverage", "bad-version", "bad-mapping", "bad-confirmed-id"])
    func invalidSaveResponseNeverReplacesReviewedCopy(_ problem: String) async {
        let reviewed = product()
        var rows = [row(0, "Aqua", mapping: "confirmed", id: "water"), row(1, "mystery")]
        switch problem {
        case "missing-row": rows.removeLast()
        case "duplicate-index": rows[1] = row(0, "mystery")
        case "negative-index": rows[0] = row(-1, "Aqua", mapping: "confirmed", id: "water")
        case "wrong-text": rows[1] = row(1, "different label")
        case "bad-mapping": rows[1] = row(1, "mystery", mapping: "safe")
        case "bad-confirmed-id": rows[0] = row(0, "Aqua", mapping: "confirmed", id: "INVALID ID")
        default: break
        }
        let payload = response(reviewed, rows: rows, coverage: problem == "bad-coverage" ? "complete" : "partial",
            path: problem == "no-receipt" ? nil : (problem == "wrong-path" ? "productIngredients/another" : "correct"),
            version: problem == "bad-version" ? 2 : 1)
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: { payload }, writeLocal: { stored = $0 })
        #expect(stored == reviewed && result.coverage == "complete")
        #expect(result.note != nil && !result.shouldDismiss)
    }

    @Test func localWriteFailureAfterCloudSuccessRetainsLatestRowsForRetry() async {
        let reviewed = product()
        var attempted: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: { response(reviewed) }, writeLocal: {
            attempted = $0
            throw WriteFailure()
        })
        #expect(attempted == result.product)
        #expect(result.product.ingredients[1].mapping == .unmatched && result.coverage == "partial")
        #expect(result.error?.contains("saved to the cloud") == true)
        #expect(!result.shouldDismiss)
        var retried: ManualProduct?
        let retry = await ManualProductSaving.save(result.product, coverage: result.coverage,
            persist: { response(reviewed) }, writeLocal: { retried = $0 })
        #expect(retried == result.product && retry.shouldDismiss)
    }

    @Test func signedOutSaveUsesOnlyDeviceStorage() async {
        let reviewed = product()
        var stored: ManualProduct?
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: nil, writeLocal: { stored = $0 })
        #expect(stored == reviewed && result.shouldDismiss)
    }

    @Test func failedDeviceWriteKeepsEntriesAndReportsFailure() async {
        let reviewed = product()
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: nil, writeLocal: { _ in throw WriteFailure() })
        #expect(result.product == reviewed && result.coverage == "complete")
        #expect(result.error?.contains("could not be saved on this device") == true)
        #expect(!result.shouldDismiss)
    }

    @Test func cancelledCloudSaveDoesNotWriteLocalCopyOrDismiss() async {
        let reviewed = product()
        var wrote = false
        let result = await ManualProductSaving.save(reviewed, coverage: "complete", persist: {
            throw CancellationError()
        }, writeLocal: { _ in wrote = true })
        #expect(!wrote && result.product == reviewed)
        #expect(result.error?.contains("cancelled") == true && !result.shouldDismiss)
    }
}
