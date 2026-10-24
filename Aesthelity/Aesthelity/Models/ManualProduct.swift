import Foundation

/// A user-entered product, retaining its label and ordered normalization results.
struct ManualProduct: Codable, Equatable, Identifiable {
    enum Source: String, Codable {
        case manual
    }

    let id: UUID
    let source: Source
    var schemaVersion: Int
    var name: String
    var brand: String?
    var category: DemoProductCategory?
    var rawIngredientList: String
    var ingredients: [NormalizedIngredient]

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        category: DemoProductCategory? = nil,
        rawIngredientList: String,
        ingredients: [NormalizedIngredient],
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.source = .manual
        self.schemaVersion = schemaVersion
        self.name = name
        self.brand = brand
        self.category = category
        self.rawIngredientList = rawIngredientList
        self.ingredients = ingredients
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, schemaVersion, name, brand, category, rawIngredientList, ingredients
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        source = try container.decode(Source.self, forKey: .source)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        category = try container.decodeIfPresent(DemoProductCategory.self, forKey: .category)
        rawIngredientList = try container.decode(String.self, forKey: .rawIngredientList)
        ingredients = try container.decode([NormalizedIngredient].self, forKey: .ingredients)
    }
}
