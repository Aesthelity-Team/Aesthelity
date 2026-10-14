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
        
        // 7. Verify all unique products in database
        #expect(db.allProducts.count == 14)
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
    
    @Test func skinProfileIsPassedToProfileAndContentViews() throws {
        let skinProfile = SkinProfile(skinType: .oily, concerns: [.acneProne], setupStatus: .completed)

        #expect(ProfileView().skinProfile == SkinProfile())
        #expect(ProfileView(skinProfile: skinProfile).skinProfile == skinProfile)
        #expect(ContentView(skinProfile: .constant(skinProfile)).skinProfile == skinProfile)
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
        let contentView = ContentView()
        #expect(contentView.showClashDemo == true)
        #expect(contentView.selectedPeriod == .am)
        
        // In default clash demo state for AM
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
        let contentView = ContentView(showClashDemo: false)
        
        let normalSteps = contentView.currentSteps
        #expect(normalSteps.count == 4)
        #expect(normalSteps.allSatisfy { $0.hasClash == false })
        #expect(normalSteps[0].title == "Gentle Cleanser")
        #expect(normalSteps[1].title == "Vitamin C Serum")
        #expect(normalSteps[2].title == "Daily Moisturizer")
        #expect(normalSteps[3].title == "SPF 46")
    }
    
    @Test func contentViewPopulatedRoutineHasNoEmptyMessage() throws {
        #expect(ContentView(selectedPeriod: .am).emptyRoutineMessage == nil)
        #expect(ContentView(selectedPeriod: .am, showClashDemo: false).emptyRoutineMessage == nil)
        #expect(ContentView(selectedPeriod: .pm).emptyRoutineMessage == nil)
    }

    @Test func contentViewEmptySelectedRoutineShowsMessage() throws {
        let sampleAM = ContentView(selectedPeriod: .am, showClashDemo: false).currentSteps

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
    
    @Test func routineRepositoryDefaults() throws {
        let repo = RoutineRepository.shared
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
            onSaveRoutine: { rec in savedRecord = rec }
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
        var finishedProfile: SkinProfile?
        let flow = StartupFlowView(initialScreen: .welcome) { profile in
            finishedProfile = profile
        }
        #expect(flow.currentScreen == .welcome)
        flow.onFinish(SkinProfile())
        #expect(finishedProfile == SkinProfile())
        
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
}
