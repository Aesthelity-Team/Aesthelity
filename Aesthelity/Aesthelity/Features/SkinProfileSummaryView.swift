import SwiftUI

extension SkinProfile.SkinType {
    var displayName: String { rawValue.capitalized }
}

extension SkinProfile.Concern {
    var displayName: String {
        switch self {
        case .acneProne: return "Acne prone"
        case .sensitivityAndRedness: return "Sensitivity & redness"
        case .barrierRepair: return "Barrier repair"
        case .fineLines: return "Anti-aging / fine lines"
        case .drynessAndHydration: return "Dryness & hydration"
        case .darkSpots: return "Hyperpigmentation & dark spots"
        case .oilControlAndPores: return "Oil control & pores"
        case .unevenTexture: return "Uneven texture"
        }
    }
}

extension SkinProfile {
    var concernSummary: String {
        let selected = Concern.allCases.filter { concerns.contains($0) }
        return selected.isEmpty ? "None provided" : selected.map(\.displayName).joined(separator: ", ")
    }

    var statusText: String {
        switch setupStatus {
        case .notStarted: return "Profile incomplete — setup not completed"
        case .skipped: return "Profile incomplete — setup skipped"
        case .completed: return "Profile setup completed"
        }
    }
}

struct SkinProfileSummaryView: View {
    let profile: SkinProfile
    private let ingredientLookup = Result { try IngredientNormalizer(catalog: .loadBundled()) }
    private var normalizer: IngredientNormalizer? { try? ingredientLookup.get() }
    private var ingredientLookupError: String? {
        if case .failure(let error) = ingredientLookup { return error.localizedDescription }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(profile.statusText)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("profile-summary-status")
            summaryRow("Skin type", value: profile.skinType?.displayName ?? "Not provided", id: "skin-type")
            summaryRow("Concerns", value: profile.concernSummary, id: "concerns")
            Text("Ingredients you avoid").font(.subheadline.weight(.semibold))
            if let ingredientLookupError {
                Text(ingredientLookupError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("ingredient-lookup-error")
            }
            if profile.avoidedIngredients.isEmpty {
                Text("None provided").accessibilityIdentifier("profile-summary-ingredients")
            }
            ForEach(Array(profile.avoidedIngredients.enumerated()), id: \.offset) { index, ingredient in
                VStack(alignment: .leading, spacing: 4) {
                    let canonicalName = ingredient.ingredientID.flatMap { normalizer?.ingredient(withID: $0)?.name }
                    Text(canonicalName ?? ingredient.originalText)
                        .accessibilityIdentifier("profile-summary-ingredient-\(index)")
                    if let canonicalName, canonicalName.caseInsensitiveCompare(ingredient.originalText) != .orderedSame {
                        Text("Entered as \(ingredient.originalText)")
                            .font(.caption)
                            .accessibilityIdentifier("profile-summary-original-\(index)")
                    }
                    if let warning = ingredient.warning {
                        Text(warning.message).font(.caption).foregroundStyle(Constants.semanticInkSecondary)
                    }
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(Constants.semanticInkBrand)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryRow(_ title: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).fontWeight(.semibold)
            Text(value).accessibilityIdentifier("profile-summary-\(id)")
        }
    }
}
