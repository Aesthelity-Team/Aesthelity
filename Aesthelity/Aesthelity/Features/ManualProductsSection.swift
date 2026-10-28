import SwiftUI

struct ManualProductsSection: View {
    @EnvironmentObject private var store: ManualProductStore
    @State private var showsEntry = false
    @State private var selectedProduct: ManualProduct?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your manual products").font(.headline)
                Spacer()
                Button { showsEntry = true } label: {
                    Label("Add product", systemImage: "plus")
                }
                .accessibilityIdentifier("manual-add")
            }
            if let error = store.loadError {
                Text(error).font(.footnote).foregroundStyle(.red)
            } else if store.products.isEmpty {
                Text("Add a product and its ingredient label. Entries are saved on this device.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(store.products) { product in
                Button { selectedProduct = product } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name).font(.headline)
                        if let brand = product.brand { Text(brand).font(.subheadline) }
                        Text("Manually entered · Not analyzed").font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Constants.semanticSurfaceCanvas, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("manual-product-\(product.id.uuidString)")
            }
        }
        .foregroundStyle(Constants.semanticInkBrand)
        .sheet(isPresented: $showsEntry) { ManualProductEntryView() }
        .sheet(item: $selectedProduct) { product in
            NavigationStack {
                Form {
                    Section("Product") {
                        Text(product.name)
                        if let brand = product.brand { Text(brand) }
                        Text(product.category?.rawValue.capitalized ?? "Category not specified")
                        Text("Manually entered · Not analyzed").font(.footnote)
                    }
                    Section("Original ingredient label") { Text(product.rawIngredientList).textSelection(.enabled) }
                    Section("Ingredient review") { ManualIngredientRows(ingredients: product.ingredients) }
                    Section { Text("Saved on this device. Analysis is not available yet.") }
                }
                .navigationTitle("Saved product")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { selectedProduct = nil }
                    }
                }
            }
        }
    }
}
