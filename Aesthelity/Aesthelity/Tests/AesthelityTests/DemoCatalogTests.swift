//
//  DemoCatalogTests.swift
//  AesthelityTests
//

import Testing
import Foundation
@testable import Aesthelity

struct DemoCatalogTests {
    let catalog: DemoCatalog

    init() throws {
        catalog = try DemoCatalog.load()
    }

    @Test func loadsBundledDemoData() {
        #expect(catalog.products.count == 17)
        #expect(catalog.profiles.count == 2)
        #expect(catalog.scenarios.count == 5)
    }

    @Test func productsAreLabeledFictional() {
        #expect(catalog.products.allSatisfy { $0.isFictional && $0.name.contains("Fictional") })
    }

    @Test func coversEveryScenarioType() {
        let types = Set(catalog.scenarios.map(\.scenarioType))
        #expect(types == Set(DemoScenarioType.allCases))
    }

    @Test func coversEveryProductCategory() {
        let categories = Set(catalog.products.map(\.category))
        #expect(categories == Set(DemoProductCategory.allCases))
    }

    @Test func unavailableIngredientListsAreEmpty() {
        for product in catalog.products {
            #expect((product.ingredientListStatus == .unavailable) == product.ingredients.isEmpty, "\(product.id)")
        }
    }

    @Test func scenarioReferencesResolve() {
        for scenario in catalog.scenarios {
            #expect(catalog.profile(id: scenario.profileId) != nil, "\(scenario.id): missing profile")
            for productID in scenario.productIds {
                #expect(catalog.product(id: productID) != nil, "\(scenario.id): missing product \(productID)")
            }
            for finding in scenario.expectedFindings {
                #expect(finding.productIds.allSatisfy { catalog.product(id: $0) != nil })
            }
        }
    }

    @Test func findingsHaveUserFacingText() {
        let findings = catalog.scenarios.flatMap(\.expectedFindings)
        #expect(!findings.isEmpty)
        for finding in findings {
            #expect(!finding.category.isEmpty)
            #expect(!finding.explanation.isEmpty)
            #expect(!finding.reason.isEmpty)
        }
    }

    @Test func normalScenarioHasNoFindings() throws {
        let normal = try #require(catalog.scenarios.first { $0.scenarioType == .normal })
        #expect(normal.expectedFindings.isEmpty)
    }

    @Test func allergenFindingNamesTheIngredient() throws {
        let allergen = try #require(catalog.scenarios.flatMap(\.expectedFindings).first { $0.kind == .allergen })
        #expect(allergen.ingredient == "Limonene")
    }

    // MARK: - User Story PD-01: Product Catalog Selection & Ingredient Guidance

    // Scenario 1: Given the product catalog contains available products, When a user opens the catalog, Then the products are displayed with their names and categories.
    @Test func testCatalogDisplaysProductsWithNamesAndCategories() {
        #expect(!catalog.products.isEmpty, "Catalog must load available products from bundle")
        
        let view = ProductCatalogView(products: catalog.products)
        let displayed = view.filteredProducts
        
        #expect(displayed.count == catalog.products.count)
        
        for product in displayed {
            #expect(!product.name.isEmpty)
            #expect(!product.brand.isEmpty)
            #expect(!product.category.rawValue.isEmpty)
            #expect(!product.category.displayName.isEmpty)
        }
        
        let cleansers = displayed.filter { $0.category == .cleanser }
        let serums = displayed.filter { $0.category == .serum }
        let sunscreens = displayed.filter { $0.category == .sunscreen }
        
        #expect(!cleansers.isEmpty, "Catalog should display cleansers")
        #expect(!serums.isEmpty, "Catalog should display serums")
        #expect(!sunscreens.isEmpty, "Catalog should display sunscreens")
    }

    // Scenario 2: Given a user finds a product in the catalog, When they select the product, Then the product details and ingredient list are displayed.
    @Test func testSelectProductDisplaysDetailsAndIngredients() {
        guard let retinolProduct = catalog.products.first(where: { $0.id == "serum_retinol" }) else {
            Issue.record("Expected serum_retinol in catalog")
            return
        }
        
        var selectedProduct: DemoProduct? = nil
        let view = ProductCatalogView(products: catalog.products) { product in
            selectedProduct = product
        }
        
        // Select the product
        view.selectProduct(retinolProduct)
        #expect(selectedProduct?.id == "serum_retinol")
        
        // Convert to ProductDetailItem for ProductDetailView
        let detail = ProductDetailItem(demoProduct: retinolProduct)
        
        #expect(detail.title == retinolProduct.name)
        #expect(detail.brand == retinolProduct.brand)
        #expect(detail.ingredients == retinolProduct.ingredients)
        #expect(detail.ingredientListStatus == .complete)
        #expect(detail.ingredients.contains("Retinol"))
        #expect(detail.ingredients.contains("Squalane"))
        #expect(detail.ingredientGuidance != nil)
        #expect(detail.ingredientGuidance?.contains("PM") == true)
        
        // Check routine compatibility logic for Retinol
        let amFit = detail.routineFits.first { $0.routineName.contains("AM") }
        let pmFit = detail.routineFits.first { $0.routineName.contains("PM") }
        
        #expect(amFit?.badgeText == "Avoid", "Retinol should be avoided in morning")
        #expect(pmFit?.badgeText == "Best", "Retinol is best suited for PM routine")
    }

    // Scenario 3: Given a user searches for a product that is not available, When the search is submitted, Then the app displays a clear empty-results message.
    @Test func testEmptySearchResultsHandling() {
        // Search for non-existent product
        let query = "NonExistentUnobtaniumCreamXYZ"
        let emptyView = ProductCatalogView(products: catalog.products, initialSearchText: query)
        
        let filtered = emptyView.filteredProducts(for: nil, query: query)
        #expect(filtered.isEmpty, "Search for non-existent product should return 0 results")
        #expect(emptyView.filteredProducts.isEmpty, "Filtered products should be empty for unmatched query")
        
        // Clearing search restores full catalog
        var activeView = ProductCatalogView(products: catalog.products)
        activeView.clearSearch()
        #expect(activeView.searchText.isEmpty)
        #expect(activeView.selectedCategory == nil)
        #expect(activeView.filteredProducts.count == catalog.products.count)
    }

    // Category Filtering
    @Test func testCategoryFiltering() {
        let view = ProductCatalogView(products: catalog.products)
        
        let cleansers = view.filteredProducts(for: .cleanser, query: "")
        #expect(!cleansers.isEmpty)
        #expect(cleansers.allSatisfy { $0.category == .cleanser })
        
        let serums = view.filteredProducts(for: .serum, query: "")
        #expect(!serums.isEmpty)
        #expect(serums.allSatisfy { $0.category == .serum })
        
        let sunscreens = view.filteredProducts(for: .sunscreen, query: "")
        #expect(!sunscreens.isEmpty)
        #expect(sunscreens.allSatisfy { $0.category == .sunscreen })
    }

    // Ingredient Search Filtering
    @Test func testSearchByIngredient() {
        let view = ProductCatalogView(products: catalog.products)
        
        let niacinamideMatches = view.filteredProducts(for: nil, query: "Niacinamide")
        #expect(!niacinamideMatches.isEmpty)
        
        for match in niacinamideMatches {
            let matchesName = match.name.localizedCaseInsensitiveContains("Niacinamide")
            let matchesIngredient = match.ingredients.contains { $0.localizedCaseInsensitiveContains("Niacinamide") }
            #expect(matchesName || matchesIngredient)
        }
    }

    // Unavailable Products Handling
    @Test func testUnavailableProductHandling() {
        guard let unavailable = catalog.products.first(where: { $0.ingredientListStatus == .unavailable }) else {
            Issue.record("Expected product with unavailable ingredients in catalog")
            return
        }
        
        #expect(unavailable.ingredientListStatus == .unavailable)
        #expect(unavailable.ingredients.isEmpty)
        
        let detail = ProductDetailItem(demoProduct: unavailable)
        #expect(detail.ingredientListStatus == .unavailable)
        #expect(detail.ingredientsUnavailable)
        #expect(detail.ingredients.isEmpty)
        #expect(detail.ingredientGuidance != nil)
        #expect(detail.ingredientGuidance?.contains("Caution") == true)
    }

    // Sunscreen Morning Suitability Guidance
    @Test func testSunscreenProductGuidance() {
        guard let sunscreen = catalog.products.first(where: { $0.category == .sunscreen && $0.ingredientListStatus != .unavailable }) else {
            Issue.record("Expected available sunscreen in catalog")
            return
        }
        
        let detail = ProductDetailItem(demoProduct: sunscreen)
        let amFit = detail.routineFits.first { $0.routineName.contains("AM") }
        let pmFit = detail.routineFits.first { $0.routineName.contains("PM") }
        
        #expect(amFit?.badgeText == "Best")
        #expect(pmFit?.badgeText == "Avoid", "Sunscreen is not recommended for overnight PM routines")
        #expect(detail.ingredientGuidance?.contains("morning") == true || detail.ingredientGuidance?.contains("Sun Protection") == true)
    }

    // Add to Routine Callback Integration
    @Test func testAddToRoutineIntegration() {
        guard let product = catalog.products.first else {
            Issue.record("Catalog empty")
            return
        }
        
        var addedProduct: DemoProduct? = nil
        var targetPeriod: RoutinePeriod? = nil
        
        let view = ProductCatalogView(
            products: catalog.products,
            onAddToRoutine: { p, period in
                addedProduct = p
                targetPeriod = period
            }
        )
        
        view.onAddToRoutine?(product, .am)
        #expect(addedProduct?.id == product.id)
        #expect(targetPeriod == .am)
        
        view.onAddToRoutine?(product, .pm)
        #expect(targetPeriod == .pm)
    }

    // Product Database Lookup for Demo Products
    @Test func testDatabaseDemoProductLookup() {
        let db = ProductDatabase.shared
        
        for demo in catalog.products {
            let detail = db.detail(forDemoProduct: demo)
            #expect(detail.title == demo.name)
            #expect(detail.brand == demo.brand)
            #expect(detail.ingredients.count == demo.ingredients.count)
            #expect(detail.ingredientListStatus == demo.ingredientListStatus)
        }
    }
}
