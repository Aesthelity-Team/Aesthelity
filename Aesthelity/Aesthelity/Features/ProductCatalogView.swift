//
//  ProductCatalogView.swift
//  Aesthelity
//
//  Searchable, filterable skincare product catalog with ingredient transparency
//  and routine integration.
//

import SwiftUI

/// Searchable, categorized catalog screen displaying products, ingredient transparency,
/// and direct routine addition.
public struct ProductCatalogView: View {
    public let products: [DemoProduct]
    public var onSelectProduct: ((DemoProduct) -> Void)?
    public var onAddToRoutine: ((DemoProduct, RoutinePeriod) -> Void)?
    public var onBack: (() -> Void)?
    public var showsBackButton: Bool
    public var showsTabBar: Bool
    public var fullScreenFrame: Bool
    public var onSelectTab: ((Int) -> Void)?

    // MARK: - State
    @State public var searchText: String = ""
    @State public var selectedCategory: DemoProductCategory? = nil
    @State public var selectedProduct: DemoProduct? = nil
    @State private var productForRoutineSheet: DemoProduct? = nil
    @State private var routineToastMessage: String? = nil

    public init(
        products: [DemoProduct]? = nil,
        initialSearchText: String = "",
        initialCategory: DemoProductCategory? = nil,
        onSelectProduct: ((DemoProduct) -> Void)? = nil,
        onAddToRoutine: ((DemoProduct, RoutinePeriod) -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        showsBackButton: Bool = false,
        showsTabBar: Bool = false,
        fullScreenFrame: Bool = false,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        if let products = products {
            self.products = products
        } else {
            self.products = (try? DemoCatalog.load().products) ?? []
        }
        self._searchText = State(wrappedValue: initialSearchText)
        self._selectedCategory = State(wrappedValue: initialCategory)
        self.onSelectProduct = onSelectProduct
        self.onAddToRoutine = onAddToRoutine
        self.onBack = onBack
        self.showsBackButton = showsBackButton
        self.showsTabBar = showsTabBar
        self.fullScreenFrame = fullScreenFrame
        self.onSelectTab = onSelectTab
    }

    // Overload for binary and call-site compatibility
    public init(
        products: [DemoProduct]?,
        onSelectProduct: ((DemoProduct) -> Void)?,
        onAddToRoutine: ((DemoProduct, RoutinePeriod) -> Void)?,
        onBack: (() -> Void)?,
        showsBackButton: Bool,
        showsTabBar: Bool,
        fullScreenFrame: Bool,
        onSelectTab: ((Int) -> Void)?
    ) {
        self.init(
            products: products,
            initialSearchText: "",
            initialCategory: nil,
            onSelectProduct: onSelectProduct,
            onAddToRoutine: onAddToRoutine,
            onBack: onBack,
            showsBackButton: showsBackButton,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onSelectTab: onSelectTab
        )
    }

    // MARK: - Filtering Logic
    public func filteredProducts(for category: DemoProductCategory?, query: String) -> [DemoProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return products.filter { product in
            let matchesCategory = (category == nil) || (product.category == category)
            if trimmed.isEmpty {
                return matchesCategory
            } else {
                let matchesName = product.name.localizedCaseInsensitiveContains(trimmed)
                let matchesBrand = product.brand.localizedCaseInsensitiveContains(trimmed)
                let matchesSubtype = product.subtype.localizedCaseInsensitiveContains(trimmed)
                let matchesCategoryName = product.category.rawValue.localizedCaseInsensitiveContains(trimmed)
                let matchesIngredient = product.ingredients.contains { $0.localizedCaseInsensitiveContains(trimmed) }
                return matchesCategory && (matchesName || matchesBrand || matchesSubtype || matchesCategoryName || matchesIngredient)
            }
        }
    }

    public var filteredProducts: [DemoProduct] {
        filteredProducts(for: selectedCategory, query: searchText)
    }

    public func selectProduct(_ product: DemoProduct) {
        selectedProduct = product
        onSelectProduct?(product)
    }

    public func clearSearch() {
        searchText = ""
        selectedCategory = nil
    }

    // MARK: - Body
    public var body: some View {
        Group {
            if let product = selectedProduct {
                ProductDetailView(
                    product: ProductDatabase.shared.detail(forDemoProduct: product),
                    backTitle: "Catalog",
                    showsTabBar: showsTabBar,
                    fullScreenFrame: fullScreenFrame,
                    onBack: {
                        selectedProduct = nil
                    },
                    onSelectTab: onSelectTab
                )
            } else {
                catalogContent
            }
        }
        .sheet(item: $productForRoutineSheet) { product in
            addToRoutineSheet(for: product)
        }
        .overlay(alignment: .bottom) {
            if let toast = routineToastMessage {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#50578F"))
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: routineToastMessage)
    }

    private var catalogContent: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 12) {
                if showsBackButton {
                    Button(action: {
                        onBack?()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "#50578F"))
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(hex: "#DFD8F5"), lineWidth: 1))
                    }
                    .accessibilityIdentifier("catalog.backButton")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Product Catalog")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "#222538"))
                    Text("\(filteredProducts.count) formulas with ingredient guidance")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: "#7A7E99"))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search input field
            searchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // Category filter chips
            categoryChips
                .padding(.bottom, 12)

            // Catalog list or Empty State
            if filteredProducts.isEmpty {
                emptyResultsView
            } else {
                productList
            }
        }
        .background(Color(hex: "#FAFAFD").ignoresSafeArea())
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "#7A7E99"))

            TextField("Search by name, brand, or ingredient...", text: $searchText)
                .font(.system(size: 14))
                .accessibilityIdentifier("catalog.searchField")

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#7A7E99"))
                }
                .accessibilityIdentifier("catalog.clearSearchButton")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
        )
    }

    // MARK: - Category Filter Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" filter chip
                Button(action: {
                    selectedCategory = nil
                }) {
                    Text("All (\(products.count))")
                        .font(.system(size: 13, weight: selectedCategory == nil ? .bold : .medium))
                        .foregroundStyle(selectedCategory == nil ? Color.white : Color(hex: "#50578F"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selectedCategory == nil
                                ? Color(hex: "#50578F")
                                : Color.white
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color(hex: "#DFD8F5"), lineWidth: selectedCategory == nil ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("catalog.filter.all")

                ForEach(DemoProductCategory.allCases, id: \.self) { category in
                    let count = products.filter { $0.category == category }.count
                    let isSelected = selectedCategory == category

                    Button(action: {
                        if selectedCategory == category {
                            selectedCategory = nil
                        } else {
                            selectedCategory = category
                        }
                    }) {
                        Text("\(category.displayName) (\(count))")
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.white : Color(hex: "#50578F"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                isSelected
                                    ? Color(hex: "#50578F")
                                    : Color.white
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color(hex: "#DFD8F5"), lineWidth: isSelected ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("catalog.filter.\(category.rawValue)")
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Product List
    private var productList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredProducts) { product in
                    productCard(for: product)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Product Card
    private func productCard(for product: DemoProduct) -> some View {
        Button(action: {
            selectProduct(product)
        }) {
            HStack(spacing: 14) {
                categoryThumbnail(for: product.category)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.brand.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#8E92BC"))
                            .tracking(0.5)

                        Spacer()

                        if let spf = product.spf {
                            Text("SPF \(spf)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#E09F67"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#FFF4ED"))
                                .clipShape(Capsule())
                        }
                    }

                    Text(product.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#222538"))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(product.subtype.capitalized + " · " + product.category.displayName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "#7A7E99"))

                    HStack(spacing: 8) {
                        ingredientStatusBadge(for: product)

                        Spacer()

                        // Add to Routine Action Button
                        Button(action: {
                            productForRoutineSheet = product
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Routine")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: "#50578F"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#DFD8F5").opacity(0.8))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("catalog.addToRoutine.\(product.id)")
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalog.productRow.\(product.id)")
    }

    private func categoryThumbnail(for category: DemoProductCategory) -> some View {
        let (icon, color): (String, Color) = {
            switch category {
            case .cleanser:
                return ("drop.fill", Color(hex: "#7C83BC"))
            case .toner:
                return ("sparkles", Color(hex: "#87B38D"))
            case .serum:
                return ("flame.fill", Color(hex: "#E09F67"))
            case .moisturizer:
                return ("cloud.sun.fill", Color(hex: "#729B79"))
            case .sunscreen:
                return ("sun.max.fill", Color(hex: "#DDA15E"))
            case .treatment:
                return ("cross.case.fill", Color(hex: "#B284BE"))
            case .mist:
                return ("wind", Color(hex: "#64B5F6"))
            case .mask:
                return ("theatermasks.fill", Color(hex: "#BA68C8"))
            }
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
        }
    }

    private func ingredientStatusBadge(for product: DemoProduct) -> some View {
        Group {
            switch product.ingredientListStatus {
            case .complete:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#4E937A"))
                    Text("\(product.ingredients.count) ingredients")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#4E937A"))
                }
            case .partial:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#E09F67"))
                    Text("Partial ingredients")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#E09F67"))
                }
            case .unavailable:
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#C05646"))
                    Text("Ingredients unavailable")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#C05646"))
                }
            }
        }
    }

    // MARK: - Empty State (Scenario 3)
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "#DFD8F5").opacity(0.4))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "#50578F"))
            }

            VStack(spacing: 6) {
                Text("No matching products")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#222538"))

                if !searchText.isEmpty {
                    Text("No products match \"\(searchText)\". Try searching by another active ingredient or brand.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#7A7E99"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else if selectedCategory != nil {
                    Text("No products currently cataloged in this category.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#7A7E99"))
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: {
                clearSearch()
            }) {
                Text("Reset Filters")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#50578F"))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                    )
            }
            .accessibilityIdentifier("catalog.emptyStateResetButton")
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add to Routine Sheet
    private func addToRoutineSheet(for product: DemoProduct) -> some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text("Add to Routine")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#222538"))

                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#7A7E99"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button(action: {
                    add(product: product, to: .am)
                    productForRoutineSheet = nil
                }) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(Color(hex: "#E09F67"))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Morning Routine (AM)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "#222538"))
                            Text("Best for cleansers, antioxidants, and daily SPF")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#7A7E99"))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8E92BC"))
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("catalog.addSheet.am")

                Button(action: {
                    add(product: product, to: .pm)
                    productForRoutineSheet = nil
                }) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(Color(hex: "#50578F"))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Evening Routine (PM)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "#222538"))
                            Text("Best for double cleansing, retinoids, and barrier creams")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#7A7E99"))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8E92BC"))
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("catalog.addSheet.pm")
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.height(300)])
    }

    private func add(product: DemoProduct, to period: RoutinePeriod) {
        if let onAddToRoutine = onAddToRoutine {
            onAddToRoutine(product, period)
        } else {
            let cat = ProductCategory(demoCategory: product.category)
            let periodName = period == .am ? "Morning" : "Evening"
            let existing = RoutineStore.shared.routines.first { $0.period == period }
            let nextStepNumber = (existing?.steps.count ?? 0) + 1

            let newStep = RoutineStepItem(
                stepNumber: nextStepNumber,
                title: product.name,
                subtitle: "\(product.brand) · \(cat.rawValue)",
                state: .incomplete,
                hasClash: false,
                productId: UUID()
            )

            if let routine = existing {
                var updated = routine
                updated.steps.append(newStep)
                try? RoutineStore.shared.save(updated)
            } else {
                let newRoutine = RoutineRecord(
                    name: "\(periodName) Routine",
                    period: period,
                    steps: [newStep]
                )
                try? RoutineStore.shared.save(newRoutine)
            }
        }

        routineToastMessage = "Added to \(period == .am ? "AM" : "PM") routine"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            routineToastMessage = nil
        }
    }
}
