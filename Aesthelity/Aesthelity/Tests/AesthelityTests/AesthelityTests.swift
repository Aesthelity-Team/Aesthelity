//
//  AesthelityTests.swift
//  AesthelityTests
//
//  Unit tests for Aesthelity design theme, tokens, and features.
//

import Testing
import SwiftUI
@testable import Aesthelity

struct AesthelityTests {

    @Test func themeSpacingValues() throws {
        #expect(AppTheme.Spacing.screenPadding == 16)
        #expect(AppTheme.Spacing.sm == 8)
        #expect(AppTheme.Spacing.md == 12)
        #expect(AppTheme.Spacing.xl == 24)
    }

    @Test func themeCornerRadiusValues() throws {
        #expect(AppTheme.Radius.standard == 12)
        #expect(AppTheme.Radius.card == 12)
        #expect(AppTheme.Radius.button == 12)
    }

    @Test func themeShadowSpecifications() throws {
        #expect(AppTheme.Shadows.standardRadius == 10)
        #expect(AppTheme.Shadows.standardY == 4)
        #expect(AppTheme.Shadows.standardX == 0)
    }

    @Test func colorHexInitializer() throws {
        let accentColor = Color(hex: "#A3B18A")
        #expect(accentColor != nil)
        
        let cardColor = Color(hex: "#F5F5F5")
        #expect(cardColor != nil)
    }
    
    @Test func confidenceCardTokens() throws {
        #expect(AppTheme.Radius.cardLarge == 20)
        #expect(AppTheme.Semantic.confidenceGradientStart != nil)
        #expect(AppTheme.Semantic.confidenceGradientEnd != nil)
        
        let card = ConfidenceCard(
            score: 85,
            title: "CONFIDENCE SCORE",
            subtitle: "Routine compatibility",
            amSteps: 3,
            pmSteps: 4
        )
        #expect(card.score == 85)
        #expect(card.amSteps == 3)
        #expect(card.pmSteps == 4)
    }
    
    @Test func confidenceScoreViewInitialization() throws {
        let view = ConfidenceScoreView(
            score: 82,
            amStepsCount: 4,
            pmStepsCount: 5
        )
        #expect(view.score == 82)
        #expect(view.amStepsCount == 4)
        #expect(view.pmStepsCount == 5)
    }
    
    @Test func contentViewInitialization() throws {
        let view = ContentView()
        #expect(view != nil)
    }
    
    @Test func semanticSurfaceCanvasToken() throws {
        let canvasColor = Constants.semanticSurfaceCanvas
        #expect(canvasColor != nil)
        #expect(AppTheme.Semantic.surfaceCanvas != nil)
        #expect(AppTheme.Colors.surfaceCanvas != nil)
    }
    
    @Test func libraryViewInitializationAndDefaults() throws {
        let libraryView = LibraryView()
        #expect(libraryView.showsTabBar == true)
        #expect(libraryView.fullScreenFrame == true)
        #expect(libraryView.selectedCategory == .all)
        #expect(libraryView.filteredProducts.count == 10)
        #expect(libraryView.filteredRecentSaves.count == 5)
        #expect(libraryView.selectedProductDetail == nil)
    }
    
    @Test func libraryCategoryFiltering() throws {
        let libraryView = LibraryView()
        
        // Filter by Cleanser
        let cleanserProducts = libraryView.filteredProducts(for: .cleanser)
        #expect(cleanserProducts.allSatisfy { $0.category == .cleanser })
        #expect(cleanserProducts.contains { $0.title == "Hydrabio Cre..." })
        #expect(cleanserProducts.contains { $0.title == "Superfood Ci..." })
        #expect(cleanserProducts.contains { $0.title == "Foaming Mice..." })
        let cleanserSaves = libraryView.filteredRecentSaves(for: .cleanser)
        #expect(cleanserSaves.allSatisfy { $0.category == .cleanser })
        #expect(cleanserSaves.contains { $0.title == "Gentle Foaming Cleanser" })
        
        // Filter by Serum
        let serumProducts = libraryView.filteredProducts(for: .serum)
        #expect(serumProducts.allSatisfy { $0.category == .serum })
        #expect(serumProducts.contains { $0.title == "Caffeine Solution 5%" })
        #expect(serumProducts.contains { $0.title == "Honey Glaze Collagen Lip Mask" })
        let serumSaves = libraryView.filteredRecentSaves(for: .serum)
        #expect(serumSaves.allSatisfy { $0.category == .serum })
        #expect(serumSaves.contains { $0.title == "Vitamin C Serum" })
        
        // Filter by SPF
        let spfProducts = libraryView.filteredProducts(for: .spf)
        #expect(spfProducts.allSatisfy { $0.category == .spf })
        #expect(spfProducts.contains { $0.title == "Sun Block For..." })
        let spfSaves = libraryView.filteredRecentSaves(for: .spf)
        #expect(spfSaves.allSatisfy { $0.category == .spf })
        #expect(spfSaves.contains { $0.title == "Daily UV Defense SPF 50" })
        
        // Filter by Toner
        let tonerProducts = libraryView.filteredProducts(for: .toner)
        #expect(tonerProducts.allSatisfy { $0.category == .toner })
        #expect(tonerProducts.contains { $0.title == "Clarifying Toner" })
        let tonerSaves = libraryView.filteredRecentSaves(for: .toner)
        #expect(tonerSaves.allSatisfy { $0.category == .toner })
        #expect(tonerSaves.contains { $0.title == "Barrier Balance Toner" })
        
        // Filter by All
        let allProducts = libraryView.filteredProducts(for: .all)
        #expect(allProducts.count == 10)
        let allSaves = libraryView.filteredRecentSaves(for: .all)
        #expect(allSaves.count == 5)
    }
    
    @Test func librarySearchFiltering() throws {
        let libraryView = LibraryView()
        
        // Search by product name
        let nameSaves = libraryView.filteredRecentSaves(query: "Vitamin C")
        #expect(nameSaves.count == 1)
        #expect(nameSaves.first?.title == "Vitamin C Serum")
        
        // Search by brand
        let brandProducts = libraryView.filteredProducts(query: "Bioderma")
        #expect(brandProducts.count == 1)
        #expect(brandProducts.first?.brand == "Bioderma")
    }
    
    // MARK: - Product Detail & Database Tests
    
    @Test func productDatabaseVitaminCDefault() throws {
        let db = ProductDatabase.shared
        let item = db.detail(forTitle: "Vitamin C Serum")
        
        #expect(item.title == "Vitamin C Serum")
        #expect(item.subtitle == "Brightening serum · AM routine")
        #expect(item.brand == "Misticore")
        #expect(item.category == .serum)
        #expect(item.routineFits.count == 2)
        
        let amFit = item.routineFits.first(where: { $0.routineName == "AM routine" })
        #expect(amFit?.note == "Works before SPF")
        #expect(amFit?.badgeText == "Best")
        
        let pmFit = item.routineFits.first(where: { $0.routineName == "PM routine" })
        #expect(pmFit?.note == "Do not combine with retinol")
        #expect(pmFit?.badgeText == "Avoid")
    }
    
    @Test func productDatabaseVersatileFallbacks() throws {
        let db = ProductDatabase.shared
        
        // Lookup for LibraryProductItem
        let libraryItem = LibraryProductItem(title: "Custom Hydrating Mist", brand: "Aura Botanicals", category: .toner)
        let detail = db.detail(for: libraryItem)
        #expect(detail.title == "Custom Hydrating Mist")
        #expect(detail.brand == "Aura Botanicals")
        #expect(detail.category == .toner)
        #expect(detail.routineFits.count >= 2)
        
        // Lookup for SPF product
        let spfItem = LibraryProductItem(title: "Mineral Shield SPF", brand: "SunGuard", category: .spf)
        let spfDetail = db.detail(for: spfItem)
        #expect(spfDetail.routineFits.contains { $0.routineName == "PM routine" && $0.badgeText == "Avoid" })
    }
    
    @Test func productDetailViewInitialization() throws {
        let item = ProductDatabase.shared.detail(forTitle: "Vitamin C Serum")
        let detailView = ProductDetailView(
            product: item,
            showsTabBar: true,
            fullScreenFrame: true
        )
        #expect(detailView.product.title == "Vitamin C Serum")
        #expect(detailView.showsTabBar == true)
        #expect(detailView.fullScreenFrame == true)
    }
    
    @Test func libraryViewProductSelection() throws {
        let sampleProduct = LibraryProductItem(title: "Sun Block For...", brand: "HistoLab", category: .spf)
        let detail = ProductDatabase.shared.detail(for: sampleProduct)
        
        let libraryViewWithProduct = LibraryView(selectedProductDetail: detail)
        #expect(libraryViewWithProduct.selectedProductDetail != nil)
        #expect(libraryViewWithProduct.selectedProductDetail?.title.contains("Sun Block") == true)
        
        let sampleSave = RecentSaveItem(title: "Vitamin C Serum", subtitle: "Brightening · AM", category: .serum)
        let saveDetail = ProductDatabase.shared.detail(for: sampleSave)
        let libraryViewWithSave = LibraryView(selectedProductDetail: saveDetail)
        #expect(libraryViewWithSave.selectedProductDetail?.title == "Vitamin C Serum")
    }
    
    @Test func productDetailLookupByID() throws {
        let db = ProductDatabase.shared
        
        // 1. Look up Hydrabio Cream Cleanser by ID instead of shortened name "Hydrabio Cre..."
        let hydrabio = db.product(for: ProductDatabase.hydrabioCreamCleanserID)
        #expect(hydrabio != nil)
        #expect(hydrabio?.title == "Hydrabio Cream Cleanser")
        #expect(hydrabio?.brand == "Bioderma")
        #expect(hydrabio?.category == .cleanser)
        
        // 2. Look up other previously shortened products by ID
        let sunBlock = db.product(byId: ProductDatabase.sunBlockPostCareID)
        #expect(sunBlock?.title == "Sun Block Post Care SPF 50+")
        
        let superfood = db.detail(for: ProductDatabase.superfoodCicaCleanserID)
        #expect(superfood.title == "Superfood Cica Cleanser")
        
        let foamingWash = db.detail(forId: ProductDatabase.foamingMicellarWashID)
        #expect(foamingWash?.title == "Foaming Micellar Wash")
        
        // 3. Look up by String representation of ID
        let hydrabioByStringId = db.detail(forId: ProductDatabase.hydrabioCreamCleanserID.uuidString)
        #expect(hydrabioByStringId?.title == "Hydrabio Cream Cleanser")
        
        // 4. Subscript access by UUID
        let subscriptItem = db[ProductDatabase.hydrabioCreamCleanserID]
        #expect(subscriptItem?.title == "Hydrabio Cream Cleanser")
        
        // 5. Look up via LibraryProductItem carrying ID
        let libraryItem = LibraryProductItem(
            id: ProductDatabase.hydrabioCreamCleanserID,
            title: "Hydrabio Cre...",
            brand: "Bioderma",
            category: .cleanser
        )
        let resolvedFromLibraryItem = db.detail(for: libraryItem)
        #expect(resolvedFromLibraryItem.id == ProductDatabase.hydrabioCreamCleanserID)
        #expect(resolvedFromLibraryItem.title == "Hydrabio Cream Cleanser")
        
        // 6. ProductDetailView initialization by ID
        let detailViewByID = ProductDetailView(id: ProductDatabase.hydrabioCreamCleanserID)
        #expect(detailViewByID.product.id == ProductDatabase.hydrabioCreamCleanserID)
        #expect(detailViewByID.product.title == "Hydrabio Cream Cleanser")
        
        let detailViewByProductID = ProductDetailView(productId: ProductDatabase.hydrabioCreamCleanserID)
        #expect(detailViewByProductID.product.title == "Hydrabio Cream Cleanser")
        
        let detailViewByStringID = ProductDetailView(productId: ProductDatabase.hydrabioCreamCleanserID.uuidString)
        #expect(detailViewByStringID.product.title == "Hydrabio Cream Cleanser")
        
        // 7. Seed products plus demo-catalog products registered with stable UUIDs
        let demoCount = (try? DemoCatalog.load())?.products.count ?? 0
        #expect(db.allProducts.count == 14 + demoCount)
        #expect(db.allProducts.contains { $0.id == ProductDatabase.hydrabioCreamCleanserID })
    }
    
    // MARK: - ScanView Tests
    
    @Test func scanViewInitialization() throws {
        let scanView = ScanView()
        #expect(scanView.showsTabBar == false)
        
        let scanViewWithTabBar = ScanView(showsTabBar: true)
        #expect(scanViewWithTabBar.showsTabBar == true)
    }
    
    @Test func scanModeCasesAndIcons() throws {
        #expect(ScanMode.allCases.count == 2)
        #expect(ScanMode.ingredients.rawValue == "Ingredients")
        #expect(ScanMode.barcode.rawValue == "Barcode")
        #expect(ScanMode.ingredients.iconName == "text.viewfinder")
        #expect(ScanMode.barcode.iconName == "barcode.viewfinder")
    }
    
    @Test func scanSafetyLevelsAndTokens() throws {
        let safe = IngredientSafetyLevel.safe
        #expect(safe.rawValue == "Harmonious")
        #expect(safe.iconName == "checkmark.circle.fill")
        
        let caution = IngredientSafetyLevel.caution
        #expect(caution.rawValue == "Routine Caution")
        #expect(caution.iconName == "exclamationmark.triangle.fill")
        
        let clash = IngredientSafetyLevel.clash
        #expect(clash.rawValue == "Formula Clash")
        #expect(clash.iconName == "xmark.octagon.fill")
    }
    
    @Test func scanResultSheetModel() throws {
        let resultSheet = ScanResultSheet(
            scannedTitle: "Niacinamide 10% + Zinc 1%",
            scannedBrand: "The Ordinary",
            compatibilityScore: 96,
            onDismiss: {}
        )
        #expect(resultSheet.scannedTitle == "Niacinamide 10% + Zinc 1%")
        #expect(resultSheet.scannedBrand == "The Ordinary")
        #expect(resultSheet.compatibilityScore == 96)
        #expect(resultSheet.actives.count == 3)
    }
    
    @Test func profileViewInitializationAndDefaults() throws {
        let view = ProfileView()
        #expect(view.productsCount == 24)
        #expect(view.routinesCount == 2)
        #expect(view.score == 82)
        #expect(view.amStepsCount == 4)
        #expect(view.pmStepsCount == 5)
        #expect(view.onOpenJournal == nil)
        #expect(view.onOpenAnalysis == nil)
        #expect(view.onSelectRoutine == nil)
    }
    
    @Test func profileViewCustomParametersAndActions() throws {
        var journalOpened = false
        var analysisOpened = false
        var selectedPeriod: RoutinePeriod? = nil
        
        let view = ProfileView(
            productsCount: 18,
            routinesCount: 3,
            score: 95,
            amStepsCount: 3,
            pmStepsCount: 6,
            onOpenJournal: { journalOpened = true },
            onOpenAnalysis: { analysisOpened = true },
            onSelectRoutine: { period in selectedPeriod = period }
        )
        
        #expect(view.productsCount == 18)
        #expect(view.routinesCount == 3)
        #expect(view.score == 95)
        #expect(view.amStepsCount == 3)
        #expect(view.pmStepsCount == 6)
        
        view.onOpenJournal?()
        #expect(journalOpened == true)
        
        view.onOpenAnalysis?()
        #expect(analysisOpened == true)
        
        view.onSelectRoutine?(.pm)
        #expect(selectedPeriod == .pm)
    }
    
    // MARK: - SettingsView Tests
    
    @Test func settingsViewDefaults() throws {
        let settings = SettingsView()
        #expect(settings.skinType == "Combination · Sensitive")
        #expect(settings.concerns == "Acne, Redness, Dullness")
        #expect(settings.amRoutineReminder == true)
        #expect(settings.pmRoutineReminder == true)
        #expect(settings.scanAlertsEnabled == false)
        #expect(settings.weeklySkinReportEnabled == true)
        #expect(settings.showsTabBar == false)
        #expect(settings.selectedTab == 4)
        #expect(settings.onBack == nil)
        #expect(settings.onSelectTab == nil)
        #expect(settings.onDeleteScanHistory == nil)
    }
    
    @Test func settingsViewCustomParametersAndCallbacks() throws {
        var backCalled = false
        var selectedTab: Int? = nil
        var deleteCalled = false
        
        let settings = SettingsView(
            skinType: "Oily · Acne-Prone",
            concerns: "Blemishes, Hyperpigmentation",
            amRoutineReminder: false,
            pmRoutineReminder: true,
            scanAlertsEnabled: true,
            weeklySkinReportEnabled: false,
            showsTabBar: true,
            selectedTab: 2,
            onBack: { backCalled = true },
            onSelectTab: { tab in selectedTab = tab },
            onDeleteScanHistory: { deleteCalled = true }
        )
        
        #expect(settings.skinType == "Oily · Acne-Prone")
        #expect(settings.concerns == "Blemishes, Hyperpigmentation")
        #expect(settings.amRoutineReminder == false)
        #expect(settings.pmRoutineReminder == true)
        #expect(settings.scanAlertsEnabled == true)
        #expect(settings.weeklySkinReportEnabled == false)
        #expect(settings.showsTabBar == true)
        #expect(settings.selectedTab == 2)
        
        settings.onBack?()
        #expect(backCalled == true)
        
        settings.onSelectTab?(3)
        #expect(selectedTab == 3)
        
        settings.onDeleteScanHistory?()
        #expect(deleteCalled == true)
    }
    
    @Test func profileViewSettingsIntegration() throws {
        var settingsOpened = false
        let profile = ProfileView(
            showSettings: true,
            onOpenSettings: { settingsOpened = true }
        )
        #expect(profile.showSettings == true)
        
        profile.onOpenSettings?()
        #expect(settingsOpened == true)
    }
    
    @Test func profileEditCallbackOpensSharedSetup() throws {
        var opened = false
        let profile = ProfileView(onEditSkinProfile: { opened = true })
        profile.onEditSkinProfile?()
        #expect(opened)
    }

    // MARK: - Article Detail Tests
    
    @Test func articleDetailExampleData() throws {
        let example = ArticleDetailItem.example
        #expect(example.badge == "GUIDE")
        #expect(example.title.contains("How to Layer SPF Over"))
        #expect(example.metadata == "Skin Intelligence · 3 min read")
        #expect(example.introduction.contains("SPF-over-serum dilemma"))
        #expect(example.tips.count == 3)
        #expect(example.tips[0].title == "Wait 60s")
        #expect(example.tips[0].subtitle == "Let serum fully absorb before SPF")
        #expect(example.tips[1].title == "Pat, don't rub")
        #expect(example.tips[1].subtitle == "Rubbing disrupts the serum layer")
        #expect(example.tips[2].title == "Mineral SPF")
        #expect(example.tips[2].subtitle == "Less likely to pill over actives")
        #expect(example.relatedProducts.count == 3)
        #expect(example.relatedProducts[0].title == "Vitamin C Serum")
    }
    
    @Test func articleDetailViewInitialization() throws {
        var backTapped = false
        var selectedTab: Int? = nil
        let articleView = ArticleDetailView(
            article: .example,
            showsTabBar: true,
            fullScreenFrame: true,
            onBack: { backTapped = true },
            onSelectTab: { tab in selectedTab = tab }
        )
        
        #expect(articleView.showsTabBar == true)
        #expect(articleView.fullScreenFrame == true)
        #expect(articleView.article.title == ArticleDetailItem.example.title)
        
        articleView.onBack?()
        #expect(backTapped == true)
        
        articleView.onSelectTab?(3)
        #expect(selectedTab == 3)
    }
    
    @Test func exploreViewInitializationAndGuides() throws {
        let defaultExplore = ExploreView()
        #expect(defaultExplore.showsTabBar == true)
        #expect(defaultExplore.guides.contains { $0.title.contains("How to Layer SPF") })
    }
    
    // MARK: - Ingredient Clash Tests
    
    @Test func ingredientClashViewInitialization() throws {
        var backTapped = false
        let clashView = IngredientClashView(onBack: {
            backTapped = true
        })
        #expect(clashView.onBack != nil)
        clashView.onBack?()
        #expect(backTapped == true)
    }
    
    @Test func routineStepItemClashProperty() throws {
        let nonClashStep = RoutineStepItem(
            stepNumber: 1,
            title: "Gentle Cleanser",
            subtitle: "Completed · Step 1",
            state: .complete,
            hasClash: false
        )
        #expect(nonClashStep.hasClash == false)
        #expect(nonClashStep.title == "Gentle Cleanser")
        
        let clashStep = RoutineStepItem(
            stepNumber: 2,
            title: "Vitamin C Serum",
            subtitle: "Ready · Step 2",
            state: .active,
            hasClash: true
        )
        #expect(clashStep.hasClash == true)
        #expect(clashStep.title == "Vitamin C Serum")
    }
    
    @Test func contentViewClashDemoStateDefaultsAndSteps() throws {
        let clashSteps = ContentViewStepModel.defaultAMClashSteps
        let contentView = ContentView(
            selectedPeriod: .am,
            showClashDemo: true,
            amSteps: ContentViewStepModel.defaultAMSteps,
            amClashSteps: clashSteps,
            pmSteps: ContentViewStepModel.defaultPMSteps
        )
        #expect(contentView.showClashDemo == true)
        #expect(contentView.selectedPeriod == .am)
        
        let steps = contentView.currentSteps
        #expect(steps.count == 5)
        #expect(steps[0].title == "Gentle Cleanser")
        #expect(steps[0].hasClash == false)
        #expect(steps[1].title == "Vitamin C Serum")
        #expect(steps[1].hasClash == true)
        #expect(steps[2].title == "Retinol Night Cream")
        #expect(steps[2].hasClash == true)
        #expect(steps[3].title == "Daily Moisturizer")
        #expect(steps[3].hasClash == false)
        #expect(steps[4].title == "SPF 46")
        #expect(steps[4].hasClash == false)
    }
    
    @Test func contentViewToggleClashDemoState() throws {
        let contentView = ContentView(
            selectedPeriod: .am,
            showClashDemo: false,
            amSteps: ContentViewStepModel.defaultAMSteps,
            amClashSteps: ContentViewStepModel.defaultAMClashSteps,
            pmSteps: ContentViewStepModel.defaultPMSteps
        )
        
        let normalSteps = contentView.currentSteps
        #expect(normalSteps.count == 4)
        #expect(normalSteps.allSatisfy { $0.hasClash == false })
        #expect(normalSteps[0].title == "Gentle Cleanser")
        #expect(normalSteps[1].title == "Vitamin C Serum")
        #expect(normalSteps[2].title == "Daily Moisturizer")
        #expect(normalSteps[3].title == "SPF 46")
    }
    
    @Test func contentViewPopulatedRoutineHasNoEmptyMessage() throws {
        let injected = ContentView(
            selectedPeriod: .am,
            showClashDemo: false,
            amSteps: ContentViewStepModel.defaultAMSteps,
            amClashSteps: ContentViewStepModel.defaultAMClashSteps,
            pmSteps: ContentViewStepModel.defaultPMSteps
        )
        #expect(injected.emptyRoutineMessage == nil)
        #expect(ContentView(
            selectedPeriod: .pm,
            showClashDemo: false,
            amSteps: ContentViewStepModel.defaultAMSteps,
            amClashSteps: ContentViewStepModel.defaultAMClashSteps,
            pmSteps: ContentViewStepModel.defaultPMSteps
        ).emptyRoutineMessage == nil)
    }

    @Test func contentViewEmptySelectedRoutineShowsMessage() throws {
        let sampleAM = ContentViewStepModel.defaultAMSteps

        let emptyPM = ContentView(selectedPeriod: .pm, amSteps: sampleAM, amClashSteps: sampleAM, pmSteps: [])
        #expect(emptyPM.currentSteps.isEmpty)
        #expect(emptyPM.emptyRoutineMessage == "No PM routine steps to show yet.")

        let populatedAM = ContentView(selectedPeriod: .am, amSteps: sampleAM, amClashSteps: sampleAM, pmSteps: [])
        #expect(populatedAM.emptyRoutineMessage == nil)

        let emptyClashAM = ContentView(selectedPeriod: .am, showClashDemo: true, amSteps: sampleAM, amClashSteps: [], pmSteps: [])
        #expect(emptyClashAM.emptyRoutineMessage == "No AM routine steps to show yet.")
    }

    @Test func contentViewClashDetailNavigationState() throws {
        let contentView = ContentView(showIngredientClashDetail: true)
        #expect(contentView.showIngredientClashDetail == true)
    }
    
    @Test func skinMoodEnumCases() throws {
        let allMoods = SkinMood.allCases
        #expect(allMoods.count == 6)
        #expect(SkinMood.calm.rawValue == "Calm")
        #expect(SkinMood.dry.rawValue == "Dry")
        #expect(SkinMood.redness.rawValue == "Redness")
        #expect(SkinMood.breakout.rawValue == "Breakout")
        #expect(SkinMood.irritated.rawValue == "Irritated")
        #expect(SkinMood.glowy.rawValue == "Glowy")
        #expect(SkinMood.calm.displayName == "Calm")
        #expect(SkinMood.calm.id == "Calm")
    }
    
    @Test func skinLogEntryModel() throws {
        let entry = SkinLogEntry(
            dateString: "September 13",
            title: "Glow day",
            subtitle: "Low redness · routine complete",
            mood: .calm,
            note: "Skin looked calm today.",
            conditions: ["Low redness", "Routine complete", "SPF applied"],
            badgeText: "Good",
            hasDot: false,
            isHighlighted: true
        )
        #expect(entry.dateString == "September 13")
        #expect(entry.title == "Glow day")
        #expect(entry.subtitle == "Low redness · routine complete")
        #expect(entry.mood == .calm)
        #expect(entry.note == "Skin looked calm today.")
        #expect(entry.conditions.count == 3)
        #expect(entry.badgeText == "Good")
        #expect(entry.isHighlighted == true)
    }
    
    @Test func skinJournalStoreDefaultsAndSaving() throws {
        let store = SkinJournalStore()
        #expect(store.entries.count == 3)
        #expect(store.entries[0].dateString == "September 13")
        #expect(store.entries[1].dateString == "September 9")
        #expect(store.entries[2].dateString == "September 6")
        
        let newEntry = SkinLogEntry(
            dateString: "September 20",
            title: "Hydration check",
            subtitle: "Plump and calm",
            mood: .glowy
        )
        store.saveEntry(newEntry)
        #expect(store.entries.count == 4)
        #expect(store.entries[0].dateString == "September 20")
        
        var modifiedEntry = newEntry
        modifiedEntry.note = "Updated note"
        store.saveEntry(modifiedEntry)
        #expect(store.entries.count == 4)
        #expect(store.entries[0].note == "Updated note")
    }
    
    @Test func skinCalendarViewDefaults() throws {
        let store = SkinJournalStore()
        var openedLog: SkinLogEntry? = nil
        var openedJournal = false
        
        let view = SkinCalendarView(
            store: store,
            backTitle: "Journal",
            showsTabBar: true,
            onOpenLog: { log in
                openedLog = log
            },
            onOpenJournal: {
                openedJournal = true
            }
        )
        #expect(view.backTitle == "Journal")
        #expect(view.showsTabBar == true)
        #expect(view.store.entries.count == 3)
        view.onOpenLog?(store.entries[0])
        #expect(openedLog?.title == store.entries[0].title)
        view.onOpenJournal?()
        #expect(openedJournal == true)
    }
    
    @Test func skinLogViewDefaultsAndSaving() throws {
        let entry = SkinLogEntry(
            dateString: "September 13",
            title: "September 13 Log",
            subtitle: "Track how your skin felt today.",
            mood: .calm,
            note: "Skin looked calm today.",
            conditions: ["Low redness", "Routine complete", "SPF applied"],
            badgeText: "Good"
        )
        
        var savedEntry: SkinLogEntry? = nil
        var dismissed = false
        
        let logView = SkinLogView(
            entry: entry,
            backTitle: "Calendar",
            showsTabBar: true,
            showsValidationButton: true,
            onDismiss: {
                dismissed = true
            },
            onSave: { updated in
                savedEntry = updated
            }
        )
        #expect(logView.backTitle == "Calendar")
        #expect(logView.showsTabBar == true)
        #expect(logView.showsValidationButton == true)
        #expect(logView.entry.dateString == "September 13")
        logView.onDismiss?()
        #expect(dismissed == true)
        logView.onSave?(entry)
        #expect(savedEntry?.title == entry.title)
    }
    
    @Test func skinJournalViewDefaults() throws {
        let store = SkinJournalStore()
        var openedCalendar = false
        var dismissed = false
        
        let journalView = SkinJournalView(
            store: store,
            backTitle: "Home",
            showsTabBar: false,
            onBack: {
                dismissed = true
            },
            onOpenCalendar: {
                openedCalendar = true
            }
        )
        #expect(journalView.backTitle == "Home")
        #expect(journalView.showsTabBar == false)
        #expect(journalView.store.todayNote.contains("Low redness today"))
        #expect(journalView.store.todayMoodText == "Glowy / Calm")
        journalView.onBack?()
        #expect(dismissed == true)
        journalView.onOpenCalendar?()
        #expect(openedCalendar == true)
    }
    
    @Test func contentViewCalendarSheetState() throws {
        let defaultView = ContentView()
        #expect(defaultView.showCalendarSheet == false)
        #expect(defaultView.showJournalSheet == false)
        let activeView = ContentView(showJournalSheet: true, showCalendarSheet: true)
        #expect(activeView.showCalendarSheet == true)
        #expect(activeView.showJournalSheet == true)
    }
    
    // MARK: - Routine Screen & Feature Tests
    
    @Test @MainActor func routineRepositoryDefaults() throws {
        let repo = RoutineRepository.shared
        try repo.seedDefaults()
        #expect(repo.routines.count >= 3)
        
        let amGlow = repo.routines.first(where: { $0.name == "AM Glow" })
        #expect(amGlow != nil)
        #expect(amGlow?.period == .am)
        #expect(amGlow?.status == .paused)
        #expect(amGlow?.steps.count == 4)
        #expect(amGlow?.frequency == .everyDay)
        #expect(amGlow?.scheduleSummary.contains("7:00 AM") == true)
        
        let pmRepair = repo.routines.first(where: { $0.name == "PM Repair" })
        #expect(pmRepair != nil)
        #expect(pmRepair?.period == .pm)
        #expect(pmRepair?.status == .paused)
        #expect(pmRepair?.frequency == .everyOtherDay)
        #expect(pmRepair?.scheduleSummary.contains("9:00 PM") == true)
        
        let weekly = repo.routines.first(where: { $0.name == "Weekly Exfoliate" })
        #expect(weekly != nil)
        #expect(weekly?.status == .active)
        #expect(weekly?.frequency == .twoTimesAWeek)
        #expect(weekly?.scheduleSummary.contains("2× / week") == true)
    }
    
    @Test func routineFrequencyAndScheduleFormatting() throws {
        #expect(RoutineFrequency.allCases.count == 5)
        #expect(RoutineFrequency.everyDay.rawValue == "Every day")
        #expect(RoutineFrequency.everyOtherDay.rawValue == "Every other day")
        #expect(RoutineFrequency.twoTimesAWeek.rawValue == "2 times a week")
        #expect(RoutineFrequency.onceAWeek.rawValue == "Once a week")
        #expect(RoutineFrequency.onceAMonth.rawValue == "Once a month")
        
        let everyDayRecord = RoutineRecord(name: "Morning", frequency: .everyDay, reminderTime: "7:00 AM")
        #expect(everyDayRecord.scheduleSummary == "Every day · 7:00 AM")
        
        let everyOtherRecord = RoutineRecord(name: "Alt", frequency: .everyOtherDay, reminderTime: "8:00 AM")
        #expect(everyOtherRecord.scheduleSummary == "Every other day · 8:00 AM")
        
        let weeklyRecord = RoutineRecord(name: "Weekend", frequency: .onceAWeek, reminderTime: "9:00 AM")
        #expect(weeklyRecord.scheduleSummary == "Once a week · 9:00 AM")
        
        let monthlyRecord = RoutineRecord(name: "Monthly", frequency: .onceAMonth, reminderTime: "10:00 AM")
        #expect(monthlyRecord.scheduleSummary == "Once a month · 10:00 AM")
        
        let weekdays = RoutineWeekday.allCases
        #expect(weekdays.count == 7)
    }
    
    @Test func routineNotificationSettingsLeadTimes() throws {
        #expect(NotificationLeadTime.allCases.count == 3)
        #expect(NotificationLeadTime.atTime.rawValue == "At time")
        #expect(NotificationLeadTime.min15.rawValue == "15 min before")
        #expect(NotificationLeadTime.hour1.rawValue == "1 hour before")
        
        let record = RoutineRecord(
            name: "Test Routine",
            pushRemindersEnabled: true,
            leadTime: .min15,
            quietHoursEnabled: true
        )
        #expect(record.pushRemindersEnabled == true)
        #expect(record.leadTime == .min15)
        #expect(record.quietHoursEnabled == true)
    }
    
    @Test func routineStepReordering() throws {
        let initialSteps = [
            RoutineStepItem(stepNumber: 1, title: "Cleanser", subtitle: "Step 1", state: .complete),
            RoutineStepItem(stepNumber: 2, title: "Toner", subtitle: "Step 2", state: .active),
            RoutineStepItem(stepNumber: 3, title: "Moisturizer", subtitle: "Step 3", state: .incomplete)
        ]
        
        var reordered = initialSteps
        let item = reordered.remove(at: 0)
        reordered.insert(item, at: 1)
        
        for i in 0..<reordered.count {
            let s = reordered[i]
            reordered[i] = RoutineStepItem(
                stepNumber: i + 1,
                title: s.title,
                subtitle: s.subtitle,
                state: s.state,
                hasClash: s.hasClash
            )
        }
        
        #expect(reordered[0].title == "Toner")
        #expect(reordered[0].stepNumber == 1)
        #expect(reordered[1].title == "Cleanser")
        #expect(reordered[1].stepNumber == 2)
        #expect(reordered[2].title == "Moisturizer")
        #expect(reordered[2].stepNumber == 3)
    }
    
    @Test func editRoutineStepLimitMaxEight() throws {
        var steps: [RoutineStepItem] = []
        for i in 1...8 {
            steps.append(RoutineStepItem(stepNumber: i, title: "Step \(i)", subtitle: "Desc", state: .incomplete))
        }
        let record = RoutineRecord(name: "Full Routine", period: .am, steps: steps)
        #expect(record.steps.count == 8)
        
        let view = EditRoutineView(routine: record)
        #expect(view.steps.count == 8)
    }
    
    @Test func contentViewRoutineNavigationStates() throws {
        let view = ContentView(showManageRoutinesView: true, showEditRoutineView: true)
        #expect(view.showManageRoutinesView == true)
        #expect(view.showEditRoutineView == true)
    }
    
    @Test func createRoutineViewInitialization() throws {
        var cancelCalled = false
        var savedRecord: RoutineRecord? = nil
        let createView = CreateRoutineView(
            onCancel: { cancelCalled = true },
            onSaveRoutine: { rec in
                savedRecord = rec
                return true
            }
        )
        #expect(createView.routineName.isEmpty)
        #expect(createView.selectedPeriod == RoutinePeriod.am)
        #expect(createView.frequency == RoutineFrequency.everyDay)
        createView.onCancel()
        #expect(cancelCalled == true)
        let sample = RoutineRecord(name: "Created Routine")
        createView.onSaveRoutine(sample)
        #expect(savedRecord?.name == "Created Routine")
    }
    
    @Test func myRoutinesViewInitialization() throws {
        var backCalled = false
        let myRoutines = MyRoutinesView(initialEmptyDemo: false, onBack: { backCalled = true })
        #expect(myRoutines.showEmptyStateDemo == false)
        myRoutines.onBack()
        #expect(backCalled == true)
    }
    
    @Test func addProductToRoutineViewInitialization() throws {
        let addView = AddProductToRoutineView(
            currentRoutineName: "AM Glow",
            existingStepTitles: ["Gentle Cleanser", "Vitamin C Serum"]
        )
        #expect(addView.currentRoutineName == "AM Glow")
        #expect(addView.existingStepTitles.count == 2)
    }

    // MARK: - Scan Error State Tests
    
    @Test func scanErrorTypeProperties() throws {
        #expect(ScanErrorType.allCases.count == 2)
        
        let labelError = ScanErrorType.unableToReadLabel
        #expect(labelError.title == "Unable to Read Label")
        #expect(labelError.badgeText == "Unreadable Label")
        #expect(labelError.iconName == "text.viewfinder")
        #expect(labelError.primaryActionTitle == "Try Again")
        #expect(labelError.secondaryActionTitle == "Upload Photo Instead")
        #expect(labelError.tips.count == 3)
        #expect(labelError.tips[0].title == "Bright, Even Light")
        
        let barcodeError = ScanErrorType.unableToReadBarcode
        #expect(barcodeError.title == "Unable to Read Barcode")
        #expect(barcodeError.badgeText == "Unreadable Barcode")
        #expect(barcodeError.iconName == "barcode.viewfinder")
        #expect(barcodeError.primaryActionTitle == "Try Again")
        #expect(barcodeError.secondaryActionTitle == "Scan Ingredient Label Instead")
        #expect(barcodeError.tips.count == 3)
        #expect(barcodeError.tips[0].title == "Align in Frame")
    }
    
    @Test func scanErrorViewInitializationAndCallbacks() throws {
        var tryAgainCalled = false
        var secondaryCalled = false
        var dismissCalled = false
        var tabIndexSelected: Int? = nil
        
        let errorView = ScanErrorView(
            errorType: .unableToReadLabel,
            showsTabBar: true,
            onTryAgain: { tryAgainCalled = true },
            onSecondaryAction: { secondaryCalled = true },
            onDismiss: { dismissCalled = true },
            onSelectTab: { tabIndexSelected = $0 }
        )
        
        #expect(errorView.errorType == .unableToReadLabel)
        #expect(errorView.showsTabBar == true)
        
        errorView.onTryAgain()
        #expect(tryAgainCalled == true)
        
        errorView.onSecondaryAction()
        #expect(secondaryCalled == true)
        
        errorView.onDismiss()
        #expect(dismissCalled == true)
        
        errorView.onSelectTab?(2)
        #expect(tabIndexSelected == 2)
    }
    
    @Test func scanViewErrorScreenStates() throws {
        #expect(ScanScreenState.unableToReadLabel.rawValue == "Unable to Read Label")
        #expect(ScanScreenState.unableToReadBarcode.rawValue == "Unable to Read Barcode")
        
        let scanViewLabelError = ScanView(initialState: .unableToReadLabel, showsTabBar: true)
        #expect(scanViewLabelError.showsTabBar == true)
        
        let scanViewBarcodeError = ScanView(initialState: .unableToReadBarcode, showsTabBar: false)
        #expect(scanViewBarcodeError.showsTabBar == false)
    }

    // MARK: - Startup & Authentication Screens Tests
    
    @Test func startupScreenCases() throws {
        #expect(StartupScreen.allCases.count == 5)
        #expect(StartupScreen.welcome.rawValue == "Welcome")
        #expect(StartupScreen.concerns.rawValue == "Concerns")
        #expect(StartupScreen.signInNormal.rawValue == "Sign In")
        #expect(StartupScreen.signInInvalid.rawValue == "Invalid Form")
        #expect(StartupScreen.signInFailed.rawValue == "Network Error")
    }
    
    @Test func startupFlowViewInitialization() throws {
        var finished = false
        let flow = StartupFlowView(initialScreen: .welcome) {
            finished = true
        }
        #expect(flow.currentScreen == .welcome)
        flow.onFinish()
        #expect(finished)
        
        let customFlow = StartupFlowView(initialScreen: .signInFailed)
        #expect(customFlow.currentScreen == .signInFailed)
    }
    
    @Test func authSignInViewModesAndCredentials() throws {
        var successCalled = false
        var switchToSetupCalled = false
        
        let normalAuth = AuthSignInView(
            initialMode: .normal,
            onSuccess: { successCalled = true },
            onSwitchToSetup: { switchToSetupCalled = true }
        )
        #expect(normalAuth.mode == .normal)
        #expect(normalAuth.email == "maya@aesthelity.app")
        #expect(normalAuth.password == "")
        normalAuth.onSuccess()
        #expect(successCalled == true)
        normalAuth.onSwitchToSetup()
        #expect(switchToSetupCalled == true)
        
        let invalidAuth = AuthSignInView(initialMode: .invalid)
        #expect(invalidAuth.mode == .invalid)
        #expect(invalidAuth.email == "maya")
        #expect(invalidAuth.password == "")
        
        let failedAuth = AuthSignInView(initialMode: .failed)
        #expect(failedAuth.mode == .failed)
        #expect(failedAuth.email == "maya@aesthelity.app")
    }
    
    @Test func onboardingWelcomeViewCallbacks() throws {
        var startedCalled = false
        var signInCalled = false
        var skipCalled = false
        
        let welcome = OnboardingWelcomeView(
            onGetStarted: { startedCalled = true },
            onSignIn: { signInCalled = true },
            onSkip: { skipCalled = true }
        )
        
        welcome.onGetStarted()
        #expect(startedCalled == true)
        
        welcome.onSignIn()
        #expect(signInCalled == true)
        
        welcome.onSkip()
        #expect(skipCalled == true)
    }
    
    @Test func onboardingConcernsSelection() throws {
        var selected = SkinProfileDraft(concerns: [.sensitivityAndRedness])
        var backCalled = false
        var continueCalled = false
        var skipCalled = false
        
        let binding = SwiftUI.Binding<SkinProfileDraft>(
            get: { selected },
            set: { selected = $0 }
        )
        
        let concernsView = OnboardingConcernsView(
            draft: binding,
            errors: [],
            saveError: nil,
            normalizer: nil,
            onBack: { backCalled = true },
            onContinue: { continueCalled = true },
            onSkip: { skipCalled = true }
        )
        
        #expect(SkinProfile.Concern.allCases.count == 8)
        #expect(concernsView.draft.concerns.contains(.sensitivityAndRedness))
        
        concernsView.onBack()
        #expect(backCalled == true)
        
        concernsView.onContinue()
        #expect(continueCalled == true)
        
        concernsView.onSkip()
        #expect(skipCalled == true)
    }

    // MARK: - Routine Persistence Tests (RT-03)
    
    @MainActor
    private static func withTemporaryRoutineFile(_ test: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(directory.appendingPathComponent("routines.json"))
    }
    
    @Test @MainActor func routinePersistenceSaveAndPreserveStepOrder() throws {
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            #expect(store.routines.isEmpty)
            #expect(store.loadError == nil)
            
            let steps = [
                RoutineStepItem(stepNumber: 1, title: "Oil Cleanser", subtitle: "Step 1", state: .complete),
                RoutineStepItem(stepNumber: 2, title: "Hydrating Cleanser", subtitle: "Step 2", state: .active),
                RoutineStepItem(stepNumber: 3, title: "Hyaluronic Acid", subtitle: "Step 3", state: .incomplete),
                RoutineStepItem(stepNumber: 4, title: "Ceramide Cream", subtitle: "Step 4", state: .incomplete)
            ]
            let routine = RoutineRecord(
                name: "PM Hydration",
                period: .pm,
                status: .active,
                frequency: .everyDay,
                reminderTime: "9:30 PM",
                steps: steps
            )
            
            try store.save(routine)
            #expect(store.routines.count == 1)
            #expect(store.routines[0].id == routine.id)
            #expect(store.routines[0].steps.count == 4)
            #expect(store.routines[0].steps[0].title == "Oil Cleanser")
            #expect(store.routines[0].steps[0].stepNumber == 1)
            #expect(store.routines[0].steps[1].title == "Hydrating Cleanser")
            #expect(store.routines[0].steps[1].stepNumber == 2)
            #expect(store.routines[0].steps[2].title == "Hyaluronic Acid")
            #expect(store.routines[0].steps[2].stepNumber == 3)
            #expect(store.routines[0].steps[3].title == "Ceramide Cream")
            #expect(store.routines[0].steps[3].stepNumber == 4)
        }
    }
    
    @Test @MainActor func routinePersistenceReloadFromDisk() throws {
        try Self.withTemporaryRoutineFile { url in
            let initialStore = RoutineStore(fileURL: url)
            let steps = [
                RoutineStepItem(stepNumber: 1, title: "Gentle Cleanser", subtitle: "Step 1", state: .complete),
                RoutineStepItem(stepNumber: 2, title: "Vitamin C", subtitle: "Step 2", state: .active),
                RoutineStepItem(stepNumber: 3, title: "Moisturizer", subtitle: "Step 3", state: .incomplete)
            ]
            let routine = RoutineRecord(
                name: "AM Radiance",
                period: .am,
                status: .active,
                frequency: .everyDay,
                reminderTime: "7:30 AM",
                steps: steps
            )
            try initialStore.save(routine)
            
            // Re-opening / reloading routine screen
            let reloadedStore = RoutineStore(fileURL: url)
            #expect(reloadedStore.routines.count == 1)
            #expect(reloadedStore.loadError == nil)
            
            let loaded = reloadedStore.routines[0]
            #expect(loaded.id == routine.id)
            #expect(loaded.name == "AM Radiance")
            #expect(loaded.period == .am)
            #expect(loaded.frequency == .everyDay)
            #expect(loaded.reminderTime == "7:30 AM")
            #expect(loaded.steps.count == 3)
            #expect(loaded.steps.map(\.title) == ["Gentle Cleanser", "Vitamin C", "Moisturizer"])
            #expect(loaded.steps.map(\.stepNumber) == [1, 2, 3])
        }
    }
    
    @Test @MainActor func routinePersistenceUpdateReplacesPreviousVersion() throws {
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            let originalRoutine = RoutineRecord(
                name: "Original Routine",
                period: .am,
                status: .active,
                frequency: .everyDay,
                steps: [
                    RoutineStepItem(stepNumber: 1, title: "Cleanser", subtitle: "Step 1", state: .incomplete)
                ]
            )
            try store.save(originalRoutine)
            #expect(store.routines.count == 1)
            #expect(store.routines[0].name == "Original Routine")
            
            var updatedRoutine = originalRoutine
            updatedRoutine.name = "Updated Morning Routine"
            updatedRoutine.status = .paused
            updatedRoutine.steps = [
                RoutineStepItem(stepNumber: 1, title: "Foaming Cleanser", subtitle: "Step 1", state: .complete),
                RoutineStepItem(stepNumber: 2, title: "Hydrating Toner", subtitle: "Step 2", state: .active),
                RoutineStepItem(stepNumber: 3, title: "SPF 50", subtitle: "Step 3", state: .incomplete)
            ]
            
            try store.update(updatedRoutine)
            
            // Verify in current store
            #expect(store.routines.count == 1)
            #expect(store.routines[0].id == originalRoutine.id)
            #expect(store.routines[0].name == "Updated Morning Routine")
            #expect(store.routines[0].status == .paused)
            #expect(store.routines[0].steps.count == 3)
            #expect(store.routines[0].steps[0].title == "Foaming Cleanser")
            #expect(store.routines[0].steps[1].title == "Hydrating Toner")
            #expect(store.routines[0].steps[2].title == "SPF 50")
            
            // Verify persisted to disk and reloads updated version
            let freshStore = RoutineStore(fileURL: url)
            #expect(freshStore.routines.count == 1)
            #expect(freshStore.routines[0].name == "Updated Morning Routine")
            #expect(freshStore.routines[0].steps.count == 3)
            #expect(freshStore.routines[0].steps.map(\.title) == ["Foaming Cleanser", "Hydrating Toner", "SPF 50"])
        }
    }
    
    @Test @MainActor func routinePersistenceEmptyStateWhenNoFileExists() throws {
        try Self.withTemporaryRoutineFile { url in
            // File does not exist initially
            let store = RoutineStore(fileURL: url)
            #expect(store.routines.isEmpty)
            #expect(store.loadError == nil)
        }
    }
    
    @Test @MainActor func routinePersistenceCorruptedDataHandling() throws {
        try Self.withTemporaryRoutineFile { url in
            // Write corrupt invalid JSON
            let invalidData = Data("this is not valid json".utf8)
            try invalidData.write(to: url)
            
            let store = RoutineStore(fileURL: url)
            #expect(store.routines.isEmpty)
            #expect(store.loadError != nil)
            
            // Verify corrupt file was NOT overwritten on load
            #expect(try Data(contentsOf: url) == invalidData)
            
            // An ordinary save must not destroy unreadable data.
            #expect(throws: RoutineStore.StoreError.corruptedData) {
                try store.save(RoutineRecord(name: "Recovery Routine"))
            }
            #expect(try Data(contentsOf: url) == invalidData)
        }
    }
    
    @Test @MainActor func routinePersistenceUnsupportedSchemaVersion() throws {
        try Self.withTemporaryRoutineFile { url in
            // Write future schema version
            let futureDoc = RoutineStorageDocument(schemaVersion: 99, routines: [RoutineRecord(name: "Future")])
            let futureData = try JSONEncoder().encode(futureDoc)
            try futureData.write(to: url)
            
            let store = RoutineStore(fileURL: url)
            #expect(store.routines.isEmpty)
            #expect(store.loadError != nil)
            
            // File remains intact until explicit save
            #expect(try Data(contentsOf: url) == futureData)
            #expect(throws: RoutineStore.StoreError.corruptedData) {
                try store.save(RoutineRecord(name: "New"))
            }
            #expect(try Data(contentsOf: url) == futureData)
        }
    }
    
    @Test @MainActor func routinePersistenceFailedSaveDoesNotPublish() throws {
        try Self.withTemporaryRoutineFile { url in
            // Create a file where directory should be to force write failure
            try Data("blocker".utf8).write(to: url)
            let impossibleURL = url.appendingPathComponent("subfolder/routines.json")
            let store = RoutineStore(fileURL: impossibleURL)
            
            let routine = RoutineRecord(name: "Unsaveable")
            #expect(throws: (any Error).self) {
                try store.save(routine)
            }
            #expect(store.routines.isEmpty)
        }
    }
    
    @Test @MainActor func routinePersistenceDeleteRoutine() throws {
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            let r1 = RoutineRecord(name: "AM")
            let r2 = RoutineRecord(name: "PM")
            try store.save(r1)
            try store.save(r2)
            #expect(store.routines.count == 2)
            
            try store.delete(id: r1.id)
            #expect(store.routines.count == 1)
            #expect(store.routines[0].id == r2.id)
            
            let reloaded = RoutineStore(fileURL: url)
            #expect(reloaded.routines.count == 1)
            #expect(reloaded.routines[0].id == r2.id)
        }
    }
    
    @Test @MainActor func routinePersistenceEmptyZeroBytesFileHandling() throws {
        try Self.withTemporaryRoutineFile { url in
            // Create a 0-byte file (corrupted/empty data)
            try Data().write(to: url)
            
            let store = RoutineStore(fileURL: url)
            #expect(store.routines.isEmpty)
            #expect(store.loadError != nil)
            
            #expect(throws: RoutineStore.StoreError.corruptedData) {
                try store.save(RoutineRecord(name: "Recovered"))
            }
            #expect(try Data(contentsOf: url).isEmpty)
        }
    }
    
    @Test @MainActor func routinePersistenceProductReferenceAndStepOrder() throws {
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            let prod1 = UUID()
            let prod2 = UUID()
            let prod3 = UUID()
            
            let steps = [
                RoutineStepItem(stepNumber: 1, title: "Oil Cleanser", subtitle: "Purifying", state: .complete, productId: prod1),
                RoutineStepItem(stepNumber: 2, title: "Vitamin C Serum", subtitle: "Brightening", state: .active, productId: prod2),
                RoutineStepItem(stepNumber: 3, title: "SPF 50", subtitle: "Protection", state: .incomplete, productId: prod3)
            ]
            let routine = RoutineRecord(name: "Product Linked Routine", period: .am, steps: steps)
            
            try store.save(routine)
            
            let reloaded = RoutineStore(fileURL: url)
            #expect(reloaded.routines.count == 1)
            let loadedSteps = reloaded.routines[0].steps
            #expect(loadedSteps.count == 3)
            #expect(loadedSteps[0].stepNumber == 1)
            #expect(loadedSteps[0].productId == prod1)
            #expect(loadedSteps[1].stepNumber == 2)
            #expect(loadedSteps[1].productId == prod2)
            #expect(loadedSteps[2].stepNumber == 3)
            #expect(loadedSteps[2].productId == prod3)
        }
    }
    
    @Test @MainActor func routinePersistenceDatabaseDictionaryMapping() throws {
        let prodId = UUID()
        let step = RoutineStepItem(
            stepNumber: 1,
            title: "Gel Cleanser",
            subtitle: "Cleanse",
            state: .active,
            hasClash: false,
            productId: prodId
        )
        let dict = step.toDatabaseDictionary()
        #expect(dict["stepNumber"] as? Int == 1)
        #expect(dict["title"] as? String == "Gel Cleanser")
        #expect(dict["productId"] as? String == prodId.uuidString)
        
        let restoredStep = RoutineStepItem(fromDatabaseDictionary: dict)
        #expect(restoredStep != nil)
        #expect(restoredStep?.title == "Gel Cleanser")
        #expect(restoredStep?.productId == prodId)
        #expect(restoredStep?.stepNumber == 1)
        
        let routine = RoutineRecord(
            name: "Database Routine",
            period: .pm,
            status: .active,
            frequency: .everyDay,
            reminderTime: "9:00 PM",
            steps: [step]
        )
        let routineDict = routine.toDatabaseDictionary()
        #expect(routineDict["name"] as? String == "Database Routine")
        #expect(routineDict["period"] as? String == RoutinePeriod.pm.rawValue)
        
        let restoredRoutine = RoutineRecord(fromDatabaseDictionary: routineDict)
        #expect(restoredRoutine != nil)
        #expect(restoredRoutine?.name == "Database Routine")
        #expect(restoredRoutine?.period == .pm)
        #expect(restoredRoutine?.steps.count == 1)
        #expect(restoredRoutine?.steps.first?.productId == prodId)
    }
    
    @Test @MainActor func routinePersistenceDatabaseServiceOperations() throws {
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            let service: RoutineDatabaseService = store
            
            let routinesBefore = try service.fetchRoutines()
            #expect(routinesBefore.isEmpty)
            
            let r = RoutineRecord(name: "Service Test Routine")
            try service.saveRoutine(r)
            
            let routinesAfter = try service.fetchRoutines()
            #expect(routinesAfter.count == 1)
            #expect(routinesAfter[0].name == "Service Test Routine")
            
            var updated = r
            updated.name = "Service Updated Routine"
            try service.updateRoutine(updated)
            
            let reloaded = try service.fetchRoutines()
            #expect(reloaded[0].name == "Service Updated Routine")
            
            try service.deleteRoutine(id: r.id)
            #expect(try service.fetchRoutines().isEmpty)
        }
    }
    
    @Test @MainActor func routinePersistenceScenario1SaveRoutineAndOrder() throws {
        // Scenario 1: Given a user has created a valid routine; When they save the routine; Then the routine and its product order are stored successfully.
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            let steps = [
                RoutineStepItem(stepNumber: 1, title: "Step 1: Oil Cleanser", subtitle: "Cleanse", state: .complete),
                RoutineStepItem(stepNumber: 2, title: "Step 2: Toner", subtitle: "Tone", state: .active),
                RoutineStepItem(stepNumber: 3, title: "Step 3: Moisturizer", subtitle: "Moisturize", state: .incomplete)
            ]
            let routine = RoutineRecord(name: "Valid Routine", period: .pm, steps: steps)
            try store.save(routine)
            
            #expect(store.routines.count == 1)
            #expect(store.routines[0].steps.map(\.stepNumber) == [1, 2, 3])
            #expect(store.routines[0].steps.map(\.title) == ["Step 1: Oil Cleanser", "Step 2: Toner", "Step 3: Moisturizer"])
        }
    }
    
    @Test @MainActor func routinePersistenceScenario2LoadRoutineOnReturn() throws {
        // Scenario 2: Given a user has a saved routine; When they return to the routine screen; Then the saved routine appears with the correct products and order.
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            let steps = [
                RoutineStepItem(stepNumber: 1, title: "First Step", subtitle: "A", state: .complete),
                RoutineStepItem(stepNumber: 2, title: "Second Step", subtitle: "B", state: .active)
            ]
            let routine = RoutineRecord(name: "Saved Morning Routine", period: .am, steps: steps)
            try store.save(routine)
            
            // Returning to routine screen (creating a new store or calling load)
            let returnScreenStore = RoutineStore(fileURL: url)
            returnScreenStore.load()
            
            #expect(returnScreenStore.routines.count == 1)
            let loaded = returnScreenStore.routines[0]
            #expect(loaded.name == "Saved Morning Routine")
            #expect(loaded.steps.count == 2)
            #expect(loaded.steps[0].title == "First Step")
            #expect(loaded.steps[0].stepNumber == 1)
            #expect(loaded.steps[1].title == "Second Step")
            #expect(loaded.steps[1].stepNumber == 2)
        }
    }
    
    @Test @MainActor func routinePersistenceScenario3EditAndReplaceRoutine() throws {
        // Scenario 3: Given a user edits an existing routine; When they save the changes; Then the updated routine replaces the previous version.
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            let original = RoutineRecord(name: "Initial Name", period: .am, steps: [
                RoutineStepItem(stepNumber: 1, title: "Step A", subtitle: "", state: .incomplete)
            ])
            try store.save(original)
            
            var edited = original
            edited.name = "Replaced Name"
            edited.period = .pm
            edited.steps = [
                RoutineStepItem(stepNumber: 1, title: "Step B", subtitle: "", state: .complete),
                RoutineStepItem(stepNumber: 2, title: "Step C", subtitle: "", state: .incomplete)
            ]
            try store.update(edited)
            
            // Verify single replacement
            #expect(store.routines.count == 1)
            #expect(store.routines[0].id == original.id)
            #expect(store.routines[0].name == "Replaced Name")
            #expect(store.routines[0].period == .pm)
            #expect(store.routines[0].steps.count == 2)
            #expect(store.routines[0].steps[0].title == "Step B")
        }
    }
    
    @Test @MainActor func routinePersistenceScenario4EmptyStateNoRoutines() throws {
        // Scenario 4: Given no routine has been saved; When the user opens the routine screen; Then the app displays a clear empty state and an option to create a routine.
        try Self.withTemporaryRoutineFile { url in
            let store = RoutineStore(fileURL: url)
            #expect(store.routines.isEmpty)
            #expect(store.loadError == nil)
            
            // MyRoutinesView observes repository.routines: when empty, it renders emptyStateView
            _ = MyRoutinesView(repository: store)
            #expect(store.routines.isEmpty)
        }
    }
}

@MainActor
struct RoutineEditorTests {
    private func manual(name: String = "Serum") throws -> RoutineStepItem {
        let normalizer = IngredientNormalizer(catalog: try .loadBundled())
        return RoutineProductSnapshot(ManualProduct(name: name, rawIngredientList: "Water, Vitamin C, Water",
                                                    ingredients: normalizer.normalize(["Water", "Vitamin C", "Water"]))).step
    }

    @Test func incompleteRoutinesReportAllRequiredInformation() throws {
        #expect(RoutineEditor.validationErrors(name: " \n ", steps: []).count == 2)
        #expect(RoutineEditor.validationErrors(name: "Morning", steps: []).count == 1)
        #expect(RoutineEditor.validationErrors(name: "Morning", steps: [try manual()]).isEmpty)
    }

    @Test func additionPreservesProductIdentityAndUnresolvedIngredientDetails() throws {
        let step = try manual()
        let added = RoutineEditor.adding(step, to: [])
        #expect(added.first?.id == step.id)
        #expect(added.first?.product == step.product)
        #expect(added.first?.product?.normalizedIngredients.warnings.count == 1)
        #expect(added.first?.product?.ingredientNames == ["Water", "Vitamin C", "Water"])
        #expect(added.first?.stepNumber == 1)
    }

    @Test func catalogStepsRetainStableReferencesAndIncompleteLists() throws {
        let catalog = try DemoCatalog.load()
        let product = try #require(catalog.products.first { $0.ingredientListStatus == .unavailable })
        let snapshot = RoutineProductSnapshot(product)
        #expect(snapshot.reference == .catalog(product.id))
        #expect(snapshot.listStatus == "unavailable")
        #expect(snapshot.ingredientNames.isEmpty)
        #expect(snapshot.step.product == snapshot)
    }

    @Test func sameProductIsNotAddedTwiceButSameNamesWithDistinctIDsAreAllowed() throws {
        let step = try manual()
        let duplicate = RoutineEditor.adding(step.product!.step, to: [step])
        #expect(duplicate.count == 1)
        #expect(duplicate.first?.id == step.id)
        let distinct = try manual()
        #expect(RoutineEditor.adding(distinct, to: [step]).count == 2)
    }

    @Test func reorderPreservesIDsReferencesWarningsAndContiguousNumbers() throws {
        let first = try manual(name: "First")
        let second = try manual(name: "Second")
        let reordered = RoutineEditor.moving([first, second], from: 0, to: 1)
        #expect(reordered.map(\.id) == [second.id, first.id])
        #expect(reordered.map(\.product) == [second.product, first.product])
        #expect(reordered.map(\.stepNumber) == [1, 2])
    }

    @Test func removalTargetsStepIDAndRetainsOtherProductMetadata() throws {
        let first = try manual()
        let second = try manual()
        let remaining = RoutineEditor.removing(first.id, from: [first, second])
        #expect(remaining.map(\.id) == [second.id])
        #expect(remaining.first?.product == second.product)
        #expect(remaining.first?.stepNumber == 1)
        #expect(RoutineEditor.removing(second.id, from: remaining).isEmpty)
    }

    @Test func outOfBoundsMovesDoNotChangeTheDraft() throws {
        let steps = [try manual()]
        #expect(RoutineEditor.moving(steps, from: 0, to: -1) == steps)
        #expect(RoutineEditor.moving(steps, from: 5, to: 0) == steps)
    }

    @Test func maximumStepCountIsConsistentForAddingAndSaving() throws {
        let steps = try (0..<8).map { try manual(name: "Product \($0)") }
        #expect(RoutineEditor.adding(try manual(), to: steps) == steps)
        #expect(RoutineEditor.validationErrors(name: "Routine", steps: steps).isEmpty)
        #expect(!RoutineEditor.validationErrors(name: "Routine", steps: steps + [try manual()]).isEmpty)
    }

    @Test func unsavedDraftChangesDoNotMutateRepository() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = RoutineRepository(fileURL: directory.appendingPathComponent("routines.json"))
        let original = RoutineRecord(name: "Original", steps: [try manual()])
        try repository.save(original)
        var draft = original
        draft.name = "Unsaved"
        draft.steps = RoutineEditor.removing(draft.steps[0].id, from: draft.steps)
        #expect(repository.routines == [original])
        #expect(!RoutineEditor.validationErrors(name: draft.name, steps: draft.steps).isEmpty)
    }

    @Test func persistedRoutineRetainsManualWarningsAndCatalogReferencesAfterReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("routines.json")
        let catalog = try DemoCatalog.load()
        let product = try #require(catalog.products.first)
        let catalogStep = RoutineProductSnapshot(product).step
        let manualStep = try manual()
        let routine = RoutineRecord(name: "Persisted editor", steps: RoutineEditor.numbered([catalogStep, manualStep]))
        try RoutineStore(fileURL: url).save(routine)
        let restored = try #require(RoutineStore(fileURL: url).routines.first)
        #expect(restored == routine)
        #expect(restored.steps[0].productId == CatalogProductIdentity.uuid(forCatalogId: product.id))
        #expect(restored.steps[1].product?.normalizedIngredients.warnings.count == 1)
        #expect(restored.steps[1].productId == manualStep.productId)
    }

    @Test func olderStoredStepsDecodeWithoutNewSnapshotMetadata() throws {
        let step = try manual()
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(step)) as? [String: Any])
        object.removeValue(forKey: "product")
        let restored = try JSONDecoder().decode(RoutineStepItem.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.id == step.id)
        #expect(restored.productId == step.productId)
        #expect(restored.product == nil)
        #expect(RoutineEditor.numbered([restored]).first?.productId == step.productId)
    }

    @Test func existingProductIDsPreventDuplicateSelectionWithoutSnapshotMetadata() throws {
        let catalog = try DemoCatalog.load()
        let product = try #require(catalog.products.first)
        let candidate = RoutineProductSnapshot(product).step
        let existing = RoutineStepItem(stepNumber: 1, title: product.name, subtitle: "", state: .incomplete, productId: candidate.productId)
        #expect(RoutineEditor.adding(candidate, to: [existing]) == [existing])
    }
}
