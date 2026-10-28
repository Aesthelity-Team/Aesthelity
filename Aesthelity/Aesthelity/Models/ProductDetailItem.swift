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

        if isSpf {
            amNote = "Crucial final step before sun exposure"
            pmNote = "Remove thoroughly before sleep"
            amBadge = "Best"
            pmBadge = "Avoid"
        } else if isRetinol {
            amNote = "Degrades in UV light; causes sun sensitivity"
            pmNote = "Promotes overnight cellular renewal"
            amBadge = "Avoid"
            pmBadge = "Best"
        } else if isVitaminC {
            amNote = "Antioxidant protection under SPF"
            pmNote = "Avoid combining with evening retinol"
            amBadge = "Best"
            pmBadge = "Avoid"
        } else if isAha {
            amNote = "Increases photosensitivity; use SPF if worn in day"
            pmNote = "Exfoliates surface cells overnight"
            amBadge = "Caution"
            pmBadge = "Best"
        } else if isCleanser {
            amNote = "Gentle morning cleanse"
            pmNote = "Essential evening cleanse"
            amBadge = "Best"
            pmBadge = "Best"
        } else if isToner {
            amNote = "Preps skin for daytime hydration"
            pmNote = "Restores post-cleanse barrier balance"
            amBadge = "Best"
            pmBadge = "Best"
        } else {
            amNote = "Nourishes and supports skin barrier"
            pmNote = "Deeply hydrates during sleep"
            amBadge = "Best"
            pmBadge = "Best"
        }

        let guidance: String? = {
            if demoProduct.ingredientListStatus == .unavailable {
                return "Full ingredient list is unavailable for this product. Caution: routine clash analysis cannot be verified."
            } else if isRetinol {
                return "Contains Retinoid: Recommended for PM routine use only. Increases photosensitivity; always wear SPF during the day. Do not layer with AHA/BHA or Vitamin C at the same time."
            } else if isVitaminC {
                return "Contains Vitamin C: High-potency antioxidant. Excellent under morning SPF. Avoid mixing with retinol or direct acids in the same application."
            } else if isAha {
                return "Contains Exfoliating Acid: Use 2-3 times weekly at night. Avoid pairing with strong retinoids on the same evening."
            } else if isSpf {
                return "Daily Sun Protection: Apply as the final step in your AM routine 15 minutes before sun exposure. Reapply every 2 hours outdoors."
            } else {
                return "Formulated with skin-compatible hydrators and gentle conditioning agents. Suitable for daily AM and PM use."
            }
        }()

        let subtitleText: String
        if let spf = demoProduct.spf {
            subtitleText = "\(demoProduct.subtype.capitalized) · SPF \(spf)"
        } else {
            subtitleText = "\(demoProduct.subtype.capitalized) · \(cat.rawValue)"
        }

        self.init(
            id: UUID(),
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
