import Foundation
import Testing
@testable import Aesthelity

struct AnalysisFindingsTests {
    @Test func invalidResponseDoesNotUseIncompleteTitle() {
        let message = APIClientError.invalidResponse.localizedDescription
        #expect(message == "The server returned an unreadable response.")
        #expect(!message.contains(AnalysisResponsePayload.incompleteTitle))
    }

    @Test func supportedFixtureKeepsEvidence() throws {
        let response = try decode(fixture("supported_finding"))
        try AccountDataAPI.validate(
            response, for: request(ids: ["fictional_retinol_serum", "fictional_glycolic_toner"]), catalogVersion: 3
        )
        #expect(response.ruleVersion == "ai-analysis-v1")
        #expect(response.outcome == .known(.findings))
        #expect(!response.hasIncompleteAssessment)
        let finding = try #require(response.findings.first)
        #expect(finding.outcome == .known(.caution))
        #expect(finding.ruleStatus == .known(.aiAssisted))
        #expect(finding.severity == .known(.moderate))
        #expect(finding.ingredientIDs == ["retinol", "glycolic-acid"])
        let evidence = try #require(finding.evidence?.first)
        #expect(evidence.referenceID == "ref.retinol-with-exfoliant")
        #expect(evidence.referenceVersion == 1)
        #expect(evidence.source.publisher == "Aesthelity Fixture")
        #expect(!evidence.claim.isEmpty)
        #expect(!finding.limitations.isEmpty)
    }

    @Test func unknownFixtureDrivesIncompletePresentation() throws {
        let response = try decode(fixture("incomplete_unknown"))
        try AccountDataAPI.validate(response, for: request(ids: ["fictional_partial_serum"]), catalogVersion: 3)
        #expect(response.outcome == .known(.unknown))
        #expect(response.hasIncompleteAssessment)
        #expect(!response.showsNoFindings)
        #expect(response.coverage?.unknownIngredientCount == 1)
        #expect(response.findings.count == 2)
        let gap = try #require(response.findings.first)
        #expect(gap.reasonCode == "normalization-unknown")
        #expect(gap.ingredientLabel == "Mystery Extract")
        #expect(gap.rowIndex == 0)
        #expect(gap.evidence == nil)
        #expect(response.findings.last?.reasonCode == "allergy-status-unknown")
    }

    @Test(arguments: ["complete", "empty findings", "supported finding", "unrecognized finding", "display label", "null label"])
    func malformedUnknownIsRejected(_ variant: String) throws {
        var body = try fixtureObject("incomplete_unknown")
        var findings = try #require(body["findings"] as? [[String: Any]])
        switch variant {
        case "complete": body["completeness"] = "complete"
        case "empty findings": findings = []
        case "supported finding": findings[0]["outcome"] = "caution"
        case "unrecognized finding": findings[0]["outcome"] = "future-risk"
        case "display label": body["displayLabel"] = "No recorded conflicts"
        case "null label": body["displayLabel"] = NSNull()
        default: Issue.record("Unhandled test variant")
        }
        body["findings"] = findings
        let data = try JSONSerialization.data(withJSONObject: body)
        if variant == "null label" {
            #expect(throws: DecodingError.self) { try decode(data) }
        } else {
            let response = try decode(data)
            #expect(throws: APIClientError.invalidResponse) {
                try AccountDataAPI.validate(response, for: request(ids: ["fictional_partial_serum"]), catalogVersion: 3)
            }
        }
    }

    @Test func supportedFindingWithGapRemainsVisible() throws {
        var body = try fixtureObject("supported_finding")
        var findings = try #require(body["findings"] as? [[String: Any]])
        let unknown = try fixtureObject("incomplete_unknown")
        let gaps = try #require(unknown["findings"] as? [[String: Any]])
        var gap = try #require(gaps.first)
        gap["productIDs"] = ["fictional_retinol_serum"]
        findings.append(gap)
        body["findings"] = findings
        body["completeness"] = "incomplete"
        body["coverage"] = unknown["coverage"]
        let response = try decode(JSONSerialization.data(withJSONObject: body))
        try AccountDataAPI.validate(response, for: request(ids: response.productIDs), catalogVersion: 3)
        #expect(response.hasIncompleteAssessment)
        #expect(!response.showsNoFindings)
        #expect(response.findings.first?.evidence?.count == 1)
        #expect(response.findings.last?.outcome == .known(.unknown))
    }

    @Test func futureFindingValuesDecodeAndRoundTripAsUnknown() throws {
        var body = try fixtureObject("supported_finding")
        let findings = try #require(body["findings"] as? [[String: Any]])
        var future = try #require(findings.first)
        future["outcome"] = "future-risk"
        future["severity"] = "critical"
        future["ruleStatus"] = "future-source"
        body["findings"] = [future]
        let response = try decode(JSONSerialization.data(withJSONObject: body))
        try AccountDataAPI.validate(response, for: request(ids: response.productIDs), catalogVersion: 3)
        let saved = try decode(JSONEncoder().encode(response))
        let finding = try #require(saved.findings.first)
        #expect(finding.outcome == .unknown("future-risk"))
        #expect(finding.severity == .unknown("critical"))
        #expect(finding.ruleStatus == .unknown("future-source"))
        #expect(finding.outcomeTitle == "Unknown")
        #expect(!finding.isSupported)
        #expect(finding.evidence?.count == 1)
        #expect(saved.hasIncompleteAssessment)
    }

    @Test(arguments: ["ruleVersion", "activeCatalogVersion"])
    func requiredFieldsRemainRequired(_ field: String) throws {
        var body = try fixtureObject("supported_finding")
        body.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: body)
        #expect(throws: DecodingError.self) { try decode(data) }
    }

    @Test(arguments: ["contractVersion", "activeCatalogVersion", "period", "productIDs", "productOrder", "findingProduct", "futureOutcome"])
    func responseMustAgreeWithRequest(_ field: String) throws {
        var body = try fixtureObject("supported_finding")
        let ids = ["fictional_retinol_serum", "fictional_glycolic_toner"]
        switch field {
        case "contractVersion": body[field] = 2
        case "activeCatalogVersion": body[field] = 2
        case "period": body[field] = "am"
        case "productIDs": body[field] = ["other"]
        case "productOrder": body["productIDs"] = Array(ids.reversed())
        case "findingProduct":
            var findings = try #require(body["findings"] as? [[String: Any]])
            findings[0]["productIDs"] = ["other"]
            body["findings"] = findings
        case "futureOutcome": body["outcome"] = "future-outcome"
        default: Issue.record("Unhandled test variant")
        }
        let response = try decode(JSONSerialization.data(withJSONObject: body))
        #expect(throws: APIClientError.invalidResponse) {
            try AccountDataAPI.validate(response, for: request(ids: ids), catalogVersion: 3)
        }
    }

    @Test func legacyCoverageOnlyResponseStillValidates() throws {
        var body = try fixtureObject("incomplete_unknown")
        body["ruleVersion"] = "AN-02-v1"
        body["outcome"] = "findings"
        body.removeValue(forKey: "coverage")
        var findings = try #require(body["findings"] as? [[String: Any]])
        for index in findings.indices {
            findings[index]["ruleStatus"] = "approved"
            findings[index].removeValue(forKey: "findingID")
            findings[index].removeValue(forKey: "reasonCode")
        }
        body["findings"] = findings
        let response = try decode(JSONSerialization.data(withJSONObject: body))
        try AccountDataAPI.validate(response, for: request(ids: response.productIDs), catalogVersion: 3)
        #expect(response.coverage == nil)
        #expect(response.hasIncompleteAssessment)
        #expect(!response.showsNoFindings)
    }

    @Test func onlyCompleteNoFindingsShowsNoFindingsCopy() throws {
        var body = try fixtureObject("supported_finding")
        body["outcome"] = "noFindings"
        body["findings"] = []
        let complete = try decode(JSONSerialization.data(withJSONObject: body))
        try AccountDataAPI.validate(complete, for: request(ids: complete.productIDs), catalogVersion: 3)
        #expect(complete.showsNoFindings)

        body["completeness"] = "incomplete"
        let incomplete = try decode(JSONSerialization.data(withJSONObject: body))
        #expect(incomplete.hasIncompleteAssessment)
        #expect(!incomplete.showsNoFindings)
        #expect(throws: APIClientError.invalidResponse) {
            try AccountDataAPI.validate(incomplete, for: request(ids: incomplete.productIDs), catalogVersion: 3)
        }
    }

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func fixtureObject(_ name: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: fixture(name)) as? [String: Any])
    }

    private func decode(_ data: Data) throws -> AnalysisResponsePayload {
        try JSONDecoder().decode(AnalysisResponsePayload.self, from: data)
    }

    private func request(ids: [String]) -> AnalysisRequestPayload {
        AnalysisRequestPayload(
            contractVersion: 1, period: "pm",
            recordedAllergies: RecordedAllergiesPayload(status: "unknown", ingredientIDs: nil),
            products: ids.map {
                NormalizedProductIngredients(productID: $0, listStatus: .unavailable, ingredients: [], catalogVersion: 3)
            }
        )
    }
}

private final class FixtureBundleMarker {}
