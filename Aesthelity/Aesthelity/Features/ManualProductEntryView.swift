import SwiftUI

struct ManualProductEntryView: View {
    @EnvironmentObject private var store: ManualProductStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ManualProductDraft()
    @State private var attemptedSubmission = false
    @State private var preparedProduct: ManualProduct?
    @State private var saveError: String?
    private let normalizer = try? IngredientNormalizer(catalog: .loadBundled())

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
                if normalizer == nil {
                    Section {
                        Text("Ingredient information could not be loaded. Close this form and try again.")
                            .foregroundStyle(.red)
                    }
                }
                if let message = store.loadError {
                    Section { Text(message).foregroundStyle(.red) }
                }
                Section {
                    Button("Review ingredients", action: review)
                        .accessibilityIdentifier("manual-review")
                        .disabled(normalizer == nil)
                }
                if let product = preparedProduct {
                    Section("Review ingredients") {
                        ManualIngredientRows(ingredients: product.ingredients)
                    }
                    Section {
                        if let saveError {
                            Text(saveError)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("manual-save-error")
                        }
                        Button("Save product on this device") { save(product) }
                            .accessibilityIdentifier("manual-save")
                    } footer: {
                        Text("This saves your entry locally. Ingredient matches are not a safety assessment. Analysis is not available yet.")
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
                saveError = nil
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

    private func review() {
        hideKeyboard()
        attemptedSubmission = true
        guard let normalizer else { return }
        switch draft.submit(using: normalizer) {
        case .invalid:
            preparedProduct = nil
        case .completed(let product):
            preparedProduct = product
        }
    }

    private func save(_ product: ManualProduct) {
        do {
            try store.save(product)
            // TODO(PD-02/AN-03): Hand off after completeness, catalog version, and API are agreed.
            dismiss()
        } catch {
            saveError = "Your product could not be saved. Your entries are still here. Please try again."
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ManualIngredientRows: View {
    let ingredients: [NormalizedIngredient]

    var body: some View {
        ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
            VStack(alignment: .leading, spacing: 6) {
                Text(ingredient.originalText)
                if let warning = ingredient.warning {
                    Text(warning.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("manual-warning-\(index)")
                }
            }
        }
    }
}
