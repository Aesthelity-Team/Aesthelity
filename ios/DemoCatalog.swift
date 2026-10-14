import Foundation

struct DemoProduct: Decodable, Identifiable {
    let id: String
    let name: String
    let brand: String
    let category: String
    let subtype: String
    let ingredients: [String]
    let ingredientListStatus: String
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
struct DemoCatalog: Decodable {
    let schemaVersion: Int
    let products: [DemoProduct]
    enum LoadError: Error { case missingResource, unsupportedVersion, duplicateIDs }
    static func load(bundle: Bundle = .main) throws -> DemoCatalog {
        guard let url = bundle.url(forResource: "products", withExtension: "json") else {
            throw LoadError.missingResource
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let catalog = try decoder.decode(Self.self, from: Data(contentsOf: url))
        guard catalog.schemaVersion == 1 else { throw LoadError.unsupportedVersion }
        guard Set(catalog.products.map(\.id)).count == catalog.products.count else {
            throw LoadError.duplicateIDs
        }
        return catalog
    }
}
