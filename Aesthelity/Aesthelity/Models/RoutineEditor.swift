import Foundation

public enum RoutineProductReference: Equatable, Hashable, Codable {
    case catalog(String)
    case manual(UUID)
}

/// Product information captured when a step is added; no safety conclusion is inferred.
public struct RoutineProductSnapshot: Equatable, Codable {
    public let reference: RoutineProductReference
    public let name: String
    public let brand: String?
    public let ingredientNames: [String]
    public let listStatus: String
    let normalizedIngredients: [NormalizedIngredient]

    init(_ product: DemoProduct) {
        reference = .catalog(product.id)
        name = product.name
        brand = product.brand
        ingredientNames = product.ingredients
        listStatus = product.ingredientListStatus.rawValue
        normalizedIngredients = []
    }

    init(_ product: ManualProduct) {
        reference = .manual(product.id)
        name = product.name
        brand = product.brand
        ingredientNames = product.ingredients.map(\.originalText)
        listStatus = "User-entered; completeness not verified"
        normalizedIngredients = product.ingredients
    }

    var provenance: String {
        switch reference {
        case .catalog: return "Fictional demo catalog"
        case .manual: return "Manually entered"
        }
    }

    var productID: UUID {
        switch reference {
        case .catalog(let id): return CatalogProductIdentity.uuid(forCatalogId: id)
        case .manual(let id): return id
        }
    }

    var step: RoutineStepItem {
        RoutineStepItem(stepNumber: 1, title: name, subtitle: brand ?? provenance, state: .incomplete, productId: productID, product: self)
    }
}

enum RoutineEditor {
    static let maximumSteps = 8

    static func validationErrors(name: String, steps: [RoutineStepItem]) -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Enter a routine name.") }
        if steps.isEmpty { errors.append("Add at least one product before saving.") }
        if steps.count > maximumSteps { errors.append("Use at most \(maximumSteps) steps in a routine.") }
        return errors
    }

    static func numbered(_ steps: [RoutineStepItem]) -> [RoutineStepItem] {
        steps.enumerated().map { index, step in
            RoutineStepItem(id: step.id, stepNumber: index + 1, title: step.title,
                            subtitle: step.subtitle, state: step.state, hasClash: step.hasClash, productId: step.productId, product: step.product)
        }
    }

    static func adding(_ step: RoutineStepItem, to steps: [RoutineStepItem]) -> [RoutineStepItem] {
        guard steps.count < maximumSteps else { return steps }
        if let reference = step.product?.reference,
           steps.contains(where: { $0.product?.reference == reference }) { return steps }
        if let productID = step.productId,
           steps.contains(where: { $0.productId == productID }) { return steps }
        return numbered(steps + [step])
    }

    static func removing(_ id: UUID, from steps: [RoutineStepItem]) -> [RoutineStepItem] {
        numbered(steps.filter { $0.id != id })
    }

    static func moving(_ steps: [RoutineStepItem], from source: Int, to destination: Int) -> [RoutineStepItem] {
        guard steps.indices.contains(source), steps.indices.contains(destination) else { return steps }
        var result = steps
        result.insert(result.remove(at: source), at: destination)
        return numbered(result)
    }
}
