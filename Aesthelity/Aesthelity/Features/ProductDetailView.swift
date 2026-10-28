//
//  ProductDetailView.swift
//  Aesthelity
//
//  Versatile Product Detail Screen for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - Main ProductDetailView

/// Dedicated screen displaying the product's relationships, AM/PM routine compatibility,
/// ingredients, and ingredient guidance.
public struct ProductDetailView: View {
    // State & Properties
    public var product: ProductDetailItem
    public var backTitle: String
    public var showsTabBar: Bool
    public var fullScreenFrame: Bool
    public var onBack: (() -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    
    @State private var isSaved: Bool
    @State private var isAvoided: Bool
    @State private var showAddToRoutineSheet: Bool = false
    @State private var routineToastMessage: String? = nil
    
    // MARK: - Backward-compatible Initializers (no backTitle parameter)

    public init(
        product: ProductDetailItem,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            product: product,
            backTitle: "Library",
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }

    public init(
        productId: UUID,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: productId,
            backTitle: "Library",
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }

    public init(
        id: UUID,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: id,
            backTitle: "Library",
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }

    public init(
        productId: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: productId,
            backTitle: "Library",
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }

    public init(
        id: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: id,
            backTitle: "Library",
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }

    // MARK: - Initializers with custom backTitle

    public init(
        product: ProductDetailItem,
        backTitle: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.product = product
        self.backTitle = backTitle
        self.showsTabBar = showsTabBar
        self.fullScreenFrame = fullScreenFrame
        self.onBack = onBack
        self.onSelectTab = onSelectTab
        self._isSaved = State(initialValue: product.isSaved)
        self._isAvoided = State(initialValue: product.isAvoided)
    }
    
    public init(
        productId: UUID,
        backTitle: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        let resolved = ProductDatabase.shared.detail(for: productId)
        self.init(
            product: resolved,
            backTitle: backTitle,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    public init(
        id: UUID,
        backTitle: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: id,
            backTitle: backTitle,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    public init(
        productId: String,
        backTitle: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        let resolved = ProductDatabase.shared.detail(forId: productId)
            ?? ProductDatabase.shared.detail(forTitle: productId)
        self.init(
            product: resolved,
            backTitle: backTitle,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    public init(
        id: String,
        backTitle: String,
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.init(
            productId: id,
            backTitle: backTitle,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }

    /// Look up product directly from DemoProduct.
    public init(
        demoProduct: DemoProduct,
        backTitle: String = "Catalog",
        showsTabBar: Bool = true,
        fullScreenFrame: Bool = true,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        let item = ProductDatabase.shared.detail(forDemoProduct: demoProduct)
        self.init(
            product: item,
            backTitle: backTitle,
            showsTabBar: showsTabBar,
            fullScreenFrame: fullScreenFrame,
            onBack: onBack,
            onSelectTab: onSelectTab
        )
    }
    
    public var body: some View {
        Group {
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
        .sheet(isPresented: $showAddToRoutineSheet) {
            detailAddToRoutineSheet
        }
        .overlay(alignment: .bottom) {
            if let message = routineToastMessage {
                toastBanner(message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, showsTabBar ? 90 : 24)
            }
        }
    }
    
    private var mainContentVStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Navigation Bar (< Library / Back)
                    backButtonSection
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    
                    // Product Title & Subtitle Header
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
                    
                    // Action Buttons: "Save product", "Avoid", and "Add to routine"
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
                        .padding(.bottom, 20)

                    // Ingredients & Guidance Section
                    ingredientSection
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
                Text(backTitle)
                    .font(.system(size: 16, weight: .regular))
            }
            .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.58))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.backButton")
    }
    
    // MARK: - 2. Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                .accessibilityIdentifier("detail.title")
            
            Text(product.subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                .accessibilityIdentifier("detail.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 3. Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Save Product Button (BrandPill)
                BrandPillButton(isSaved ? "Saved" : "Save product") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSaved.toggle()
                    }
                }
                .accessibilityIdentifier("detail.saveButton")
                
                // Avoid Button (Secondary / Destructive)
                LabeledButton(
                    isAvoided ? "Avoided" : "Avoid",
                    variant: isAvoided ? .destructive : .secondary
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isAvoided.toggle()
                    }
                }
                .accessibilityIdentifier("detail.avoidButton")
            }

            // Add to Routine Quick Button
            Button(action: {
                showAddToRoutineSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add to Routine")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#50578F"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "#DFD8F5").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("detail.addToRoutineButton")
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
                .accessibilityIdentifier("detail.routineFitTitle")
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
                .fill(Color(red: 0.87, green: 0.85, blue: 0.96))
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

    // MARK: - 6. Ingredients & Guidance Section
    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ingredients")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.26, green: 0.16, blue: 0.11))
                        .accessibilityIdentifier("detail.ingredientsTitle")
                    
                    Text("Formulation breakdown & guidance")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                }
                
                Spacer()
                
                ingredientStatusPill
            }
            
            // Active Ingredient Guidance
            if let guidance = product.ingredientGuidance, !guidance.isEmpty {
                guidanceCard(guidance)
            }
            
            // Formula display: chips or unavailable banner
            if product.ingredientListStatus == .unavailable || product.ingredients.isEmpty {
                unavailableIngredientsCard
            } else {
                ingredientsChipsView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("detail.ingredientSection")
    }

    @ViewBuilder
    private var ingredientStatusPill: some View {
        switch product.ingredientListStatus {
        case .complete:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text("\(product.ingredients.count) ingredients")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color(hex: "#2E5224"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#EAF2EC"))
            .clipShape(Capsule())
            .accessibilityIdentifier("detail.statusBadge.complete")

        case .partial:
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                Text("Partial formula")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color(hex: "#625478"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#DFD8F5").opacity(0.7))
            .clipShape(Capsule())
            .accessibilityIdentifier("detail.statusBadge.partial")

        case .unavailable:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text("Unavailable")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color(hex: "#9E2A2B"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#FDE8E1"))
            .clipShape(Capsule())
            .accessibilityIdentifier("detail.statusBadge.unavailable")
        }
    }

    private func guidanceCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#50578F"))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Ingredient Guidance")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Text(text)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "#3E3A4A"))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#FAF8F5"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#E8DFD8"), lineWidth: 1)
        )
        .accessibilityIdentifier("detail.ingredientGuidance")
    }

    private var unavailableIngredientsCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#D05353"))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Ingredient list unavailable")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#6D122B"))
                
                Text("The formulation for this product is not yet verified or provided. Routine clash detection cannot be confirmed.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "#6D122B").opacity(0.85))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#FFF4F2"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#FAD2C8"), lineWidth: 1)
        )
        .accessibilityIdentifier("detail.ingredientsUnavailable")
    }

    private var ingredientsChipsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(product.ingredients, id: \.self) { ingredient in
                    let isActive = isKeyActive(ingredient)
                    HStack(spacing: 5) {
                        if isActive {
                            Circle()
                                .fill(Color(hex: "#7C83BC"))
                                .frame(width: 6, height: 6)
                        }
                        Text(ingredient)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? Color(hex: "#1A1628") : Color(hex: "#3E3A4A"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isActive ? Color(hex: "#DFD8F5").opacity(0.6) : Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isActive ? Color(hex: "#7C83BC").opacity(0.6) : Color(hex: "#E5E0EE"), lineWidth: 1)
                    )
                }
            }
            .accessibilityIdentifier("detail.ingredientList")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
        )
    }

    private func isKeyActive(_ ingredient: String) -> Bool {
        let lower = ingredient.lowercased()
        let keyActives = [
            "retinol", "retinoid", "ascorbic", "vitamin c", "niacinamide",
            "salicylic", "glycolic", "lactic", "hyaluron", "zinc", "centella",
            "squalane", "panthenol", "ceramide", "caffeine", "peptides", "azelaic"
        ]
        return keyActives.contains { lower.contains($0) }
    }

    // MARK: - Add to Routine Sheet
    private var detailAddToRoutineSheet: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Add to Routine")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Text(product.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#625478"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 24)
            
            VStack(spacing: 12) {
                Button(action: {
                    commitAddToRoutine(period: .am)
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#DDA15E").opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: "#DDA15E"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AM Routine")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#1A1628"))
                            Text("Morning skincare routine")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#625478"))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#7C83BC"))
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail.sheet.addAM")

                Button(action: {
                    commitAddToRoutine(period: .pm)
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#7C83BC").opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: "#7C83BC"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PM Routine")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#1A1628"))
                            Text("Evening skincare routine")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#625478"))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#7C83BC"))
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail.sheet.addPM")
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: {
                showAddToRoutineSheet = false
            }) {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#625478"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#EFEBF5"))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(340)])
    }

    private func commitAddToRoutine(period: RoutinePeriod) {
        let routineName = period == .am ? "AM Routine" : "PM Routine"
        showAddToRoutineSheet = false
        do {
            _ = try RoutineStore.shared.addProduct(
                title: product.title,
                subtitle: "\(product.brand) · \(product.category.rawValue)",
                period: period,
                productId: product.id
            )
            withAnimation {
                routineToastMessage = "Added \(product.title) to \(routineName)!"
            }
        } catch {
            withAnimation {
                routineToastMessage = "Could not save \(product.title) to \(routineName). Please try again."
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                routineToastMessage = nil
            }
        }
    }

    private func toastBanner(_ message: String) -> some View {
        let isError = message.localizedCaseInsensitiveContains("could not save")
        return HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? Color(hex: "#842029") : Color(hex: "#2E5224"))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#1A1628"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isError ? Color(hex: "#F8D7DA") : Color(hex: "#EAF2EC"))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isError ? Color(hex: "#F5C2C7") : Color(hex: "#D4EDDA"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - 7. Bottom Tab Bar
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
