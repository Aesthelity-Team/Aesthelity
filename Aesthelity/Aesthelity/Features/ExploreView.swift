//
//  ExploreView.swift
//  Aesthelity
//
//  Explore Screen for Aesthelity Skincare Routine Optimizer with Search,
//  Ingredient Intelligence, and Guide Details.
//

import SwiftUI

// MARK: - Guide Tip Model

public struct GuideTip: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    
    public init(id: UUID = UUID(), title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Ingredient Item Model

public struct IngredientItem: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var category: String
    public var benefit: String
    public var routineNote: String
    public var safetyLevel: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        category: String,
        benefit: String,
        routineNote: String,
        safetyLevel: String = "Harmonious"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.benefit = benefit
        self.routineNote = routineNote
        self.safetyLevel = safetyLevel
    }
}

// MARK: - Explore Search Scope

public enum ExploreSearchScope: String, CaseIterable, Identifiable {
    case all = "All"
    case guides = "Guides"
    case ingredients = "Ingredients"
    case products = "Products"
    
    public var id: String { rawValue }
}

// MARK: - Explore Guide Item Model

public struct GuideItem: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var readTime: String
    public var source: String
    public var category: String
    public var tag: String
    public var summary: String
    public var fullContent: String
    public var keyTips: [GuideTip]
    public var relatedProductTitles: [String]
    
    public init(
        id: UUID = UUID(),
        title: String,
        readTime: String = "3 min read",
        source: String = "Skin Intelligence",
        category: String = "Sun Protection",
        tag: String = "GUIDE",
        summary: String = "",
        fullContent: String = "",
        keyTips: [GuideTip] = [],
        relatedProductTitles: [String] = []
    ) {
        self.id = id
        self.title = title
        self.readTime = readTime
        self.source = source
        self.category = category
        self.tag = tag
        self.summary = summary
        self.fullContent = fullContent
        self.keyTips = keyTips
        self.relatedProductTitles = relatedProductTitles
    }
}

// MARK: - Guide Card View

public struct GuideCardView: View {
    public let guide: GuideItem
    public var onRead: (() -> Void)?
    
    public init(guide: GuideItem, onRead: (() -> Void)? = nil) {
        self.guide = guide
        self.onRead = onRead
    }
    
    public var body: some View {
        Button(action: {
            onRead?()
        }) {
            HStack(spacing: 14) {
                // Sage green square icon
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#A3B18A"))
                    .frame(width: 48, height: 48)
                
                // Title & Read metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(guide.readTime) · \(guide.source)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.38))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Dark coffee Read capsule button
                Text("Read")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.40, green: 0.28, blue: 0.20))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.80, blue: 0.84),
                        Color(red: 0.94, green: 0.72, blue: 0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main ExploreView

public struct ExploreView: View {
    // Layout and container flags
    public var showsTabBar: Bool
    public var fullScreenFrame: Bool
    public var onSelectTab: ((Int) -> Void)?
    
    // Search & Filter State
    @State public var searchText: String
    @State public var selectedScope: ExploreSearchScope
    @State public var selectedArticleDetail: ArticleDetailItem?
    @State public var selectedGuide: GuideItem?
    @State public var selectedProductDetail: ProductDetailItem?
    
    // Guide & Ingredient Collections
    @State public var guides: [GuideItem]
    @State public var ingredients: [IngredientItem]
    
    // Color Palette Constants
    private let brandInk = Color(red: 0.26, green: 0.16, blue: 0.11)
    private let mutedInk = Color(red: 0.44, green: 0.31, blue: 0.22)
    private let accentInk = Color(red: 0.31, green: 0.34, blue: 0.56)
    private let lilacBorder = Color(red: 0.49, green: 0.51, blue: 0.74)
    private let peachCardColor = Color(red: 1.00, green: 0.84, blue: 0.73)
    private let hairlineColor = Color(red: 0.85, green: 0.81, blue: 0.94)
    
    // Quick suggestion topics
    private let quickTopics = ["SPF", "Vitamin C", "Niacinamide", "Retinol", "Ceramides", "Cleanser"]
    
    public init(
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        searchText: String = "",
        selectedScope: ExploreSearchScope = .all,
        selectedArticleDetail: ArticleDetailItem? = nil,
        selectedGuide: GuideItem? = nil,
        selectedProductDetail: ProductDetailItem? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.showsTabBar = showsTabBar
        self.fullScreenFrame = fullScreenFrame
        self._searchText = State(initialValue: searchText)
        self._selectedScope = State(initialValue: selectedScope)
        self._selectedArticleDetail = State(initialValue: selectedArticleDetail)
        self._selectedGuide = State(initialValue: selectedGuide)
        self._selectedProductDetail = State(initialValue: selectedProductDetail)
        self.onSelectTab = onSelectTab
        
        // Seed default comprehensive guides including SPF over serum
        self._guides = State(initialValue: Self.defaultGuides)
        self._ingredients = State(initialValue: Self.defaultIngredients)
    }
    
    // MARK: - Search Filtering Logic
    
    public var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var isSearching: Bool {
        !trimmedQuery.isEmpty
    }
    
    public var filteredGuides: [GuideItem] {
        guard isSearching else { return guides }
        let query = trimmedQuery.lowercased()
        return guides.filter { guide in
            guide.title.localizedCaseInsensitiveContains(query) ||
            guide.source.localizedCaseInsensitiveContains(query) ||
            guide.summary.localizedCaseInsensitiveContains(query) ||
            guide.category.localizedCaseInsensitiveContains(query) ||
            guide.tag.localizedCaseInsensitiveContains(query) ||
            guide.keyTips.contains { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
        }
    }
    
    public var filteredIngredients: [IngredientItem] {
        guard isSearching else { return ingredients }
        let query = trimmedQuery.lowercased()
        return ingredients.filter { ing in
            ing.name.localizedCaseInsensitiveContains(query) ||
            ing.category.localizedCaseInsensitiveContains(query) ||
            ing.benefit.localizedCaseInsensitiveContains(query) ||
            ing.routineNote.localizedCaseInsensitiveContains(query)
        }
    }
    
    public var filteredProducts: [ProductDetailItem] {
        guard isSearching else { return ProductDatabase.shared.allProducts }
        let query = trimmedQuery.lowercased()
        return ProductDatabase.shared.allProducts.filter { product in
            product.title.localizedCaseInsensitiveContains(query) ||
            product.subtitle.localizedCaseInsensitiveContains(query) ||
            product.brand.localizedCaseInsensitiveContains(query) ||
            product.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }
    
    public var totalResultsCount: Int {
        switch selectedScope {
        case .all:
            return filteredGuides.count + filteredIngredients.count + filteredProducts.count
        case .guides:
            return filteredGuides.count
        case .ingredients:
            return filteredIngredients.count
        case .products:
            return filteredProducts.count
        }
    }
    
    // MARK: - Body View
    
    public var body: some View {
        if let product = selectedProductDetail {
            ProductDetailView(
                product: product,
                showsTabBar: showsTabBar,
                fullScreenFrame: fullScreenFrame,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProductDetail = nil
                    }
                },
                onSelectTab: onSelectTab
            )
        } else if let article = selectedArticleDetail {
            ArticleDetailView(
                article: article,
                showsTabBar: showsTabBar,
                fullScreenFrame: fullScreenFrame,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedArticleDetail = nil
                    }
                },
                onSelectTab: onSelectTab,
                onSelectProduct: { product in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProductDetail = product
                    }
                }
            )
        } else if let guide = selectedGuide {
            guideDetailView(for: guide)
        } else {
            mainExploreView
        }
    }
    
    // MARK: - Main Explore View
    
    private var mainExploreView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // Search Bar
                    searchBar
                    
                    // Search Scope Pills
                    searchScopePills
                    
                    if !isSearching {
                        // Quick Suggestions / Popular Topics
                        quickTopicsSection
                        
                        // Featured Guide Card
                        featuredGuideCard
                        
                        // Guide Cards List
                        guideCardsList
                    } else {
                        // Search Results Section
                        searchResultsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, showsTabBar ? 24 : 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Tab Bar
            if showsTabBar {
                exploreTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.semanticSurfaceCanvas)
    }
    
    // MARK: - 1. Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Explore")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.20))
            
            Text("Learn skincare science and routine basics.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.30))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 2. Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
            
            TextField("Search ingredients and products...", text: $searchText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hairlineColor, lineWidth: 1.5)
        )
    }
    
    // MARK: - 3. Search Scope Pills
    private var searchScopePills: some View {
        HStack(spacing: 8) {
            ForEach(ExploreSearchScope.allCases) { scope in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selectedScope = scope
                    }
                }) {
                    Text(scope.rawValue)
                        .font(.system(size: 13, weight: selectedScope == scope ? .semibold : .medium))
                        .foregroundStyle(selectedScope == scope ? Color.white : accentInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedScope == scope
                                ? accentInk
                                : Color.white
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedScope == scope ? Color.clear : hairlineColor, lineWidth: 1.2)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
    
    // MARK: - 4. Quick Suggestions / Popular Topics
    private var quickTopicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Popular Searches")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mutedInk)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickTopics, id: \.self) { topic in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                searchText = topic
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(accentInk)
                                Text(topic)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(brandInk)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(hairlineColor, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Featured Guide Card
    private var featuredGuideCard: some View {
        Button(action: {
            if let spfGuide = guides.first(where: { $0.title.contains("SPF") }) {
                openGuide(spfGuide)
            } else if let first = guides.first {
                openGuide(first)
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("FEATURED GUIDE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(mutedInk)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(mutedInk)
                }
                
                Text("How to Layer SPF Over Serum Without Pilling")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(brandInk)
                    .lineSpacing(2)
                
                Text("Skin Intelligence · 3 min read")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accentInk)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(peachCardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 6. Guide Cards List
    private var guideCardsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Research Guides")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(brandInk)
            
            VStack(spacing: 12) {
                ForEach(guides) { guide in
                    GuideCardView(guide: guide) {
                        openGuide(guide)
                    }
                }
            }
        }
    }
    
    // MARK: - 7. Search Results Section
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Results Summary
            HStack {
                Text("Results for \"\(trimmedQuery)\"")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(brandInk)
                
                Spacer()
                
                Text("\(totalResultsCount) found")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(hairlineColor, lineWidth: 1)
                    )
            }
            
            if totalResultsCount == 0 {
                emptySearchState
            } else {
                // Section: Guides
                if (selectedScope == .all || selectedScope == .guides) && !filteredGuides.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Guides (\(filteredGuides.count))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(brandInk)
                        
                        ForEach(filteredGuides) { guide in
                            GuideCardView(guide: guide) {
                                openGuide(guide)
                            }
                        }
                    }
                }
                
                // Section: Ingredients & Actives
                if (selectedScope == .all || selectedScope == .ingredients) && !filteredIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients & Actives (\(filteredIngredients.count))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(brandInk)
                        
                        ForEach(filteredIngredients) { ing in
                            ingredientCard(for: ing)
                        }
                    }
                }
                
                // Section: Products
                if (selectedScope == .all || selectedScope == .products) && !filteredProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Products (\(filteredProducts.count))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(brandInk)
                        
                        ForEach(filteredProducts) { product in
                            productSearchCard(for: product)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Open Guide Helper
    private func openGuide(_ guide: GuideItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if guide.title.contains("SPF") {
                selectedArticleDetail = .example
            } else {
                selectedArticleDetail = ArticleDetailItem(
                    badge: guide.tag,
                    title: guide.title,
                    metadata: "\(guide.source) · \(guide.readTime)",
                    introduction: guide.summary,
                    tips: guide.keyTips.map { ArticleTipItem(title: $0.title, subtitle: $0.subtitle) },
                    relatedProducts: guide.relatedProductTitles.map { title in
                        ArticleProductItem(
                            title: title,
                            subtitle: ProductDatabase.shared.detail(forTitle: title).subtitle
                        )
                    }
                )
            }
        }
    }
    
    // MARK: - Ingredient Card
    private func ingredientCard(for ing: IngredientItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(ing.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(brandInk)
                
                Spacer()
                
                Text(ing.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accentInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.88, green: 0.86, blue: 0.95))
                    .clipShape(Capsule())
            }
            
            Text(ing.benefit)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                .lineLimit(2)
            
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#A3B18A"))
                
                Text(ing.routineNote)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(mutedInk)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(lilacBorder, lineWidth: 1.2)
        )
    }
    
    // MARK: - Product Search Card
    private func productSearchCard(for product: ProductDetailItem) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProductDetail = product
            }
        }) {
            HStack(spacing: 14) {
                // Peach rounded square icon
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(peachCardColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundStyle(mutedInk)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(brandInk)
                        .lineLimit(1)
                    
                    Text("\(product.brand) · \(product.category.rawValue.capitalized)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(accentInk)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(lilacBorder)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(lilacBorder, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(accentInk.opacity(0.7))
                .padding(.top, 24)
            
            Text("No results for \"\(trimmedQuery)\"")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(brandInk)
            
            Text("Try searching for SPF, Vitamin C, Niacinamide, Retinol, or Cleanser.")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.38))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    searchText = ""
                }
            }) {
                Text("Clear Search")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.40, green: 0.28, blue: 0.20))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(hairlineColor, lineWidth: 1)
        )
    }
    
    // MARK: - 8. Guide Detail View (Pixel-perfect match to user screenshot)
    public func guideDetailView(for guide: GuideItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Navigation Bar (< Explore)
                    guideBackButton
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    
                    // Main Peach Guide Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(guide.tag.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(mutedInk)
                        
                        Text(guide.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(brandInk)
                            .lineSpacing(2)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(peachCardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.bottom, 16)
                    
                    // Metadata: Source · Read Time
                    Text("\(guide.source) · \(guide.readTime)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(accentInk)
                        .padding(.bottom, 14)
                    
                    // Hairline Divider
                    Rectangle()
                        .fill(hairlineColor)
                        .frame(height: 1)
                        .padding(.bottom, 16)
                    
                    // Summary / Dilemma Text
                    Text(guide.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(brandInk)
                        .lineSpacing(4)
                        .padding(.bottom, 24)
                    
                    // Key Tips Section
                    if !guide.keyTips.isEmpty {
                        Text("Key Tips")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(brandInk)
                            .padding(.bottom, 14)
                        
                        VStack(spacing: 12) {
                            ForEach(guide.keyTips) { tip in
                                keyTipCard(for: tip)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    
                    // Related Products Section
                    if !guide.relatedProductTitles.isEmpty {
                        Text("Related Products")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(brandInk)
                            .padding(.bottom, 14)
                        
                        VStack(spacing: 12) {
                            ForEach(guide.relatedProductTitles, id: \.self) { productTitle in
                                relatedProductCard(for: productTitle)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    
                    // Clinical Guidance & Notes
                    if !guide.fullContent.isEmpty {
                        Text("Clinical Guidance")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(brandInk)
                            .padding(.bottom, 12)
                        
                        Text(guide.fullContent)
                            .font(.system(size: 14))
                            .foregroundStyle(brandInk)
                            .lineSpacing(5)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(hairlineColor, lineWidth: 1)
                            )
                            .padding(.bottom, showsTabBar ? 24 : 36)
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Tab Bar
            if showsTabBar {
                exploreTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.semanticSurfaceCanvas)
    }
    
    // MARK: - Guide Back Button (< Explore)
    private var guideBackButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedGuide = nil
                selectedArticleDetail = nil
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                Text("Explore")
                    .font(.system(size: 16, weight: .regular))
            }
            .foregroundStyle(mutedInk)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Key Tip Card (Matches Peach Square Icon & Lavender Border)
    private func keyTipCard(for tip: GuideTip) -> some View {
        HStack(spacing: 14) {
            // Peach rounded rectangle icon
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(peachCardColor)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(brandInk)
                
                Text(tip.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(accentInk)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(lilacBorder, lineWidth: 1.2)
        )
    }
    
    // MARK: - Related Product Card
    private func relatedProductCard(for title: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProductDetail = ProductDatabase.shared.detail(forTitle: title)
            }
        }) {
            HStack(spacing: 14) {
                // Peach rounded rectangle icon
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(peachCardColor)
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(brandInk)
                    
                    Text(ProductDatabase.shared.detail(forTitle: title).subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(lilacBorder)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(lilacBorder, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Tab Bar
    private var exploreTabBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Tab 0: Home
                tabButton(title: "Home", systemImage: "house", isSelected: false, index: 0)
                
                // Tab 1: Library
                tabButton(title: "Library", systemImage: "books.vertical", isSelected: false, index: 1)
                
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
                            .foregroundStyle(mutedInk)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                // Tab 3: Explore (Active)
                tabButton(title: "Explore", systemImage: "magnifyingglass", isSelected: true, index: 3)
                
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
                .foregroundStyle(hairlineColor),
            alignment: .top
        )
    }
    
    private func tabButton(title: String, systemImage: String, isSelected: Bool, index: Int) -> some View {
        Button(action: { onSelectTab?(index) }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? accentInk : mutedInk)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? accentInk : mutedInk)
                
                if isSelected {
                    Capsule()
                        .fill(accentInk)
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

// MARK: - Default Guide & Ingredient Collections

extension ExploreView {
    public static let defaultGuides: [GuideItem] = [
        GuideItem(
            title: "How to Layer SPF Over Serum Without Pilling",
            readTime: "3 min read",
            source: "Skin Intelligence",
            category: "Sun Protection",
            tag: "GUIDE",
            summary: "The SPF-over-serum dilemma is one of the most common questions in skincare. Here's what the research says about layering order and wait time.",
            fullContent: "Applying sunscreen over serums without pilling requires understanding formulation compatibility and absorption timing. When active water-based serums aren't fully absorbed, sunscreen polymers can ball up on the surface.\n\nAlways allow 60 seconds for serums to sink in completely. When applying SPF, pat gently across the skin rather than vigorously rubbing. Mineral SPFs containing zinc oxide or titanium dioxide tend to pill less over high-potency actives like Vitamin C or Hyaluronic Acid.",
            keyTips: [
                GuideTip(title: "Wait 60s", subtitle: "Let serum fully absorb before SPF"),
                GuideTip(title: "Pat, don't rub", subtitle: "Rubbing disrupts the serum layer"),
                GuideTip(title: "Mineral SPF", subtitle: "Less likely to pill over actives")
            ],
            relatedProductTitles: ["Vitamin C Serum", "Daily UV Defense SPF 50"]
        ),
        GuideItem(
            title: "How to layer actives safely",
            readTime: "5 min read",
            source: "Dermatologist Editorial",
            category: "Routine Order",
            tag: "FEATURED GUIDE",
            summary: "The fundamental rule of layering actives is consistency and pH. Cleanse thoroughly without stripping lipids.",
            fullContent: "1. Cleanse thoroughly without stripping lipids.\n2. Apply thinnest water-based serums first (e.g., Vitamin C, Niacinamide, Hyaluronic Acid).\n3. Allow low-pH actives 1-2 minutes to absorb before applying higher-pH creams.\n4. Lock in hydration with a barrier moisturizer containing ceramides.\n5. Always finish morning routines with broad-spectrum SPF 46+.",
            keyTips: [
                GuideTip(title: "Thinnest to thickest", subtitle: "Water-based formulations before oil or lipid creams"),
                GuideTip(title: "Respect pH windows", subtitle: "Allow 1-2 minutes for active absorption"),
                GuideTip(title: "Separate conflicts", subtitle: "Vitamin C in AM, Retinol in PM")
            ],
            relatedProductTitles: ["Vitamin C Serum", "Niacinamide 10% + Zinc 1%"]
        ),
        GuideItem(
            title: "Niacinamide guide",
            readTime: "5 min read",
            source: "Research Hub",
            category: "Barrier Support",
            tag: "GUIDE",
            summary: "Niacinamide (Vitamin B3) is a versatile water-soluble active that fortifies lipid barriers and regulates sebum.",
            fullContent: "Niacinamide (Vitamin B3) supports ceramide production and strengthens skin barrier resilience. It pairs smoothly with hydrating toners and gentle cleansers, and works effectively across both morning and nighttime regimens.",
            keyTips: [
                GuideTip(title: "2% to 5% optimum", subtitle: "Peak barrier recovery without flushing"),
                GuideTip(title: "High compatibility", subtitle: "Harmonious with Hyaluronic Acid and Ceramides"),
                GuideTip(title: "Day & night versatility", subtitle: "Safe across both morning and evening routines")
            ],
            relatedProductTitles: ["Niacinamide 10% + Zinc 1%", "Gentle Foaming Cleanser"]
        ),
        GuideItem(
            title: "Retinol Beginner Tips",
            readTime: "5 min read",
            source: "Research Hub",
            category: "Cellular Renewal",
            tag: "GUIDE",
            summary: "A complete guide on introducing retinoids slowly, utilizing the moisturizer sandwich technique.",
            fullContent: "Start with 1 to 2 evenings per week. Buffer by applying moisturizer before and after your retinoid. Never mix directly with Vitamin C or exfoliating AHAs/BHAs in the same routine period.",
            keyTips: [
                GuideTip(title: "Moisturizer sandwich", subtitle: "Moisturizer, retinol, then moisturizer"),
                GuideTip(title: "Gradual introduction", subtitle: "Start 1-2 nights weekly to build tolerance"),
                GuideTip(title: "PM exclusive", subtitle: "UV light degrades retinoid stability")
            ],
            relatedProductTitles: ["Barrier Balance Toner", "Gentle Foaming Cleanser"]
        ),
        GuideItem(
            title: "Vitamin C & Sun Protection",
            readTime: "4 min read",
            source: "Research Hub",
            category: "Antioxidants",
            tag: "GUIDE",
            summary: "Why L-ascorbic acid and UV filters form an unmatched synergy against photoaging.",
            fullContent: "L-ascorbic acid provides antioxidant photoprotection that neutralizes reactive oxygen species created when ultraviolet radiation penetrates sunscreen filters.",
            keyTips: [
                GuideTip(title: "Double photoprotection", subtitle: "Vitamin C neutralizes free radicals SPF misses"),
                GuideTip(title: "Apply to dry skin", subtitle: "Allows optimal ascorbic acid absorption"),
                GuideTip(title: "Follow with SPF 50", subtitle: "Shields newly applied antioxidants")
            ],
            relatedProductTitles: ["Vitamin C Serum", "Daily UV Defense SPF 50"]
        ),
        GuideItem(
            title: "Ceramide Barrier Guide",
            readTime: "6 min read",
            source: "Research Hub",
            category: "Moisture Barrier",
            tag: "GUIDE",
            summary: "The fundamental 3:1:1 physiological ratio of ceramides, cholesterol, and fatty acids.",
            fullContent: "Intercellular matrix replenishment prevents transepidermal water loss and restores natural lipid barriers after chemical exfoliation.",
            keyTips: [
                GuideTip(title: "3:1:1 lipid ratio", subtitle: "Ceramides, cholesterol, and fatty acids"),
                GuideTip(title: "Prevent TEWL", subtitle: "Locks in deep moisture across epidermal layers"),
                GuideTip(title: "Post-actives repair", subtitle: "Calms and restores skin barrier after acids")
            ],
            relatedProductTitles: ["Barrier Balance Toner", "Hydrating Milk Toner"]
        )
    ]
    
    public static let defaultIngredients: [IngredientItem] = [
        IngredientItem(
            name: "Zinc Oxide (Mineral SPF)",
            category: "Sun Protection",
            benefit: "Physical blocker that reflects UVA/UVB rays without chemical heat absorption.",
            routineNote: "Final morning step; pat gently over absorbed serums.",
            safetyLevel: "Harmonious"
        ),
        IngredientItem(
            name: "Vitamin C (L-Ascorbic Acid)",
            category: "Antioxidant",
            benefit: "Neutralizes ambient free radicals, boosts collagen synthesis, and brightens tone.",
            routineNote: "Best in AM before SPF; avoid combining directly with Retinol.",
            safetyLevel: "Routine Caution"
        ),
        IngredientItem(
            name: "Niacinamide (Vitamin B3)",
            category: "Barrier Support",
            benefit: "Regulates sebum flow, refines pore structure, and reinforces ceramide synthesis.",
            routineNote: "Compatible with both AM and PM routines; pairs well with Hyaluronic Acid.",
            safetyLevel: "Harmonious"
        ),
        IngredientItem(
            name: "Retinol (Vitamin A)",
            category: "Cellular Renewal",
            benefit: "Accelerates epidermal cell turnover and stimulates deep collagen production.",
            routineNote: "PM only; buffer with ceramides and avoid AHA/BHA in same step.",
            safetyLevel: "Routine Caution"
        ),
        IngredientItem(
            name: "Ceramides (NP, AP, EOP)",
            category: "Moisture Barrier",
            benefit: "Forms the protective intercellular lipid cement to prevent trans-epidermal moisture loss.",
            routineNote: "Universal compatibility across all AM/PM routine steps.",
            safetyLevel: "Harmonious"
        ),
        IngredientItem(
            name: "Hyaluronic Acid",
            category: "Hydration Booster",
            benefit: "Multi-molecular weight humectant drawing moisture deep into the dermis.",
            routineNote: "Apply to damp skin before sealants or moisturizers.",
            safetyLevel: "Harmonious"
        ),
        IngredientItem(
            name: "Salicylic Acid (BHA)",
            category: "Pore Clearing",
            benefit: "Lipid-soluble beta hydroxy acid clearing congestion within follicular walls.",
            routineNote: "Use 2-3 nights per week; separate from retinol and potent Vitamin C.",
            safetyLevel: "Routine Caution"
        )
    ]
}

// MARK: - Previews

#Preview("Explore Screen - 390x844 Frame") {
    ExploreView()
}

#Preview("Explore Screen - Article Detail (SPF Over Serum)") {
    ExploreView(selectedArticleDetail: .example)
}
