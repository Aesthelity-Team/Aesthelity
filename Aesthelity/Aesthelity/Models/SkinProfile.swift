import Foundation

/// Information the user chooses to provide. Ingredient avoidance is a preference,
/// not a diagnosed allergy. An empty list means no preferences were recorded.
struct SkinProfile: Codable, Equatable {
    enum SetupStatus: String, Codable {
        case notStarted = "not-started"
        case skipped
        /// Setup was submitted; optional fields and unresolved ingredients may remain.
        case completed
    }

    enum SkinType: String, CaseIterable, Codable {
        case normal
        case dry
        case oily
        case combination
    }

    /// Stable identifiers corresponding to the existing onboarding concern choices.
    enum Concern: String, CaseIterable, Codable {
        case acneProne = "acne-prone"
        case sensitivityAndRedness = "sensitivity-and-redness"
        case barrierRepair = "barrier-repair"
        case fineLines = "fine-lines"
        case drynessAndHydration = "dryness-and-hydration"
        case darkSpots = "dark-spots"
        case oilControlAndPores = "oil-control-and-pores"
        case unevenTexture = "uneven-texture"
    }

    var schemaVersion: Int
    var skinType: SkinType?
    var concerns: Set<Concern>
    /// Keeps original text, matching status, and warnings from DATA-02 intact.
    var avoidedIngredients: [NormalizedIngredient]
    var setupStatus: SetupStatus

    init(
        skinType: SkinType? = nil,
        concerns: Set<Concern> = [],
        avoidedIngredients: [NormalizedIngredient] = [],
        setupStatus: SetupStatus = .notStarted,
        schemaVersion: Int = 1
    ) {
        self.schemaVersion = schemaVersion
        self.skinType = skinType
        self.concerns = concerns
        self.avoidedIngredients = avoidedIngredients
        self.setupStatus = setupStatus
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, skinType, concerns, avoidedIngredients, setupStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        skinType = try container.decodeIfPresent(SkinType.self, forKey: .skinType)
        concerns = try container.decode(Set<Concern>.self, forKey: .concerns)
        avoidedIngredients = try container.decode([NormalizedIngredient].self, forKey: .avoidedIngredients)
        setupStatus = try container.decode(SetupStatus.self, forKey: .setupStatus)
    }

    var isComplete: Bool { setupStatus == .completed }

    /// A fresh skipped profile does not accidentally submit an unfinished draft.
    static var skipped: SkinProfile { SkinProfile(setupStatus: .skipped) }
}
