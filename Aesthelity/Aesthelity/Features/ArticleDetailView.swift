//
//  ArticleDetailView.swift
//  Aesthelity
//
//  Article & Guide Detail Screen for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - Article Models

/// Item representing a key tip or takeaway within an article.
public struct ArticleTipItem: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var subtitle: String
    
    public init(id: UUID = UUID(), title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

/// Item representing a related product suggested by an article.
public struct ArticleProductItem: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var subtitle: String
    
    public init(id: UUID = UUID(), title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

/// Comprehensive model for articles and guides in Aesthelity.
public struct ArticleDetailItem: Identifiable, Equatable {
    public let id: UUID
    public var badge: String
    public var title: String
    public var metadata: String
    public var introduction: String
    public var tips: [ArticleTipItem]
    public var relatedProducts: [ArticleProductItem]
    
    public init(
        id: UUID = UUID(),
        badge: String = "GUIDE",
        title: String,
        metadata: String,
        introduction: String,
        tips: [ArticleTipItem] = [],
        relatedProducts: [ArticleProductItem] = []
    ) {
        self.id = id
        self.badge = badge
        self.title = title
        self.metadata = metadata
        self.introduction = introduction
        self.tips = tips
        self.relatedProducts = relatedProducts
    }
    
    /// Default example article exactly matching the design specification.
    public static let example = ArticleDetailItem(
        badge: "GUIDE",
        title: "How to Layer SPF Over\nSerum Without Pilling",
        metadata: "Skin Intelligence · 3 min read",
        introduction: "The SPF-over-serum dilemma is one of the most common questions in skincare. Here's what the research says about layering order and wait time.",
        tips: [
            ArticleTipItem(
                title: "Wait 60s",
                subtitle: "Let serum fully absorb before SPF"
            ),
            ArticleTipItem(
                title: "Pat, don't rub",
                subtitle: "Rubbing disrupts the serum layer"
            ),
            ArticleTipItem(
                title: "Mineral SPF",
                subtitle: "Less likely to pill over actives"
            )
        ],
        relatedProducts: [
            ArticleProductItem(
                id: ProductDatabase.vitaminCID,
                title: "Vitamin C Serum",
                subtitle: "Brightening serum · AM routine"
            ),
            ArticleProductItem(
                id: ProductDatabase.dailyUVDefenseID,
                title: "Daily UV Defense SPF 50",
                subtitle: "Broad spectrum protection · AM routine"
            ),
            ArticleProductItem(
                id: ProductDatabase.hydrabioCreamCleanserID,
                title: "Hydrabio Cream Cleanser",
                subtitle: "Gentle morning base · AM routine"
            )
        ]
    )
}

// MARK: - Main ArticleDetailView

/// Dedicated screen displaying full article details, key tips, and related products.
public struct ArticleDetailView: View {
    // Properties
    public var article: ArticleDetailItem
    public var showsTabBar: Bool
    public var fullScreenFrame: Bool
    public var onBack: (() -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    public var onSelectProduct: ((ProductDetailItem) -> Void)?
    
    // Internal State
    @State private var selectedProductDetail: ProductDetailItem?
    
    public init(
        article: ArticleDetailItem = .example,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil,
        onSelectProduct: ((ProductDetailItem) -> Void)? = nil
    ) {
        self.article = article
        self.showsTabBar = showsTabBar
        self.fullScreenFrame = fullScreenFrame
        self.onBack = onBack
        self.onSelectTab = onSelectTab
        self.onSelectProduct = onSelectProduct
    }
    
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
        } else {
            if fullScreenFrame {
                mainContentVStack
                    .padding(0)
                    .frame(width: 390, height: 844, alignment: .topLeading)
                    .background(Constants.semanticSurfaceBase)
            } else {
                mainContentVStack
                    .padding(0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Constants.semanticSurfaceBase)
            }
        }
    }
    
    private var mainContentVStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Navigation Bar (< Explore)
                    backButtonSection
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                    
                    // 2. Guide Hero Card
                    guideHeroCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // 3. Metadata & Separator & Intro
                    articleIntroSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // 4. Key Tips Section
                    keyTipsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    // 5. Related Products Section
                    relatedProductsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, showsTabBar ? 24 : 36)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Tab Bar
            if showsTabBar {
                articleTabBar
            }
        }
    }
    
    // MARK: - 1. Back Button Section
    private var backButtonSection: some View {
        Button(action: {
            onBack?()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Explore")
                    .font(.system(size: 16, weight: .regular))
            }
            .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.20))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Guide Hero Card
    private var guideHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(article.badge)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.20))
            
            Text(article.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.20))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(red: 1.00, green: 0.81, blue: 0.64))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    // MARK: - 3. Article Intro Section
    private var articleIntroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(article.metadata)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
            
            Rectangle()
                .fill(Color(red: 0.85, green: 0.81, blue: 0.94))
                .frame(height: 1)
            
            Text(article.introduction)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.20))
                .lineSpacing(4)
                .padding(.top, 2)
        }
    }
    
    // MARK: - 4. Key Tips Section
    private var keyTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Tips")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.20))
            
            VStack(spacing: 12) {
                ForEach(article.tips) { tip in
                    tipCardView(tip: tip)
                }
            }
        }
    }
    
    private func tipCardView(tip: ArticleTipItem) -> some View {
        HStack(spacing: 14) {
            // Soft peach icon placeholder
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.85, blue: 0.71),
                            Color(red: 1.00, green: 0.80, blue: 0.63)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                
                Text(tip.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.7), lineWidth: 1.2)
        )
    }
    
    // MARK: - 5. Related Products Section
    private var relatedProductsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Products")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.20))
            
            VStack(spacing: 12) {
                ForEach(article.relatedProducts) { product in
                    relatedProductCardView(product: product)
                }
            }
        }
    }
    
    private func relatedProductCardView(product: ArticleProductItem) -> some View {
        Button(action: {
            let detail = ProductDatabase.shared.product(for: product.id)
                ?? ProductDatabase.shared.detail(forTitle: product.title)
            if let onSelectProduct = onSelectProduct {
                onSelectProduct(detail)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedProductDetail = detail
                }
            }
        }) {
            HStack(spacing: 14) {
                // Soft peach icon placeholder
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.85, blue: 0.71),
                                Color(red: 1.00, green: 0.80, blue: 0.63)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                        .lineLimit(1)
                    
                    Text(product.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.7), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 6. Bottom Tab Bar
    private var articleTabBar: some View {
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
                            .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                // Tab 3: Explore (Selected)
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
                .foregroundStyle(Color(red: 0.85, green: 0.81, blue: 0.94)),
            alignment: .top
        )
    }
    
    private func tabButton(title: String, systemImage: String, isSelected: Bool, index: Int) -> some View {
        Button(action: {
            if index == 3 {
                onBack?()
            } else {
                onSelectTab?(index)
            }
        }) {
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

#Preview("Example Article Details - 390x844 Frame") {
    ArticleDetailView()
}
