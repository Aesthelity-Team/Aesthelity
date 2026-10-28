//
//  ProductDetailItem.swift
//  Aesthelity
//
//  Shared data model for Product Details and Routine Fits.
//

import Foundation

/// Item describing how a product fits into morning or evening routines.
public struct RoutineFitItem: Identifiable, Equatable {
    public let id: UUID
    public let routineName: String
    public let note: String
    public let badgeText: String
    
    public init(id: UUID = UUID(), routineName: String, note: String, badgeText: String = "Safe") {
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
    public var ingredients: [String]
    public var ingredientListStatus: IngredientListStatus
    public var ingredientGuidance: String?
    public var spf: Int?
    public var catalogId: String?
    
    public var ingredientsUnavailable: Bool {
        ingredientListStatus == .unavailable
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        brand: String = "Misticore",
        category: ProductCategory = .serum,
        routineFits: [RoutineFitItem] = [],
        isSaved: Bool = false,
        isAvoided: Bool = false,
        productDescription: String? = nil,
        ingredients: [String] = [],
        ingredientListStatus: IngredientListStatus = .complete,
        ingredientGuidance: String? = nil,
        spf: Int? = nil,
        catalogId: String? = nil
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
        self.ingredients = ingredients
        self.ingredientListStatus = ingredientListStatus
        self.ingredientGuidance = ingredientGuidance
        self.spf = spf
        self.catalogId = catalogId
    }

    public init(demoProduct: DemoProduct) {
        let cat = ProductCategory(demoCategory: demoProduct.category)
        let isSpf = demoProduct.category == .sunscreen || demoProduct.spf != nil
        let isCleanser = demoProduct.category == .cleanser
        let isToner = demoProduct.category == .toner
        let isRetinol = demoProduct.id.contains("retinol") || demoProduct.subtype.lowercased().contains("retinol")
        let isVitaminC = demoProduct.id.contains("vitaminc") || demoProduct.name.lowercased().contains("vitamin c")
        let isAha = demoProduct.subtype.lowercased().contains("exfoliating") || demoProduct.id.contains("exfoliating")

        let amNote: String
        let pmNote: String
        let amBadge: String
        let pmBadge: String

        // Category heuristics only — not a safety or suitability assessment.
        if isSpf {
            amNote = "Often used as a daytime final step"
            pmNote = "Usually removed before sleep"
            amBadge = "AM tip"
            pmBadge = "PM tip"
        } else if isRetinol {
            amNote = "Often reserved for evening use"
            pmNote = "Commonly used in evening routines"
            amBadge = "AM tip"
            pmBadge = "PM tip"
        } else if isVitaminC {
            amNote = "Often paired with daytime SPF"
            pmNote = "May conflict with some evening actives"
            amBadge = "AM tip"
            pmBadge = "PM tip"
        } else if isAha {
            amNote = "Can increase sun sensitivity"
            pmNote = "Often used in evening routines"
            amBadge = "AM tip"
            pmBadge = "PM tip"
        } else if isCleanser || isToner {
            amNote = "Common morning step"
            pmNote = "Common evening step"
            amBadge = "AM tip"
            pmBadge = "PM tip"
        } else {
            amNote = "General product category tip only"
            pmNote = "General product category tip only"
            amBadge = "AM tip"
            pmBadge = "PM tip"
        }

        let guidance: String? = {
            switch demoProduct.ingredientListStatus {
            case .unavailable:
                return "Ingredient list unavailable. No safety or clash assessment can be made from this record."
            case .partial:
                return "Ingredient list is partial. Treat category tips as incomplete information, not a suitability judgment."
            case .complete:
                if isRetinol {
                    return "Category tip (not a safety assessment): retinoid-type products are often used in PM routines; daytime SPF is commonly advised."
                }
                if isVitaminC {
                    return "Category tip (not a safety assessment): vitamin C products are often used in AM routines under SPF."
                }
                if isAha {
                    return "Category tip (not a safety assessment): exfoliating acids are often limited to a few PM uses per week."
                }
                if isSpf {
                    return "Category tip (not a safety assessment): sunscreen products are often applied as a final AM step."
                }
                return "Category tip only. This is not a verified suitability or safety assessment."
            }
        }()

        let subtitleText: String
        if let spf = demoProduct.spf {
            subtitleText = "\(demoProduct.subtype.capitalized) · SPF \(spf)"
        } else {
            subtitleText = "\(demoProduct.subtype.capitalized) · \(cat.rawValue)"
        }

        self.init(
            id: CatalogProductIdentity.uuid(forCatalogId: demoProduct.id),
            title: demoProduct.name,
            subtitle: subtitleText,
            brand: demoProduct.brand,
            category: cat,
            routineFits: [
                RoutineFitItem(routineName: "AM routine", note: amNote, badgeText: amBadge),
                RoutineFitItem(routineName: "PM routine", note: pmNote, badgeText: pmBadge)
            ],
            isSaved: false,
            isAvoided: false,
            productDescription: demoProduct.provenance.note.isEmpty ? nil : demoProduct.provenance.note,
            ingredients: demoProduct.ingredients,
            ingredientListStatus: demoProduct.ingredientListStatus,
            ingredientGuidance: guidance,
            spf: demoProduct.spf,
            catalogId: demoProduct.id
        )
    }
}
