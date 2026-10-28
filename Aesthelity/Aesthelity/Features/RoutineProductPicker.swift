import SwiftUI

struct RoutineProductPicker: View {
    @EnvironmentObject private var store: ManualProductStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let steps: [RoutineStepItem]
    let onSelect: (RoutineStepItem) -> Void
    private let catalog = Result { try DemoCatalog.load() }

    private func matches(_ product: RoutineProductSnapshot) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || product.name.localizedCaseInsensitiveContains(text)
            || (product.brand?.localizedCaseInsensitiveContains(text) ?? false)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Bundled catalog") {
                    switch catalog {
                    case .success(let catalog):
                        let products = catalog.products.map(RoutineProductSnapshot.init).filter(matches)
                        if products.isEmpty { Text("No catalog products match your search.") }
                        ForEach(products, id: \.reference) { row($0) }
                    case .failure:
                        Text("The catalog could not be loaded. Close this picker and try again.")
                    }
                }
                Section("Manual products on this device") {
                    if let error = store.loadError { Text(error).foregroundStyle(.red) }
                    let products = store.products.map(RoutineProductSnapshot.init).filter(matches)
                    if products.isEmpty { Text("No saved manual products match your search.") }
                    ForEach(products, id: \.reference) { row($0) }
                }
            }
            .searchable(text: $query, prompt: "Product name or brand")
            .navigationTitle("Add a product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .tint(.primary)
        }
    }

    private func row(_ product: RoutineProductSnapshot) -> some View {
        let alreadyAdded = steps.contains { $0.product?.reference == product.reference || $0.productId == product.productID }
        return VStack(alignment: .leading, spacing: 8) {
            Text(product.name).font(.headline)
            if let brand = product.brand { Text(brand).font(.subheadline) }
            Text(product.provenance).font(.caption)
            RoutineIngredientInfo(product: product)
            Button(alreadyAdded ? "Already added" : "Add product") {
                onSelect(product.step)
                dismiss()
            }
            .disabled(alreadyAdded || steps.count >= RoutineEditor.maximumSteps)
            .accessibilityIdentifier("routine-pick-\(referenceID(product.reference))")
        }
        .padding(.vertical, 6)
    }

    private func referenceID(_ reference: RoutineProductReference) -> String {
        switch reference {
        case .catalog(let id): return "catalog-\(id)"
        case .manual(let id): return "manual-\(id.uuidString)"
        }
    }
}

struct RoutineIngredientInfo: View {
    let product: RoutineProductSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ingredients: \(product.ingredientNames.prefix(3).joined(separator: ", ").isEmpty ? "Unavailable" : product.ingredientNames.prefix(3).joined(separator: ", "))")
                .font(.caption)
            Text("List: \(product.listStatus) · Not analyzed").font(.caption)
            DisclosureGroup("Ingredient details") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(product.ingredientNames.enumerated()), id: \.offset) { _, name in Text(name) }
                    ForEach(Array(product.normalizedIngredients.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(warning.message).font(.footnote)
                    }
                }
            }
            .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

struct RoutineStepsEditor: View {
    @Binding var steps: [RoutineStepItem]
    let onAdd: () -> Void
    @State private var pendingRemoval: RoutineStepItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STEPS · \(steps.count)").font(.headline)
            if steps.isEmpty { Text("Add your first product to build this routine.") }
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(index + 1). \(step.title)").font(.headline)
                        .accessibilityIdentifier("routine-step-\(index)")
                    if let product = step.product {
                        Text(product.provenance).font(.caption)
                        RoutineIngredientInfo(product: product)
                    } else {
                        Text("Ingredient information unavailable for this existing step.").font(.caption)
                    }
                    HStack {
                        Button { steps = RoutineEditor.moving(steps, from: index, to: index - 1) } label: {
                            Image(systemName: "arrow.up").frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(index == 0)
                        .accessibilityLabel("Move \(step.title) up")
                        .accessibilityIdentifier("routine-up-\(index)")
                        Button { steps = RoutineEditor.moving(steps, from: index, to: index + 1) } label: {
                            Image(systemName: "arrow.down").frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(index == steps.count - 1)
                        .accessibilityLabel("Move \(step.title) down")
                        .accessibilityIdentifier("routine-down-\(index)")
                        Spacer()
                        Button("Remove", role: .destructive) { pendingRemoval = step }
                            .accessibilityIdentifier("routine-remove-\(index)")
                    }
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
            if steps.count >= RoutineEditor.maximumSteps {
                Text("This routine has the maximum of eight steps.").font(.footnote)
            }
            Button("Add product", systemImage: "plus", action: onAdd)
                .disabled(steps.count >= RoutineEditor.maximumSteps)
                .accessibilityIdentifier("routine-add-product")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color(hex: "#1A1628"))
        .tint(Color(hex: "#50578F"))
        .confirmationDialog("Remove \(pendingRemoval?.title ?? "product")?", isPresented: Binding(
            get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }
        ), titleVisibility: .visible) {
            Button("Remove product", role: .destructive) {
                if let step = pendingRemoval { steps = RoutineEditor.removing(step.id, from: steps) }
                pendingRemoval = nil
            }
            Button("Keep product") { pendingRemoval = nil }
        }
    }
}
