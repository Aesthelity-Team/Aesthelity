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
            sourceType: "manual"
        )
        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["contractVersion"] as? Int == 1)
        #expect(object["ai"] as? Bool == true)
        #expect(object["persist"] as? Bool == true)
        #expect(object["productID"] as? String == "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
        #expect(object["sourceType"] as? String == "manual")
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
