import Foundation

// Raw values must match the strings in Resources/DemoData/*.json; an unrecognized value fails decoding.

enum DemoProductCategory: String, Codable, CaseIterable {
    case cleanser, serum, treatment, moisturizer, sunscreen, toner, mist, mask
}

enum IngredientListStatus: String, Decodable, CaseIterable {
    case complete, partial, unavailable
}

enum DemoFindingKind: String, Decodable, CaseIterable {
    case caution, allergen, unknown
}

enum DemoScenarioType: String, Decodable, CaseIterable {
    case normal, caution, allergen, unknown
}

enum DemoRoutineTime: String, Decodable, CaseIterable {
    case am, pm
}

struct DemoProduct: Decodable, Identifiable {
    let id: String
    let name: String
    let brand: String
    let category: DemoProductCategory
    let subtype: String
    let ingredients: [String]
    let ingredientListStatus: IngredientListStatus
    let isFictional: Bool
    let sourceUrl: String
    let sourceRef: String
    let verifiedOn: String
    let provenance: Provenance
    let spf: Int?
    struct Provenance: Decodable {
        let kind: String
        let verificationMethod: String
        let note: String
    }
}

struct DemoProfile: Decodable, Identifiable {
    let id: String
    let recordedAllergens: [String]
}

struct DemoFinding: Decodable {
    let kind: DemoFindingKind
    let productIds: [String]
    let ingredient: String?
    let message: String
    let category: String
    let explanation: String
    let reason: String
}

struct DemoScenario: Decodable, Identifiable {
    let id: String
    let scenarioType: DemoScenarioType
    let productIds: [String]
    let profileId: String
    let routineTime: DemoRoutineTime
    let expectedFindings: [DemoFinding]
}

struct DemoCatalog {
    let products: [DemoProduct]
    let profiles: [DemoProfile]
    let scenarios: [DemoScenario]

    enum LoadError: Error { case missingResource(String), unsupportedVersion, duplicateIDs(String) }

    func product(id: String) -> DemoProduct? {
        products.first { $0.id == id }
    }

    func profile(id: String) -> DemoProfile? {
        profiles.first { $0.id == id }
    }

    static func load(bundle: Bundle = .main) throws -> DemoCatalog {
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
