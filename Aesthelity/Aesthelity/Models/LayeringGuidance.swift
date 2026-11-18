import Foundation

struct LayeringGuidance {
    struct Step: Identifiable {
        let id: UUID
        let name: String
        let explanation: String
    }

    let steps: [Step]
    let isIncomplete: Bool
    let cautions: [String]

    static let sourceURL = URL(string: "https://www.aad.org/public/everyday-care/skin-care-basics/care/apply-skin-care-certain-order")
    private static let unknownOrderExplanation = "Order unknown. Product type, ingredient coverage, or directions are insufficient for a suggestion."
    static let disclaimer = "General guidance only. Follow product directions and your clinician’s advice. Application order does not establish compatibility or guarantee safety."

    private enum Stage: Int {
        case cleanse, treatment, moisturize, sunscreen

        var explanation: String {
            switch self {
            case .cleanse: return "Cleansing comes before leave-on products."
            case .treatment: return "Serums and treatments generally follow cleansing and precede moisturizer. Follow the label for product-specific directions."
            case .moisturize: return "Moisturizer generally follows leave-on treatments."
            case .sunscreen: return "For daytime use, apply sunscreen after moisturizer and follow its label."
            }
        }
    }

    static func evaluate(_ inputs: [RoutineStepItem], period: RoutinePeriod) -> Self {
        let rows = inputs.enumerated().map { index, step -> (Int, RoutineStepItem, Stage?) in
            guard let product = step.product,
                  product.listStatus == IngredientListStatus.complete.rawValue,
                  !product.ingredientNames.isEmpty else { return (index, step, nil) }
            let stage: Stage?
            switch product.category {
            case .cleanser: stage = .cleanse
            case .serum, .treatment: stage = .treatment
            case .moisturizer: stage = .moisturize
            case .sunscreen: stage = period == .am ? .sunscreen : nil
            default: stage = nil
            }
            return (index, step, stage)
        }
        let incomplete = rows.isEmpty || rows.contains { $0.2 == nil }
        let treatmentCount = rows.filter { $0.2 == .treatment }.count
        let repeatedStage = Dictionary(grouping: rows.compactMap { $0.2 }, by: { $0 })
            .values.contains { $0.count > 1 }
        var cautions: [String] = []
        if treatmentCount > 1 {
            cautions.append("Multiple serums or treatments need product-specific instructions. Their relative order and combined use have not been established.")
        }
        if repeatedStage {
            cautions.append("Products in the same category retain your saved order. A preferred order within that category is unknown.")
        }
        // A partial sequence could imply an unsupported position for an unknown product.
        let ordered = incomplete ? rows : rows.sorted {
            let left = $0.2?.rawValue ?? 0
            let right = $1.2?.rawValue ?? 0
            return left == right ? $0.0 < $1.0 : left < right
        }
        return Self(
            steps: ordered.map { _, step, stage in
                Step(id: step.id, name: step.title,
                     explanation: incomplete
                        ? unknownOrderExplanation
                        : stage?.explanation ?? unknownOrderExplanation)
            },
            isIncomplete: incomplete,
            cautions: cautions
        )
    }
}
