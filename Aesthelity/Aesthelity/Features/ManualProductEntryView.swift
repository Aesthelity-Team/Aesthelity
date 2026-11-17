import SwiftUI
import FirebaseAuth

struct ManualProductEntryView: View {
    @EnvironmentObject private var store: ManualProductStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ManualProductDraft()
    @State private var attemptedSubmission = false
    @State private var preparedProduct: ManualProduct?
    @State private var coverage: String?
    @State private var matchingNote: String?
    @State private var saveError: String?
    @State private var isResolving = false
    @State private var isSaving = false
    @State private var normalizer: IngredientNormalizer?
    @State private var loadingNormalizer = true
    private let api = BackendAnalysisAPI()

    private var errors: [ManualProductDraft.ValidationError] {
        attemptedSubmission ? draft.validationErrors() : []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $draft.name)
                        .accessibilityIdentifier("manual-name")
                    fieldErrors(.name)
                    TextField("Brand (optional)", text: $draft.brand)
                        .accessibilityIdentifier("manual-brand")
                    fieldErrors(.brand)
                    Picker("Category (optional)", selection: $draft.category) {
                        Text("Not specified").tag(nil as DemoProductCategory?)
                        ForEach(DemoProductCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(Optional(category))
                        }
                    }
                    .accessibilityIdentifier("manual-category")
                }
                Section {
                    TextEditor(text: $draft.rawIngredientList)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Ingredient list")
                        .accessibilityIdentifier("manual-ingredients")
                    fieldErrors(.ingredientList)
                } header: {
                    Text("Ingredient list")
                } footer: {
                    Text("Copy the label using commas or line breaks between ingredients. Use at most 120 characters per ingredient.")
                }
                if !loadingNormalizer && normalizer == nil {
                    Section {
                        Text("On-device ingredient catalog could not be loaded. Matching still tries the backend first.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let message = store.loadError {
                    Section { Text(message).foregroundStyle(.red) }
                }
                Section {
                    Button("Review ingredients", action: review)
                        .accessibilityIdentifier("manual-review")
                        .disabled(isResolving)
                    if isResolving {
                        ProgressView("Matching ingredients…")
                            .accessibilityIdentifier("manual-resolving")
                    }
                }
                if let product = preparedProduct {
                    if let coverage {
                        Section {
                            Text(coverageLabel(coverage))
                                .accessibilityIdentifier("manual-coverage")
                            if let matchingNote {
                                Text(matchingNote)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("manual-matching-note")
                            }
                        } header: {
                            Text("Coverage")
                        }
                    }
                    Section("Review ingredients") {
                        ManualIngredientRows(ingredients: product.ingredients)
                    }
                    Section {
                        if let saveError {
                            Text(saveError)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("manual-save-error")
                        }
                        Button(isSaving ? "Saving…" : "Save product on this device") { save(product) }
                            .accessibilityIdentifier("manual-save")
                            .disabled(isSaving || isResolving)
                    } footer: {
                        Text("Saves on this device. When you are signed in, the ingredient list is also written to Firestore. Matches are not a safety assessment.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .tint(.primary)
            .navigationTitle("Add product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("manual-cancel")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .onChange(of: draft) { _, _ in
                preparedProduct = nil
                coverage = nil
                matchingNote = nil
                saveError = nil
            }
            .task {
                guard normalizer == nil else { return }
                do {
                    let catalog = try await IngredientAliasCatalogService().loadCatalog()
                    normalizer = IngredientNormalizer(catalog: catalog)
                } catch {
                    loadingNormalizer = false
                }
                loadingNormalizer = false
            }
        }
    }

    private func fieldErrors(_ field: ManualProductDraft.ValidationError.Field) -> some View {
        ForEach(Array(errors.filter { $0.field == field }.enumerated()), id: \.offset) { _, error in
            Text(error.entryIndex.map { "Ingredient \($0 + 1) (\(error.input.trimmingCharacters(in: .whitespacesAndNewlines))): \(error.message)" } ?? error.message)
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityIdentifier("manual-error-\(String(describing: field))")
        }
    }

    private func coverageLabel(_ value: String) -> String {
        switch value {
        case "complete":
            return "Complete — every ingredient was identified in the approved catalog."
        case "partial":
            return "Partial — some ingredients were identified; others are best guesses or unknown."
        default:
            return "Unknown — no approved-catalog matches yet, or matching did not complete."
        }
    }

    private func review() {
        hideKeyboard()
        attemptedSubmission = true
        let validation = draft.validationErrors()
        guard validation.isEmpty else {
            preparedProduct = nil
            coverage = nil
            matchingNote = nil
            return
        }
        let entries = IngredientLabelParser.entriesForValidation(in: draft.rawIngredientList)
        let names = entries.compactMap(\.name)
        let productID = UUID()
        let preparedBrand = ManualProductDraft.preparedPublic(draft.brand)
        isResolving = true
        matchingNote = nil
        Task {
            defer { isResolving = false }
            do {
                let response = try await api.resolveIngredients(
                    names,
                    productID: productID.uuidString,
                    persist: false,
                    sourceType: "manual",
                    ai: true,
                    format: "analysis-input",
                    listStatus: "complete"
                )
                let ingredients = response.ingredients
                    .sorted { $0.index < $1.index }
                    .map { $0.asNormalizedIngredient() }
                preparedProduct = ManualProduct(
                    id: productID,
                    name: ManualProductDraft.preparedPublic(draft.name),
                    brand: preparedBrand.isEmpty ? nil : preparedBrand,
                    category: draft.category,
                    rawIngredientList: draft.rawIngredientList,
                    ingredients: ingredients
                )
                coverage = response.coverage ?? "unknown"
                if response.status == "failed" {
                    matchingNote = "Matching did not complete (\(response.failureCode ?? response.providerStatus ?? "ai-unavailable")). Your list is still shown."
                }
            } catch {
                if let normalizer {
                    switch draft.submit(using: normalizer) {
                    case .invalid:
                        preparedProduct = nil
                        coverage = nil
                    case .completed(let product):
                        // Keep a stable ID from this review attempt when falling back.
                        preparedProduct = ManualProduct(
                            id: productID,
                            name: product.name,
                            brand: product.brand,
                            category: product.category,
                            rawIngredientList: product.rawIngredientList,
                            ingredients: product.ingredients
                        )
                        let confirmed = product.ingredients.filter { $0.mapping == .confirmed }.count
                        if product.ingredients.isEmpty {
                            coverage = "unknown"
                        } else if confirmed == product.ingredients.count {
                            coverage = "complete"
                        } else if confirmed == 0 {
                            coverage = "unknown"
                        } else {
                            coverage = "partial"
                        }
                        matchingNote = "Using on-device catalog matching because the backend was unavailable."
                    }
                } else {
                    preparedProduct = nil
                    coverage = nil
                    matchingNote = "Ingredient matching is unavailable. Check that the local API is running, then try again."
                }
            }
        }
    }

    private func save(_ product: ManualProduct) {
        saveError = nil
        isSaving = true
        Task {
            defer { isSaving = false }
            var cloudNote: String?
            // Issue #98: persist the ordered list to Firestore when signed in.
            if Auth.auth().currentUser != nil {
                do {
                    let texts = product.ingredients.map(\.originalText)
                    let response = try await api.resolveIngredients(
                        texts,
                        productID: product.id.uuidString,
                        persist: true,
                        sourceType: "manual",
                        ai: true,
                        format: "analysis-input",
                        listStatus: "complete"
                    )
                    if response.status == "failed" {
                        cloudNote = "Saved on this device. Cloud matching reported a failure (\(response.failureCode ?? "unknown")); try syncing again later."
                    }
                } catch {
                    cloudNote = "Saved on this device. Cloud sync failed; your list is still here. Try again when the API is available."
                }
            }
            do {
                try store.save(product)
                if let cloudNote {
                    matchingNote = cloudNote
                    // Keep the sheet open so the note is visible; Cancel dismisses.
                } else {
                    dismiss()
                }
            } catch {
                saveError = "Your product could not be saved. Your entries are still here. Please try again."
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension ManualProductDraft {
    /// Trim helpers shared with the resolve review path (same rules as submit).
    static func preparedPublic(_ input: String) -> String {
        String(String.UnicodeScalarView(input.unicodeScalars.filter {
            $0.properties.generalCategory != .format
        })).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ManualIngredientRows: View {
    let ingredients: [NormalizedIngredient]

    var body: some View {
        ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
            VStack(alignment: .leading, spacing: 6) {
                Text(ingredient.originalText)
                Text(statusLabel(for: ingredient))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("manual-status-\(index)")
                if let warning = ingredient.warning {
                    Text(warning.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("manual-warning-\(index)")
                }
            }
        }
    }

    private func statusLabel(for ingredient: NormalizedIngredient) -> String {
        switch ingredient.status {
        case .matched:
            return "Identified"
        case .uncertain:
            return "Best guess"
        case .ambiguous:
            return "Best guess (ambiguous)"
        case .unmatched:
            if ingredient.warning?.message.localizedCaseInsensitiveContains("best guess") == true {
                return "Best guess"
            }
            return "Unknown"
        }
    }
}
