//
//  ProductDetailView.swift
//  Aesthelity
//
//  Versatile Product Detail Screen for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - Product Detail & Routine Fit Models

/// Represents how a product fits into a specific routine (AM or PM).
public struct RoutineFitItem: Identifiable, Equatable {
    public let id: UUID
    public let routineName: String
    public let note: String
    public let badgeText: String
    
    public init(
        id: UUID = UUID(),
        routineName: String,
        note: String,
        badgeText: String
    ) {
        self.id = id
        self.routineName = routineName
        self.note = note
        self.badgeText = badgeText
    }
}

/// Comprehensive, database-ready model for skincare products in Aesthelity.
public struct ProductDetailItem: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var subtitle: String
    public var brand: String
    public var category: ProductCategory
    public var routineFits: [RoutineFitItem]
    public var isSaved: Bool
    public var isAvoided: Bool
    public var productDescription: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        brand: String = "Misticore",
        category: ProductCategory = .serum,
        routineFits: [RoutineFitItem] = [],
        isSaved: Bool = false,
        isAvoided: Bool = false,
        productDescription: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.brand = brand
        self.category = category
        self.routineFits = routineFits
        self.isSaved = isSaved
        self.isAvoided = isAvoided
        self.productDescription = productDescription
    }
}

// MARK: - Versatile Product Database & Repository

/// Central repository providing product detail records with database-ready architecture.
public class ProductDatabase {
    public static let shared = ProductDatabase()
    
    // MARK: - Well-Known Stable Product IDs
    public static let vitaminCID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
    public static let gentleFoamingCleanserID = UUID(uuidString: "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")!
    public static let hydrabioCreamCleanserID = UUID(uuidString: "B2C3D4E5-F6A1-4B5C-9D0E-1F2A3B4C5D6E")!
    public static let barrierBalanceTonerID = UUID(uuidString: "C3D4E5F6-A1B2-4C5D-0E1F-2A3B4C5D6E7F")!
    public static let clarifyingTonerID = UUID(uuidString: "D4E5F6A1-B2C3-4D5E-1F2A-3B4C5D6E7F8A")!
    public static let hydratingMilkTonerID = UUID(uuidString: "E5F6A1B2-C3D4-4E5F-2A3B-4C5D6E7F8A9B")!
    public static let dailyUVDefenseID = UUID(uuidString: "F6A1B2C3-D4E5-4F5A-3B4C-5D6E7F8A9B0C")!
    public static let sunBlockPostCareID = UUID(uuidString: "A2B3C4D5-E6F7-4A5B-4C5D-6E7F8A9B0C1D")!
    public static let antheliosUVMeltInID = UUID(uuidString: "B3C4D5E6-F7A8-4B5C-5D6E-7F8A9B0C1D2E")!
    public static let niacinamideID = UUID(uuidString: "C4D5E6F7-A8B9-4C5D-6E7F-8A9B0C1D2E3F")!
    public static let caffeineSolutionID = UUID(uuidString: "D5E6F7A8-B9C0-4D5E-7F8A-9B0C1D2E3F4A")!
    public static let honeyGlazeLipMaskID = UUID(uuidString: "E6F7A8B9-C0D1-4E5F-8A9B-0C1D2E3F4A5B")!
    public static let superfoodCicaCleanserID = UUID(uuidString: "F7A8B9C0-D1E2-4F5A-9B0C-1D2E3F4A5B6C")!
    public static let foamingMicellarWashID = UUID(uuidString: "A3B4C5D6-E7F8-4A5B-0C1D-2E3F4A5B6C7D")!
    
    private var databaseById: [UUID: ProductDetailItem] = [:]
    private var database: [String: ProductDetailItem] = [:]
    
    public init() {
        seedDefaults()
    }
    
    /// Register a product detail item in both ID-indexed and title-indexed stores.
    public func register(_ item: ProductDetailItem) {
        databaseById[item.id] = item
        database[item.title] = item
    }
    
    private func seedDefaults() {
        // 1. Vitamin C Serum (Exact match to design specification)
        let vitaminC = ProductDetailItem(
            id: Self.vitaminCID,
            title: "Vitamin C Serum",
            subtitle: "Brightening serum · AM routine",
            brand: "Misticore",
            category: .serum,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Works before SPF", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Do not combine with retinol", badgeText: "Avoid")
            ]
        )
        register(vitaminC)
        
        // 2. Gentle Foaming Cleanser & Hydrabio Cream Cleanser
        let cleanser = ProductDetailItem(
            id: Self.gentleFoamingCleanserID,
            title: "Gentle Foaming Cleanser",
            subtitle: "Purifying wash · AM/PM routine",
            brand: "Bioderma",
            category: .cleanser,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Removes night oils gently", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "First water-based step", badgeText: "Best")
            ]
        )
        register(cleanser)
        
        let hydrabio = ProductDetailItem(
            id: Self.hydrabioCreamCleanserID,
            title: "Hydrabio Cream Cleanser",
            subtitle: "Moisturizing cleanser · AM/PM routine",
            brand: "Bioderma",
            category: .cleanser,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Preserves skin hydration", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Comfortable rinse-off formula", badgeText: "Best")
            ]
        )
        register(hydrabio)
        
        // 3. Barrier Balance Toner, Clarifying Toner & Hydrating Milk Toner
        let toner = ProductDetailItem(
            id: Self.barrierBalanceTonerID,
            title: "Barrier Balance Toner",
            subtitle: "Hydrating balance · AM/PM routine",
            brand: "Paula's Choice",
            category: .toner,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Preps skin for active serums", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Restores moisture barrier balance", badgeText: "Best")
            ]
        )
        register(toner)
        
        let clarifying = ProductDetailItem(
            id: Self.clarifyingTonerID,
            title: "Clarifying Toner",
            subtitle: "Pore refining toner · AM/PM routine",
            brand: "Paula's Choice",
            category: .toner,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Controls excess mid-day oils", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Calms post-cleanse skin", badgeText: "Safe")
            ]
        )
        register(clarifying)
        
        let hydratingMilk = ProductDetailItem(
            id: Self.hydratingMilkTonerID,
            title: "Hydrating Milk Toner",
            subtitle: "Ceramide emulsion · AM/PM routine",
            brand: "Rhode",
            category: .toner,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Instant plumping under SPF", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Deeply restorative base layer", badgeText: "Best")
            ]
        )
        register(hydratingMilk)
        
        // 4. Daily UV Defense SPF 50, Sun Block Post Care & Anthelios
        let spf = ProductDetailItem(
            id: Self.dailyUVDefenseID,
            title: "Daily UV Defense SPF 50",
            subtitle: "Protection · AM routine",
            brand: "HistoLab",
            category: .spf,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Crucial final step before sun exposure", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Cleanse thoroughly before bed", badgeText: "Avoid")
            ]
        )
        register(spf)
        
        let sunBlock = ProductDetailItem(
            id: Self.sunBlockPostCareID,
            title: "Sun Block Post Care SPF 50+",
            subtitle: "Broad spectrum UV barrier · AM routine",
            brand: "HistoLab",
            category: .spf,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Dermatologist shield against UV", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Not formulated for night wear", badgeText: "Avoid")
            ]
        )
        register(sunBlock)
        
        let anthelios = ProductDetailItem(
            id: Self.antheliosUVMeltInID,
            title: "Anthelios UV Melt-In SPF 60",
            subtitle: "Ultralight fluid shield · AM routine",
            brand: "La Roche-Posay",
            category: .spf,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Fast-absorbing antioxidant shield", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Remove with evening double cleanse", badgeText: "Avoid")
            ]
        )
        register(anthelios)
        
        // 5. Niacinamide 10% + Zinc 1%
        let niacinamide = ProductDetailItem(
            id: Self.niacinamideID,
            title: "Niacinamide 10% + Zinc 1%",
            subtitle: "Balancing · PM routine",
            brand: "The Ordinary",
            category: .serum,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Compatible with daily moisturizer", badgeText: "Safe"),
                RoutineFitItem(routineName: "PM routine", note: "Regulates sebum overnight", badgeText: "Best")
            ]
        )
        register(niacinamide)
        database["Niacinamide 10%"] = niacinamide
        
        // 6. Caffeine Solution 5%
        let caffeine = ProductDetailItem(
            id: Self.caffeineSolutionID,
            title: "Caffeine Solution 5%",
            subtitle: "Depuffing eye serum · AM routine",
            brand: "The Ordinary",
            category: .serum,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Reduces puffiness and dark circles", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Gentle hydration around eye contour", badgeText: "Safe")
            ]
        )
        register(caffeine)
        
        // 7. Honey Glaze Collagen Lip Mask
        let honeyGlaze = ProductDetailItem(
            id: Self.honeyGlazeLipMaskID,
            title: "Honey Glaze Collagen Lip Mask",
            subtitle: "Nourishing lip treatment · PM routine",
            brand: "Gisou",
            category: .serum,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Optional light veil under balm", badgeText: "Safe"),
                RoutineFitItem(routineName: "PM routine", note: "Intense overnight peptide repair", badgeText: "Best")
            ]
        )
        register(honeyGlaze)
        
        // 8. Superfood Cica Cleanser & Foaming Micellar Wash
        let superfoodCica = ProductDetailItem(
            id: Self.superfoodCicaCleanserID,
            title: "Superfood Cica Cleanser",
            subtitle: "Antioxidant wash · AM routine",
            brand: "Besoma",
            category: .cleanser,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Calms redness and wakens skin", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Gentle non-stripping second cleanse", badgeText: "Safe")
            ]
        )
        register(superfoodCica)
        
        let foamingMicellar = ProductDetailItem(
            id: Self.foamingMicellarWashID,
            title: "Foaming Micellar Wash",
            subtitle: "Gentle rinse · AM/PM routine",
            brand: "Alya Skin",
            category: .cleanser,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Refreshes delicate skin", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Water-based second cleanse step", badgeText: "Safe")
            ]
        )
        register(foamingMicellar)
    }
    
    /// All unique products registered in the database.
    public var allProducts: [ProductDetailItem] {
        databaseById.values.sorted { $0.title < $1.title }
    }
    
    /// Look up product detail by UUID.
    public func product(for id: UUID) -> ProductDetailItem? {
        databaseById[id]
    }
    
    /// Look up product detail by UUID.
    public func product(byId id: UUID) -> ProductDetailItem? {
        databaseById[id]
    }
    
    /// Look up product detail by UUID with guaranteed fallback.
    public func detail(for id: UUID) -> ProductDetailItem {
        databaseById[id] ?? fallbackDetail(id: id, title: "Product", brand: "Aesthelity Essentials", category: .serum)
    }
    
    /// Look up product detail by UUID.
    public func detail(forId id: UUID) -> ProductDetailItem? {
        databaseById[id]
    }
    
    /// Look up product detail by String identifier or UUID string.
    public func detail(forId idString: String) -> ProductDetailItem? {
        if let uuid = UUID(uuidString: idString), let found = databaseById[uuid] {
            return found
        }
        if let found = database[idString] {
            return found
        }
        return nil
    }
    
    /// Subscript access by UUID.
    public subscript(id: UUID) -> ProductDetailItem? {
        databaseById[id]
    }
    
    /// Look up or dynamically generate product detail for any title.
    public func detail(forTitle title: String) -> ProductDetailItem {
        if let uuid = UUID(uuidString: title), let item = databaseById[uuid] {
            return item
        }
        if let existing = database[title] {
            return existing
        }
        // Case-insensitive / prefix matching without requiring literal "..." keys
        let cleanTitle = title.replacingOccurrences(of: "...", with: "").trimmingCharacters(in: .whitespaces).lowercased()
        if !cleanTitle.isEmpty {
            for (key, item) in database {
                let keyLower = key.lowercased()
                if keyLower.starts(with: cleanTitle) || cleanTitle.starts(with: keyLower) || keyLower.contains(cleanTitle) {
                    return item
                }
            }
        }
        // Versatile fallback generator
        return fallbackDetail(title: title, brand: "Aesthelity Essentials", category: .serum)
    }
    
    public func detail(for product: LibraryProductItem) -> ProductDetailItem {
        // 1. Look up by product ID first
        if let existing = databaseById[product.id] {
            return existing
        }
        // 2. Look up by title
        if let existing = database[product.title] {
            return existing
        }
        let cleanTitle = product.title.replacingOccurrences(of: "...", with: "").trimmingCharacters(in: .whitespaces).lowercased()
        if !cleanTitle.isEmpty {
            for (key, item) in database {
                let keyLower = key.lowercased()
                if keyLower.starts(with: cleanTitle) || cleanTitle.starts(with: keyLower) || keyLower.contains(cleanTitle) {
                    return item
                }
            }
        }
        return fallbackDetail(id: product.id, title: product.title, brand: product.brand, category: product.category)
    }
    
    public func detail(for save: RecentSaveItem) -> ProductDetailItem {
        // 1. Look up by save ID first
        if let existing = databaseById[save.id] {
            return existing
        }
        // 2. Look up by title
        if let existing = database[save.title] {
            return existing
        }
        let cleanTitle = save.title.replacingOccurrences(of: "...", with: "").trimmingCharacters(in: .whitespaces).lowercased()
        if !cleanTitle.isEmpty {
            for (key, item) in database {
                let keyLower = key.lowercased()
                if keyLower.starts(with: cleanTitle) || cleanTitle.starts(with: keyLower) || keyLower.contains(cleanTitle) {
                    return item
                }
            }
        }
        return fallbackDetail(id: save.id, title: save.title, brand: "Aesthelity", category: save.category)
    }
    
    private func fallbackDetail(id: UUID = UUID(), title: String, brand: String, category: ProductCategory) -> ProductDetailItem {
        let isSpf = category == .spf
        let isCleanser = category == .cleanser
        let isToner = category == .toner
        
        let amNote = isSpf ? "Works before direct UV exposure" : (isCleanser ? "Gentle morning cleanse" : (isToner ? "Preps skin for hydration" : "Works before SPF"))
        let pmNote = isSpf ? "Do not use overnight" : (isCleanser ? "Essential evening cleanse" : (isToner ? "Locks in evening moisture" : "Do not combine with retinol"))
        let pmBadge = isSpf ? "Avoid" : (isCleanser ? "Best" : (isToner ? "Best" : "Avoid"))
        
        return ProductDetailItem(
            id: id,
            title: title,
            subtitle: "\(category.rawValue) formula · AM routine",
            brand: brand,
            category: category,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: amNote, badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: pmNote, badgeText: pmBadge)
            ]
        )
    }
}

// MARK: - Product Arch Hero Illustration

/// Archway niche illustration featuring illuminated architectural portal and serum bottle.
public struct ProductArchHeroView: View {
    public let product: ProductDetailItem
    
    public init(product: ProductDetailItem) {
        self.product = product
    }
    
    public var body: some View {
        ZStack {
            // Warm beige canvas inside the card
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(red: 0.94, green: 0.89, blue: 0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Architectural Glowing Archway Niche
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Outer glowing arch backdrop
                    ArchShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color(red: 0.99, green: 0.94, blue: 0.87)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 156, height: 180)
                        .shadow(color: Color.white.opacity(0.8), radius: 10, x: 0, y: 0)
                        .overlay(
                            ArchShape()
                                .stroke(Color.white.opacity(0.9), lineWidth: 8)
                        )
                    
                    // Circular stone pedestal
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.97, green: 0.95, blue: 0.92),
                                    Color(red: 0.90, green: 0.86, blue: 0.81)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 124, height: 26)
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
                        .offset(y: 8)
                    
                    // Serum Dropper Bottle
                    cosmeticBottleView
                        .offset(y: -4)
                }
            }
            .offset(y: 8)
        }
        .frame(width: 240, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .stroke(Color(red: 0.49, green: 0.51, blue: 0.74), lineWidth: 9) // Periwinkle frame
        )
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
    
    // Procedural Cosmetic Bottle View
    private var cosmeticBottleView: some View {
        VStack(spacing: 0) {
            // Dropper Bulb
            Capsule()
                .fill(Color(white: 0.96))
                .frame(width: 18, height: 18)
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            
            // Dropper Collar
            VStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.92))
                    .frame(width: 22, height: 10)
                
                Rectangle()
                    .fill(Color(white: 0.88))
                    .frame(width: 24, height: 2)
            }
            
            // Dropper Neck
            Rectangle()
                .fill(Color(white: 0.82))
                .frame(width: 14, height: 3)
            
            // Bottle Body
            ZStack {
                // Amber/warm serum glass
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.99, green: 0.96, blue: 0.92),
                                Color(red: 0.97, green: 0.89, blue: 0.79),
                                Color(red: 0.94, green: 0.84, blue: 0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 58, height: 68)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                
                // Cosmetic Label
                VStack(spacing: 2) {
                    Text(product.brand.uppercased().prefix(9))
                        .font(.system(size: 6, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                    
                    VStack(spacing: 1) {
                        Rectangle()
                            .fill(Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.4))
                            .frame(width: 28, height: 1.5)
                        
                        Text("10% Glow Serum")
                            .font(.system(size: 4, weight: .medium))
                            .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                    }
                    
                    VStack(spacing: 1.2) {
                        Rectangle()
                            .fill(Color(red: 0.26, green: 0.16, blue: 0.11).opacity(0.2))
                            .frame(width: 32, height: 1)
                        Rectangle()
                            .fill(Color(red: 0.26, green: 0.16, blue: 0.11).opacity(0.2))
                            .frame(width: 24, height: 1)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
                .frame(width: 44, height: 42)
                .background(Color(red: 0.98, green: 0.93, blue: 0.85).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(red: 0.88, green: 0.82, blue: 0.74), lineWidth: 0.5)
                )
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 3)
    }
}

// MARK: - Arch Shape Helper

struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2.0
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Main ProductDetailView

/// Dedicated screen displaying the product's relationships, AM/PM routine compatibility, and management options.
public struct ProductDetailView: View {
    // State & Properties
    public var product: ProductDetailItem
    public var showsTabBar: Bool
    public var fullScreenFrame: Bool
    public var onBack: (() -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    
    @State private var isSaved: Bool
    @State private var isAvoided: Bool
    
    public init(
        product: ProductDetailItem,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.product = product
        self.showsTabBar = showsTabBar
        self.fullScreenFrame = fullScreenFrame
        self.onBack = onBack
        self.onSelectTab = onSelectTab
        self._isSaved = State(initialValue: product.isSaved)
        self._isAvoided = State(initialValue: product.isAvoided)
    }
    
    /// Look up product directly by UUID ID.
    public init(
        productId: UUID,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        let resolved = ProductDatabase.shared.detail(for: productId)
        self.init(
            product: resolved,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    /// Look up product directly by UUID ID.
    public init(
        id: UUID,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: id,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    /// Look up product directly by String identifier or UUID string.
    public init(
        productId: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        let resolved = ProductDatabase.shared.detail(forId: productId)
            ?? ProductDatabase.shared.detail(forTitle: productId)
        self.init(
            product: resolved,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    /// Look up product directly by String identifier or UUID string.
    public init(
        id: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: id,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    public var body: some View {
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
    
    private var mainContentVStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Navigation Bar (< Library)
                    backButtonSection
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    
                    // Product Header (Title & Subtitle)
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // Centered Hero Image Card
                    HStack {
                        Spacer()
                        ProductArchHeroView(product: product)
                        Spacer()
                    }
                    .padding(.bottom, 22)
                    
                    // Action Buttons: "Save product" and "Avoid"
                    actionButtonsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    // Routine Fit Header Section
                    routineFitHeaderSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    
                    // Routine Fit Cards
                    routineFitCardsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, showsTabBar ? 24 : 36)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Tab Bar
            if showsTabBar {
                productTabBar
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
                    .font(.system(size: 15, weight: .semibold))
                Text("Library")
                    .font(.system(size: 16, weight: .regular))
            }
            .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.58)) // Indigo lavender
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11)) // semanticInkBrand
            
            Text(product.subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22)) // Muted brown
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 3. Action Buttons Section
    private var actionButtonsSection: some View {
        HStack(spacing: 14) {
            // Save Product Button (BrandPill)
            BrandPillButton(isSaved ? "Saved" : "Save product") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSaved.toggle()
                }
            }
            
            // Avoid Button (Secondary / Destructive)
            LabeledButton(
                isAvoided ? "Avoided" : "Avoid",
                variant: isAvoided ? .destructive : .secondary
            ) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isAvoided.toggle()
                }
            }
        }
    }
    
    // MARK: - 4. Routine Fit Header Section
    private var routineFitHeaderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Add to routine")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                
                Text("Having trouble updating?")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.58))
            }
            
            Text("Routine fit")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 5. Routine Fit Cards Section
    private var routineFitCardsSection: some View {
        VStack(spacing: 12) {
            ForEach(product.routineFits) { fit in
                routineFitCard(for: fit)
            }
        }
    }
    
    private func routineFitCard(for fit: RoutineFitItem) -> some View {
        HStack(spacing: 14) {
            // Soft lavender square icon box
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.87, green: 0.85, blue: 0.96)) // #DFD8F5
                .frame(width: 48, height: 48)
            
            // Routine Name & Note
            VStack(alignment: .leading, spacing: 3) {
                Text(fit.routineName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                
                Text(fit.note)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
            }
            
            Spacer()
            
            // Badge Pill
            Text(fit.badgeText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(red: 0.87, green: 0.85, blue: 0.96))
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
    
    // MARK: - 6. Bottom Tab Bar
    private var productTabBar: some View {
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

#Preview("Product Detail - Vitamin C Serum (390x844)") {
    ProductDetailView(
        product: ProductDatabase.shared.detail(forTitle: "Vitamin C Serum")
    )
}
