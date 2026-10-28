//
//  LibraryView.swift
//  Aesthelity
//
//  Library Screen for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - Library Product & Save Models

public enum ProductCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case cleanser = "Cleanser"
    case toner = "Toner"
    case serum = "Serum"
    case spf = "SPF"
    case moisturizer = "Moisturizer"
    case treatment = "Treatment"
    case oil = "Oil"
    case mask = "Mask"
    case mist = "Mist"
    
    public var id: String { rawValue }

    public init(demoCategory: DemoProductCategory) {
        switch demoCategory {
        case .cleanser: self = .cleanser
        case .serum: self = .serum
        case .treatment: self = .treatment
        case .moisturizer: self = .moisturizer
        case .sunscreen: self = .spf
        case .toner: self = .toner
        case .mist: self = .mist
        case .mask: self = .mask
        }
    }
}

public struct LibraryProductItem: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let brand: String
    public let category: ProductCategory
    
    public init(id: UUID = UUID(), title: String, brand: String, category: ProductCategory) {
        self.id = id
        self.title = title
        self.brand = brand
        self.category = category
    }
}

public struct RecentSaveItem: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let category: ProductCategory
    public let badgeText: String
    
    public init(id: UUID = UUID(), title: String, subtitle: String, category: ProductCategory, badgeText: String = "Safe") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.badgeText = badgeText
    }
}

// MARK: - Thumbnail Graphic View (Minimalist Skincare Tube on Cream Swirl)

struct CosmeticSwirlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.72))
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.28),
            control1: CGPoint(x: rect.width * 0.42, y: rect.height * 0.95),
            control2: CGPoint(x: rect.width * 0.65, y: rect.height * 0.12)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

public struct ProductTubeThumbnailView: View {
    public init() {}
    
    public var body: some View {
        ZStack {
            // Creamy Swirl Background
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.96, green: 0.93, blue: 0.89), Color(red: 0.92, green: 0.88, blue: 0.83)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Soft cosmetic swirl accent
            CosmeticSwirlShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.99, green: 0.96, blue: 0.92), Color(red: 0.94, green: 0.90, blue: 0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.85)
            
            // Minimalist Modern Tube Graphic
            VStack(spacing: 0) {
                // Tube crimp
                Capsule()
                    .fill(Color(white: 0.92))
                    .frame(width: 25, height: 2.5)
                
                // Tube body
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 23, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .stroke(Color(white: 0.88), lineWidth: 0.5)
                    )
                
                // Cap neck
                Rectangle()
                    .fill(Color(white: 0.84))
                    .frame(width: 12, height: 2.5)
                
                // Cap
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 15, height: 9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color(white: 0.78), lineWidth: 0.5)
                    )
            }
            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 2, y: 2)
            .rotationEffect(.degrees(-35))
        }
        .frame(height: 84)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Product Card

public struct LibraryProductCard: View {
    public let product: LibraryProductItem
    
    public init(product: LibraryProductItem) {
        self.product = product
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProductTubeThumbnailView()
            
            Text(product.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(product.brand)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
    }
}

// MARK: - Recent Save Card

public struct RecentSaveCard: View {
    public let save: RecentSaveItem
    
    public init(save: RecentSaveItem) {
        self.save = save
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            // Soft lavender square icon box
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.87, green: 0.85, blue: 0.96)) // #DFD8F5
                .frame(width: 46, height: 46)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(save.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16)) // semanticInkPrimary
                
                Text(save.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47)) // semanticInkSecondary
            }
            
            Spacer()
            
            // Safe pill badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text(save.badgeText)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color(red: 0.18, green: 0.32, blue: 0.14)) // #2E5224
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(red: 0.62, green: 0.74, blue: 0.55)) // #9EBD8D
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Main LibraryView

public struct LibraryView: View {
    public var showsTabBar: Bool
    public var fullScreenFrame: Bool
    public var onSelectTab: ((Int) -> Void)?
    
    // Category & Search Filtering State
    @State public var selectedCategory: ProductCategory
    @State public var searchText: String
    
    // Product Detail Navigation State
    @State public var selectedProductDetail: ProductDetailItem?
    
    // Product Catalog Navigation State
    @State public var showCatalogView: Bool = false
    
    // Data Sources
    @State public var products: [LibraryProductItem] = [
        LibraryProductItem(id: ProductDatabase.sunBlockPostCareID, title: "Sun Block For...", brand: "HistoLab", category: .spf),
        LibraryProductItem(id: ProductDatabase.hydrabioCreamCleanserID, title: "Hydrabio Cre...", brand: "Bioderma", category: .cleanser),
        LibraryProductItem(id: ProductDatabase.superfoodCicaCleanserID, title: "Superfood Ci...", brand: "Besoma", category: .cleanser),
        LibraryProductItem(id: ProductDatabase.honeyGlazeLipMaskID, title: "Honey Glaze Collagen Lip Mask", brand: "Gisou", category: .serum),
        LibraryProductItem(id: ProductDatabase.caffeineSolutionID, title: "Caffeine Solution 5%", brand: "The Ordinary", category: .serum),
        LibraryProductItem(id: ProductDatabase.foamingMicellarWashID, title: "Foaming Mice...", brand: "Alya Skin", category: .cleanser),
        // Additional items for filter expansion
        LibraryProductItem(id: ProductDatabase.clarifyingTonerID, title: "Clarifying Toner", brand: "Paula's Choice", category: .toner),
        LibraryProductItem(id: ProductDatabase.hydratingMilkTonerID, title: "Hydrating Milk Toner", brand: "Rhode", category: .toner),
        LibraryProductItem(id: ProductDatabase.antheliosUVMeltInID, title: "Anthelios UV Melt-In", brand: "La Roche-Posay", category: .spf),
        LibraryProductItem(id: ProductDatabase.niacinamideID, title: "Niacinamide 10%", brand: "The Ordinary", category: .serum)
    ]
    
    @State public var recentSaves: [RecentSaveItem] = [
        RecentSaveItem(id: ProductDatabase.vitaminCID, title: "Vitamin C Serum", subtitle: "Brightening · AM", category: .serum, badgeText: "Safe"),
        RecentSaveItem(id: ProductDatabase.gentleFoamingCleanserID, title: "Gentle Foaming Cleanser", subtitle: "Purifying · AM/PM", category: .cleanser, badgeText: "Safe"),
        RecentSaveItem(id: ProductDatabase.barrierBalanceTonerID, title: "Barrier Balance Toner", subtitle: "Hydrating · AM/PM", category: .toner, badgeText: "Safe"),
        RecentSaveItem(id: ProductDatabase.dailyUVDefenseID, title: "Daily UV Defense SPF 50", subtitle: "Protection · AM", category: .spf, badgeText: "Safe"),
        RecentSaveItem(id: ProductDatabase.niacinamideID, title: "Niacinamide 10% + Zinc 1%", subtitle: "Balancing · PM", category: .serum, badgeText: "Safe")
    ]
    
    public init(
        initialCategory: ProductCategory = .all,
        initialSearchText: String = "",
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        selectedProductDetail: ProductDetailItem? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            initialCategory: initialCategory,
            initialSearchText: initialSearchText,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            selectedProductDetail: selectedProductDetail,
            showCatalogView: false,
            onSelectTab: onSelectTab
        )
    }

    public init(
        initialCategory: ProductCategory = .all,
        initialSearchText: String = "",
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        selectedProductDetail: ProductDetailItem? = nil,
        showCatalogView: Bool,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self._selectedCategory = State(wrappedValue: initialCategory)
        self._searchText = State(wrappedValue: initialSearchText)
        self.showsTabBar = showsTabBar
        self.fullScreenFrame = fullScreenFrame
        self._selectedProductDetail = State(wrappedValue: selectedProductDetail)
        self._showCatalogView = State(wrappedValue: showCatalogView)
        self.onSelectTab = onSelectTab
    }
    
    // Programmatic selection helpers
    public mutating func selectProduct(_ product: LibraryProductItem) {
        _selectedProductDetail = State(wrappedValue: ProductDatabase.shared.detail(for: product))
    }
    
    public mutating func selectRecentSave(_ save: RecentSaveItem) {
        _selectedProductDetail = State(wrappedValue: ProductDatabase.shared.detail(for: save))
    }
    
    // Filtered lists
    public func filteredProducts(for category: ProductCategory? = nil, query: String? = nil) -> [LibraryProductItem] {
        let activeCategory = category ?? selectedCategory
        let activeQuery = query ?? searchText
        let trimmedQuery = activeQuery.trimmingCharacters(in: .whitespaces)
        return products.filter { product in
            let matchesCategory = (activeCategory == .all || product.category == activeCategory)
            if trimmedQuery.isEmpty {
                return matchesCategory
            } else {
                return matchesCategory && (
                    product.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                    product.brand.localizedCaseInsensitiveContains(trimmedQuery)
                )
            }
        }
    }
    
    public var filteredProducts: [LibraryProductItem] {
        filteredProducts(for: selectedCategory, query: searchText)
    }
    
    public func filteredRecentSaves(for category: ProductCategory? = nil, query: String? = nil) -> [RecentSaveItem] {
        let activeCategory = category ?? selectedCategory
        let activeQuery = query ?? searchText
        let trimmedQuery = activeQuery.trimmingCharacters(in: .whitespaces)
        return recentSaves.filter { save in
            let matchesCategory = (activeCategory == .all || save.category == activeCategory)
            if trimmedQuery.isEmpty {
                return matchesCategory
            } else {
                return matchesCategory && (
                    save.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                    save.subtitle.localizedCaseInsensitiveContains(trimmedQuery)
                )
            }
        }
    }
    
    public var filteredRecentSaves: [RecentSaveItem] {
        filteredRecentSaves(for: selectedCategory, query: searchText)
    }
    
    public var body: some View {
        if let detail = selectedProductDetail {
            ProductDetailView(
                product: detail,
                showsTabBar: showsTabBar,
                fullScreenFrame: fullScreenFrame,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProductDetail = nil
                    }
                },
                onSelectTab: onSelectTab
            )
        } else if showCatalogView {
            ProductCatalogView(
                onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCatalogView = false
                    }
                },
                showsBackButton: true,
                showsTabBar: showsTabBar,
                fullScreenFrame: fullScreenFrame,
                onSelectTab: onSelectTab
            )
        } else {
            if fullScreenFrame {
                mainContentVStack
                    .padding(0)
                    .frame(width: 390, height: 844, alignment: .topLeading)
                    .background(Constants.semanticSurfaceCanvas)
            } else {
                mainContentVStack
                    .padding(0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Constants.semanticSurfaceCanvas)
            }
        }
    }
    
    private var mainContentVStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scrollable Content: All content is scrollable
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Section (Canvas surface)
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection
                        catalogBannerButton
                        categoryFilterRow
                        searchBar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(Constants.semanticSurfaceCanvas)
                    
                    // Warm Section (Want to try + Recent saves)
                    VStack(alignment: .leading, spacing: 20) {
                        ManualProductsSection()
                        wantToTrySection
                        recentSavesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, showsTabBar ? 20 : 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Constants.semanticSurfaceBase)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Tab Bar
            if showsTabBar {
                libraryTabBar
            }
        }
    }
    
    // MARK: - 1. Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Library")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11)) // #43281C
            
            Text("Products organized by relationship.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47)) // semanticInkSecondary
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1b. Catalog Banner Button
    private var catalogBannerButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCatalogView = true
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#7C83BC").opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "#50578F"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Product Catalog")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    Text("Browse all skincare formulas & ingredient guidance")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#625478"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#7C83BC"))
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
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.browseCatalogButton")
    }
    
    // MARK: - 2. Category Filter Row (Clickable buttons)
    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProductCategory.allCases) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }) {
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22)) // semanticInkBrand
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category
                                    ? Color(red: 0.96, green: 0.86, blue: 0.77)
                                    : Color(red: 0.99, green: 0.93, blue: 0.88)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedCategory == category
                                            ? Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.35)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library.categoryChip.\(category.rawValue)")
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("library.categoryFilterRow")
    }
    
    // MARK: - 3. Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.6))
            
            TextField("Search your products...", text: $searchText)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                .accessibilityIdentifier("library.searchField")
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.clearSearch")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1)
        )
    }
    
    // MARK: - 4. Want to Try Section (Scrollable Horizontal Carousel)
    private var wantToTrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Want to try")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
            
            if filteredProducts.isEmpty {
                Text("No products match the selected filter.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.7))
                    .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredProducts) { product in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedProductDetail = ProductDatabase.shared.detail(for: product)
                                }
                            }) {
                                LibraryProductCard(product: product)
                                    .frame(width: 140)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("library.productCard.\(product.title)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 5. Recent Saves Section (Vertical Stack of Full-Width Cards)
    private var recentSavesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent saves")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
            
            if filteredRecentSaves.isEmpty {
                Text("No saved products match the selected filter.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.7))
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredRecentSaves) { save in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedProductDetail = ProductDatabase.shared.detail(for: save)
                            }
                        }) {
                            RecentSaveCard(save: save)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library.recentSaveCard.\(save.title)")
                    }
                }
            }
        }
    }
    
    // MARK: - 6. Bottom Tab Bar
    private var libraryTabBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Tab 0: Home
                tabButton(title: "Home", systemImage: "house", isSelected: false, index: 0)
                
                // Tab 1: Library (Active)
                tabButton(title: "Library", systemImage: "books.vertical.fill", isSelected: true, index: 1)
                
                // Tab 2: Scan (Center Elevated Button)
                Button(action: { onSelectTab?(2) }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.49, green: 0.51, blue: 0.74))
                                .frame(width: 56, height: 56)
                                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "viewfinder")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                        }
                        
                        Text("Scan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                // Tab 3: Explore
                tabButton(title: "Explore", systemImage: "magnifyingglass", isSelected: false, index: 3)
                
                // Tab 4: Profile
                tabButton(title: "Profile", systemImage: "person", isSelected: false, index: 4)
            }
            .frame(height: 72)
            
            // Safe Area spacer
            Color.clear
                .frame(height: 16)
        }
        .frame(height: 88)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.97, green: 0.95, blue: 0.93))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(red: 0.85, green: 0.81, blue: 0.94)),
            alignment: .top
        )
    }
    
    private func tabButton(title: String, systemImage: String, isSelected: Bool, index: Int) -> some View {
        Button(action: { onSelectTab?(index) }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color(red: 0.31, green: 0.34, blue: 0.56) : Color(red: 0.44, green: 0.31, blue: 0.22))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color(red: 0.31, green: 0.34, blue: 0.56) : Color(red: 0.44, green: 0.31, blue: 0.22))
                
                if isSelected {
                    Capsule()
                        .fill(Color(red: 0.31, green: 0.34, blue: 0.56))
                        .frame(width: 16, height: 4)
                } else {
                    Color.clear
                        .frame(width: 16, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Library Screen - 390x844 Frame") {
    LibraryView()
        .environmentObject(ManualProductStore())
}
