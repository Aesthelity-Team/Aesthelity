import Foundation

// Maps DATA-01 sample scenarios into what the analysis screen shows. These are fixed demo
// scenarios, not an analysis of the user's routine or profile.

enum DemoFindingStatus: Equatable {
    case caution, allergen, unknown

    init(_ kind: DemoFindingKind) {
        switch kind {
        case .caution: self = .caution
        case .allergen: self = .allergen
        case .unknown: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .caution: return "Caution"
        case .allergen: return "Caution · Sample allergy"
        case .unknown: return "Unknown · Incomplete data"
        }
    }

    var isDefinitive: Bool { self != .unknown }
}

struct DemoFindingPresentation: Equatable {
    static let missingIngredientText = "Not specified in this sample finding"

    let status: DemoFindingStatus
    let category: String
    let productNames: [String]
    let ingredient: String?
    let explanation: String
    let reason: String
    let limitation: String?

    var ingredientText: String { ingredient ?? Self.missingIngredientText }
}

enum DemoAnalysisState: Equatable {
    case normal(productNames: [String])
    case findings([DemoFindingPresentation])
    case unavailable(String)
}

struct DemoAnalysisSample: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let state: DemoAnalysisState
}

enum DemoAnalysis {
    static let loadFailedMessage = "The sample data couldn't be loaded, so no result is shown."
    static let missingReferenceMessage = "This sample refers to demo data that is missing, so no result is shown."
    static let unknownLimitation = "Ingredient data is incomplete, so no definitive conclusion can be made. Don't treat this as a safe result."

    static let scenarioChoices: [(scenarioID: String, title: String)] = [
        ("normal_am", "Normal"),
        ("caution_pm", "Caution"),
        ("allergen_mist", "Allergy"),
        ("unknown_sunscreen", "Unknown")
    ]

    static let bundledSamples: [DemoAnalysisSample] = samples(from: Result { try DemoCatalog.load() })

    static func samples(from catalog: Result<DemoCatalog, Error>) -> [DemoAnalysisSample] {
        scenarioChoices.map { choice in
            switch catalog {
            case .success(let catalog):
                return sample(scenarioID: choice.scenarioID, title: choice.title, in: catalog)
            case .failure:
                return DemoAnalysisSample(id: choice.scenarioID, title: choice.title, summary: "Sample scenario", state: .unavailable(loadFailedMessage))
            }
        }
    }

    static func sample(scenarioID: String, title: String, in catalog: DemoCatalog) -> DemoAnalysisSample {
        guard let scenario = catalog.scenarios.first(where: { $0.id == scenarioID }) else {
            return DemoAnalysisSample(id: scenarioID, title: title, summary: "Sample scenario", state: .unavailable(missingReferenceMessage))
        }
        let summary = scenario.scenarioType == .allergen
            ? "Sample allergy scenario using a demo profile with a recorded allergy. This is not your profile."
            : "Sample \(scenario.routineTime.rawValue.uppercased()) routine made of demo products. This is not your routine."
        return DemoAnalysisSample(id: scenarioID, title: title, summary: summary, state: state(for: scenario, in: catalog))
    }

    static func state(for scenario: DemoScenario, in catalog: DemoCatalog) -> DemoAnalysisState {
        guard let profile = catalog.profile(id: scenario.profileId),
              let scenarioProducts = productNames(scenario.productIds, in: catalog) else {
            return .unavailable(missingReferenceMessage)
        }
        if scenario.expectedFindings.isEmpty {
            return scenario.scenarioType == .normal ? .normal(productNames: scenarioProducts) : .unavailable(missingReferenceMessage)
        }
        var findings: [DemoFindingPresentation] = []
        for finding in scenario.expectedFindings {
            guard let names = productNames(finding.productIds, in: catalog) else {
                return .unavailable(missingReferenceMessage)
            }
            let status = DemoFindingStatus(finding.kind)
            let limitation: String?
            switch status {
            case .unknown:
                limitation = unknownLimitation
            case .allergen:
                guard !profile.recordedAllergens.isEmpty else { return .unavailable(missingReferenceMessage) }
                let allergens = profile.recordedAllergens.joined(separator: ", ")
                limitation = "Sample allergy scenario: “you” means a demo profile that records an allergy to \(allergens), not your profile."
            case .caution:
                limitation = nil
            }
            let ingredient = finding.ingredient?.trimmingCharacters(in: .whitespacesAndNewlines)
            findings.append(DemoFindingPresentation(
                status: status,
                category: finding.category,
                productNames: names,
                ingredient: (ingredient?.isEmpty ?? true) ? nil : ingredient,
                explanation: finding.explanation,
                reason: finding.reason,
                limitation: limitation
            ))
        }
        return .findings(findings)
    }

    private static func productNames(_ ids: [String], in catalog: DemoCatalog) -> [String]? {
        guard !ids.isEmpty else { return nil }
        var names: [String] = []
        for id in ids {
            guard let product = catalog.product(id: id) else { return nil }
            names.append(product.name)
        }
        return names
    }
}
