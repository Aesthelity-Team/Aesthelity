//
//  AddProductToRoutineView.swift
//  Aesthelity
//
//  Add Product to Routine screen with search, conflict banners, empty search state,
//  routine chooser, and success confirmation.
//

import SwiftUI

public struct RoutineProductItem: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let brand: String
    public let category: String
    public let periodSlot: RoutinePeriod
    public let isSafe: Bool
}

public struct AddProductToRoutineView: View {
    public var currentRoutineName: String = "AM Glow"
    public var existingStepTitles: Set<String> = []
    public var onProductSelected: (RoutineStepItem) -> Void
    public var onCancel: () -> Void
    
    // States
    @State private var searchText: String = ""
    @State private var selectedSlot: RoutinePeriod = .am
    @State private var conflictProduct: String? = nil
    @State private var showChooseRoutineSheet: Bool = false
    @State private var pendingSelectedProduct: RoutineProductItem? = nil
    @State private var showSuccessScreen: Bool = false
    @State private var addedStepItem: RoutineStepItem? = nil
    
    // Catalog of available products
    private let availableProducts: [RoutineProductItem] = [
        RoutineProductItem(title: "Niacinamide Serum", brand: "The Ordinary", category: "Pore refining & oil balance", periodSlot: .am, isSafe: true),
        RoutineProductItem(title: "Hyaluronic Acid 2% + B5", brand: "The Ordinary", category: "Deep surface hydration", periodSlot: .am, isSafe: true),
        RoutineProductItem(title: "Centella Soothing Cream", brand: "Skin1004", category: "Calming & barrier repair", periodSlot: .pm, isSafe: true),
        RoutineProductItem(title: "Vitamin C Serum", brand: "Drunk Elephant", category: "Brightening antioxidant", periodSlot: .am, isSafe: true),
        RoutineProductItem(title: "Retinol 0.5% in Squalane", brand: "The Ordinary", category: "Cellular renewal", periodSlot: .pm, isSafe: true),
        RoutineProductItem(title: "BHA Liquid Exfoliant", brand: "Paula's Choice", category: "Salicylic acid exfoliation", periodSlot: .pm, isSafe: true)
    ]
    
    public init(
        currentRoutineName: String = "AM Glow",
        existingStepTitles: Set<String> = [],
        onProductSelected: @escaping (RoutineStepItem) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        self.currentRoutineName = currentRoutineName
        self.existingStepTitles = existingStepTitles
        self.onProductSelected = onProductSelected
        self.onCancel = onCancel
    }
    
    private var filteredProducts: [RoutineProductItem] {
        availableProducts.filter { product in
            let matchesSearch = searchText.isEmpty ||
                product.title.localizedCaseInsensitiveContains(searchText) ||
                product.brand.localizedCaseInsensitiveContains(searchText)
            let matchesSlot = product.periodSlot == selectedSlot
            return matchesSearch && matchesSlot
        }
    }
    
    public var body: some View {
        ZStack {
            if showSuccessScreen, let step = addedStepItem {
                RoutineUpdatedView(
                    productTitle: step.title,
                    stepNumber: step.stepNumber,
                    routineName: currentRoutineName,
                    onViewRoutine: {
                        onProductSelected(step)
                    },
                    onBackHome: {
                        onProductSelected(step)
                    }
                )
            } else {
                mainContent
            }
        }
        .sheet(isPresented: $showChooseRoutineSheet) {
            if let product = pendingSelectedProduct {
                ChooseRoutineView(
                    productTitle: product.title,
                    currentRoutine: currentRoutineName,
                    onSelectRoutine: { targetRoutine in
                        showChooseRoutineSheet = false
                        confirmAddProduct(product, to: targetRoutine)
                    },
                    onCancel: {
                        showChooseRoutineSheet = false
                    }
                )
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#6F4E37"))
                }
                
                Spacer()
                
                Text("Add to routine")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Spacer()
                
                Button("Done") {
                    onCancel()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "#625478"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#625478"))
                
                TextField("Search products or brands...", text: $searchText)
                    .font(.system(size: 15))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#625478"))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // Conflict Alert Banner
            if let conflict = conflictProduct {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "#D9534F"))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Already in this routine")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#842029"))
                        
                        Text("\(conflict) is already part of \(currentRoutineName).")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#842029").opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Button(action: { conflictProduct = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#842029"))
                    }
                }
                .padding(14)
                .background(Color(hex: "#F8D7DA"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            
            // Slot filter pills
            HStack(spacing: 12) {
                slotPill(title: "AM slot", isSelected: selectedSlot == .am) {
                    selectedSlot = .am
                }
                slotPill(title: "PM slot", isSelected: selectedSlot == .pm) {
                    selectedSlot = .pm
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            
            // Product list or Empty state
            if filteredProducts.isEmpty {
                emptySearchStateView
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(filteredProducts) { product in
                            productCard(product: product)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(hex: "#F7F3ED"))
    }
    
    private func slotPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color(hex: "#1A1628"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "#7C83BC") : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#DFD8F5"), lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func productCard(product: RoutineProductItem) -> some View {
        let isAlreadyAdded = existingStepTitles.contains(product.title)
        
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(product.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    
                    if product.isSafe {
                        Text("Safe")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#2E5224"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#D4EDDA"))
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(product.brand) · \(product.category)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            
            Spacer()
            
            Button(action: {
                if isAlreadyAdded {
                    withAnimation {
                        conflictProduct = product.title
                    }
                } else {
                    pendingSelectedProduct = product
                    showChooseRoutineSheet = true
                }
            }) {
                Text(isAlreadyAdded ? "Added" : "Add")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isAlreadyAdded ? Color(hex: "#625478") : Color(hex: "#50578F"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(isAlreadyAdded ? Color(hex: "#EFEBF5") : Color(hex: "#DFD8F5"))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
        )
    }
    
    private var emptySearchStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            RoutineEmptyIllustration(size: 80)
            
            VStack(spacing: 6) {
                Text("No products found")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Text("Nothing matches '\(searchText)'. Clear search or go back to keep your routine unchanged.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#625478"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            LabeledButton("Clear search", variant: .secondary) {
                searchText = ""
            }
            .frame(maxWidth: 160)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func confirmAddProduct(_ product: RoutineProductItem, to routine: String) {
        let newStep = RoutineStepItem(
            stepNumber: existingStepTitles.count + 1,
            title: product.title,
            subtitle: "\(product.brand) · Step \(existingStepTitles.count + 1)",
            state: .incomplete,
            productId: product.id
        )
        addedStepItem = newStep
        withAnimation {
            showSuccessScreen = true
        }
    }
}

// MARK: - Choose Routine Sheet

public struct ChooseRoutineView: View {
    public var productTitle: String
    public var currentRoutine: String
    public var onSelectRoutine: (String) -> Void
    public var onCancel: () -> Void
    
    private let sampleRoutines = ["AM Glow", "PM Repair", "Weekly Exfoliate"]
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Choose routine")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "#625478"))
                }
            }
            
            Text("Where should \(productTitle) go?")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#625478"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 10) {
                ForEach(sampleRoutines, id: \.self) { rName in
                    Button(action: { onSelectRoutine(rName) }) {
                        HStack {
                            Text(rName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "#1A1628"))
                            
                            Spacer()
                            
                            if rName == currentRoutine {
                                Text("Current")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "#50578F"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "#DFD8F5"))
                                    .clipShape(Capsule())
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#625478"))
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .background(Color(hex: "#F7F3ED"))
    }
}

// MARK: - Routine Updated Success Screen

public struct RoutineUpdatedView: View {
    public var productTitle: String
    public var stepNumber: Int
    public var routineName: String
    public var onViewRoutine: () -> Void
    public var onBackHome: () -> Void
    
    public var body: some View {
        VStack(spacing: 0) {
            // Success top banner
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#2E5224"))
                Text("Step added")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#2E5224"))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "#D4EDDA"))
            
            Spacer()
            
            VStack(spacing: 24) {
                // Graphic
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#7C83BC"), Color(hex: "#EDA5B7")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.white)
                }
                
                VStack(spacing: 8) {
                    Text("Routine updated")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    
                    Text("\(productTitle) is now step \(stepNumber) in \(routineName).")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#625478"))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    LabeledButton("View updated routine", variant: .primary) {
                        onViewRoutine()
                    }
                    
                    LabeledButton("Back to Home", variant: .secondary) {
                        onBackHome()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .padding(24)
            
            Spacer()
        }
        .background(Color(hex: "#F7F3ED"))
    }
}
