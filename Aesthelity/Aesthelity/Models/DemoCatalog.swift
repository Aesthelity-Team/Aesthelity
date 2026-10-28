import Foundation

// Raw values must match the strings in Resources/DemoData/*.json; an unrecognized value fails decoding.

public enum DemoProductCategory: String, Decodable, CaseIterable {
    case cleanser, serum, treatment, moisturizer, sunscreen, toner, mist, mask
    
    public var displayName: String {
        switch self {
        case .cleanser: return "Cleansers"
        case .serum: return "Serums"
        case .treatment: return "Treatments"
        case .moisturizer: return "Moisturizers"
        case .sunscreen: return "Sunscreens"
        case .toner: return "Toners"
        case .mist: return "Mists"
        case .mask: return "Masks"
        }
    }
}

public enum IngredientListStatus: String, Codable, Equatable, CaseIterable {
    case complete, partial, unavailable
}

public enum DemoFindingKind: String, Decodable, CaseIterable {
    case caution, allergen, unknown
}

public enum DemoScenarioType: String, Decodable, CaseIterable {
    case normal, caution, allergen, unknown
}

public enum DemoRoutineTime: String, Decodable, CaseIterable {
    case am, pm
}

public struct DemoProduct: Decodable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let brand: String
    public let category: DemoProductCategory
    public let subtype: String
    public let ingredients: [String]
    public let ingredientListStatus: IngredientListStatus
    public let isFictional: Bool
    public let sourceUrl: String
    public let sourceRef: String
    public let verifiedOn: String
    public let provenance: Provenance
    public let spf: Int?

    public struct Provenance: Decodable, Equatable {
        public let kind: String
        public let verificationMethod: String
        public let note: String

        public init(kind: String = "fixture", verificationMethod: String = "manual", note: String = "") {
            self.kind = kind
            self.verificationMethod = verificationMethod
            self.note = note
        }
    }

    public init(
        id: String,
        name: String,
        brand: String,
        category: DemoProductCategory,
        subtype: String,
        ingredients: [String] = [],
        ingredientListStatus: IngredientListStatus = .complete,
        isFictional: Bool = true,
        sourceUrl: String = "",
        sourceRef: String = "",
        verifiedOn: String = "",
        provenance: Provenance = Provenance(),
        spf: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.subtype = subtype
        self.ingredients = ingredients
        self.ingredientListStatus = ingredientListStatus
        self.isFictional = isFictional
        self.sourceUrl = sourceUrl
        self.sourceRef = sourceRef
        self.verifiedOn = verifiedOn
        self.provenance = provenance
        self.spf = spf
    }
}

public struct DemoProfile: Decodable, Identifiable {
    public let id: String
    public let recordedAllergens: [String]
    
    public init(id: String, recordedAllergens: [String] = []) {
        self.id = id
        self.recordedAllergens = recordedAllergens
    }
}

public struct DemoFinding: Decodable {
    public let kind: DemoFindingKind
    public let productIds: [String]
    public let ingredient: String?
    public let message: String
    public let category: String
    public let explanation: String
    public let reason: String
    
    public init(
        kind: DemoFindingKind,
        productIds: [String],
        ingredient: String? = nil,
        message: String,
        category: String,
        explanation: String,
        reason: String
    ) {
        self.kind = kind
        self.productIds = productIds
        self.ingredient = ingredient
        self.message = message
        self.category = category
        self.explanation = explanation
        self.reason = reason
    }
}

public struct DemoScenario: Decodable, Identifiable {
    public let id: String
    public let scenarioType: DemoScenarioType
    public let productIds: [String]
    public let profileId: String
    public let routineTime: DemoRoutineTime
    public let expectedFindings: [DemoFinding]
    
    public init(
        id: String,
        scenarioType: DemoScenarioType,
        productIds: [String],
        profileId: String,
        routineTime: DemoRoutineTime,
        expectedFindings: [DemoFinding] = []
    ) {
        self.id = id
        self.scenarioType = scenarioType
        self.productIds = productIds
        self.profileId = profileId
        self.routineTime = routineTime
        self.expectedFindings = expectedFindings
    }
}

public struct DemoCatalog {
    public let products: [DemoProduct]
    public let profiles: [DemoProfile]
    public let scenarios: [DemoScenario]

    public init(
        products: [DemoProduct] = [],
        profiles: [DemoProfile] = [],
        scenarios: [DemoScenario] = []
    ) {
        self.products = products
        self.profiles = profiles
        self.scenarios = scenarios
    }

    public enum LoadError: Error { case missingResource(String), unsupportedVersion, duplicateIDs(String) }

    public func product(id: String) -> DemoProduct? {
        products.first { $0.id == id }
    }

    public func profile(id: String) -> DemoProfile? {
        profiles.first { $0.id == id }
    }

    public static func load(bundle: Bundle = .main) throws -> DemoCatalog {
        let products = try decode(ProductsFile.self, named: "products", from: bundle)
        let profiles = try decode(ProfilesFile.self, named: "profiles", from: bundle)
        let scenarios = try decode(ScenariosFile.self, named: "scenarios", from: bundle)
        guard [products.schemaVersion, profiles.schemaVersion, scenarios.schemaVersion].allSatisfy({ $0 == 1 }) else {
            throw LoadError.unsupportedVersion
        }
        try requireUniqueIDs(products.products.map(\.id), file: "products")
        try requireUniqueIDs(profiles.profiles.map(\.id), file: "profiles")
        try requireUniqueIDs(scenarios.scenarios.map(\.id), file: "scenarios")
        return DemoCatalog(products: products.products, profiles: profiles.profiles, scenarios: scenarios.scenarios)
    }

    private struct ProductsFile: Decodable { let schemaVersion: Int; let products: [DemoProduct] }
    private struct ProfilesFile: Decodable { let schemaVersion: Int; let profiles: [DemoProfile] }
    private struct ScenariosFile: Decodable { let schemaVersion: Int; let scenarios: [DemoScenario] }

    private static func decode<T: Decodable>(_ type: T.Type, named name: String, from bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw LoadError.missingResource("\(name).json")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    private static func requireUniqueIDs(_ ids: [String], file: String) throws {
        guard Set(ids).count == ids.count else { throw LoadError.duplicateIDs("\(file).json") }
    }
}
