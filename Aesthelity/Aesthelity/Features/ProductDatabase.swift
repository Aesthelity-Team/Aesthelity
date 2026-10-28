//
//  ProductDatabase.swift
//  Aesthelity
//
//  Central in-memory product repository and seed registry.
//

import Foundation

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
    private var demoDatabase: [String: ProductDetailItem] = [:]
    
    public init() {
        seedDefaults()
    }
    
    /// Register a product detail item in both ID-indexed and title-indexed stores.
    public func register(_ item: ProductDetailItem) {
        databaseById[item.id] = item
        database[item.title] = item
        if let catalogId = item.catalogId {
            database[catalogId] = item
        }
    }
    
    private func seedDefaults() {
        // 1. Vitamin C Serum
        let vitaminC = ProductDetailItem(
            id: Self.vitaminCID,
            title: "Vitamin C Serum",
            subtitle: "Brightening serum · AM routine",
            brand: "Misticore",
            category: .serum,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Works before SPF", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Do not combine with retinol", badgeText: "Avoid")
            ],
            ingredients: [
                "Water", "3-O-Ethyl Ascorbic Acid", "Niacinamide", "Glycerin",
                "Sodium Hyaluronate", "Ferulic Acid", "Tocopherol", "Phenoxyethanol"
            ],
            ingredientListStatus: .complete,
            ingredientGuidance: "Contains Vitamin C: High-potency antioxidant. Excellent under morning SPF. Avoid mixing with retinol or direct acids in the same application."
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
            ],
            ingredients: ["Water", "Sodium Cocoyl Glycinate", "Glycerin", "Sodium Chloride", "Citric Acid"],
            ingredientListStatus: .complete
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
            ],
            ingredients: ["Water", "Glycerin", "Caprylic/Capric Triglyceride", "Cetearyl Alcohol", "Niacinamide"],
            ingredientListStatus: .complete
        )
        register(hydrabio)
        
        // 3. Toners
        let barrierToner = ProductDetailItem(
            id: Self.barrierBalanceTonerID,
            title: "Barrier Balance Toner",
            subtitle: "Hydrating balance · AM/PM routine",
            brand: "Paula's Choice",
            category: .toner,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Preps skin for active serums", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Restores moisture barrier balance", badgeText: "Best")
            ],
            ingredients: ["Water", "Propanediol", "Centella Asiatica Extract", "Panthenol", "Ceramide NP"],
            ingredientListStatus: .complete
        )
        register(barrierToner)
        database["Barrier Balance Essence Toner"] = barrierToner
        
        let clarifyingToner = ProductDetailItem(
            id: Self.clarifyingTonerID,
            title: "Clarifying Toner",
            subtitle: "Pore refining toner · AM/PM routine",
            brand: "Paula's Choice",
            category: .toner,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Controls excess mid-day oils", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Calms post-cleanse skin", badgeText: "Safe")
            ],
            ingredients: ["Water", "Salicylic Acid", "Hamamelis Virginiana Extract", "Glycerin", "Zinc PCA"],
            ingredientListStatus: .complete,
            ingredientGuidance: "Contains Salicylic Acid (BHA): Exfoliates within pores. Best used in evening routines. Use sunscreen daily."
        )
        register(clarifyingToner)
        database["Clarifying BHA Pore Toner"] = clarifyingToner
        
        let milkToner = ProductDetailItem(
            id: Self.hydratingMilkTonerID,
            title: "Hydrating Milk Toner",
            subtitle: "Ceramide emulsion · AM/PM routine",
            brand: "Rhode",
            category: .toner,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Instant plumping under SPF", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Deeply restorative base layer", badgeText: "Best")
            ],
            ingredients: ["Water", "Glycerin", "Oryza Sativa (Rice) Bran Extract", "Ceramide NP", "Sodium Hyaluronate"],
            ingredientListStatus: .complete
        )
        register(milkToner)
        database["Hydrating Ceramide Milk"] = milkToner
        
        // 4. Sunscreens
        let dailyUV = ProductDetailItem(
            id: Self.dailyUVDefenseID,
            title: "Daily UV Defense SPF 50",
            subtitle: "Protection · AM routine",
            brand: "HistoLab",
            category: .spf,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Crucial final step before sun exposure", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Cleanse thoroughly before bed", badgeText: "Avoid")
            ],
            ingredients: ["Water", "Zinc Oxide", "Titanium Dioxide", "Glycerin", "Caprylic/Capric Triglyceride", "Silica"],
            ingredientListStatus: .complete,
            ingredientGuidance: "Broad-spectrum mineral SPF. Apply liberally 15 minutes before sun exposure and reapply every 2 hours."
        )
        register(dailyUV)
        database["Daily UV Defense SPF 50+"] = dailyUV
        
        let sunBlock = ProductDetailItem(
            id: Self.sunBlockPostCareID,
            title: "Sun Block Post Care SPF 50+",
            subtitle: "Broad spectrum UV barrier · AM routine",
            brand: "HistoLab",
            category: .spf,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Dermatologist shield against UV", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Not formulated for night wear", badgeText: "Avoid")
            ],
            ingredients: ["Water", "Homosalate", "Octocrylene", "Ethylhexyl Salicylate", "Centella Asiatica Extract"],
            ingredientListStatus: .complete
        )
        register(sunBlock)
        database["Sun Block Post Care 365"] = sunBlock
        
        let anthelios = ProductDetailItem(
            id: Self.antheliosUVMeltInID,
            title: "Anthelios UV Melt-In SPF 60",
            subtitle: "Ultralight fluid shield · AM routine",
            brand: "La Roche-Posay",
            category: .spf,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: "Fast-absorbing antioxidant shield", badgeText: "Best"),
                RoutineFitItem(routineName: "PM routine", note: "Remove with evening double cleanse", badgeText: "Avoid")
            ],
            ingredients: ["Water", "Avobenzone", "Homosalate", "Octisalate", "Octocrylene", "Silica", "Glycerin"],
            ingredientListStatus: .complete
        )
        register(anthelios)
        database["Anthelios Melt-in Milk SPF 60"] = anthelios
        
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
            ],
            ingredients: ["Aqua (Water)", "Niacinamide", "Pentylene Glycol", "Zinc PCA", "Dimethyl Isosorbide", "Tamarindus Indica Seed Gum", "Xanthan gum", "Isoceteth-20", "Ethoxydiglycol", "Phenoxyethanol", "Chlorphenesin"],
            ingredientListStatus: .complete,
            ingredientGuidance: "Contains 10% Niacinamide and 1% Zinc PCA to balance visible sebum activity and textural irregularities."
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
            ],
            ingredients: ["Aqua (Water)", "Caffeine", "Maltodextrin", "Glycerin", "Propanediol", "Epigallocatechin Gallatyl Glucoside", "G gallate", "Hyaluronic Acid"],
            ingredientListStatus: .complete,
            ingredientGuidance: "Formulated with 5% high-solubility caffeine to target puffiness and under-eye dark circles."
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
            ],
            ingredients: ["Polybutene", "Mirsalehi Honey", "Hydrolyzed Collagen", "Sodium Hyaluronate", "Tocopherol"],
            ingredientListStatus: .complete
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
            ],
            ingredients: ["Water", "Centella Asiatica Extract", "Spinacia Oleracea Leaf Extract", "Camellia Sinensis Leaf Extract", "Glycerin"],
            ingredientListStatus: .complete,
            ingredientGuidance: "Rich in Centella Asiatica to soothe and prevent redness."
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
            ],
            ingredients: ["Water", "Decyl Glucoside", "Punica Granatum Fruit Extract", "Citric Acid"],
            ingredientListStatus: .complete
        )
        register(foamingMicellar)

        // 9. Load DemoCatalog products into dedicated demo registry
        if let catalog = try? DemoCatalog.load() {
            for demo in catalog.products {
                let item = ProductDetailItem(demoProduct: demo)
                demoDatabase[demo.id] = item
                demoDatabase[demo.name] = item
            }
        }
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
        if let found = demoDatabase[idString] {
            return found
        }
        return nil
    }
    
    public func detail(forDemoProduct demoProduct: DemoProduct) -> ProductDetailItem {
        if let existing = demoDatabase[demoProduct.id] {
            return existing
        }
        let item = ProductDetailItem(demoProduct: demoProduct)
        demoDatabase[demoProduct.id] = item
        return item
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
        if let existingDemo = demoDatabase[title] {
            return existingDemo
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
            for (key, item) in demoDatabase {
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
