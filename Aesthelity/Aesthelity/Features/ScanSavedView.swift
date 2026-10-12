//
//  ScanSavedView.swift
//  Aesthelity
//
//  Scan Result / Saved to Library Screen for Aesthelity Skincare Scanner.
//

import SwiftUI

// MARK: - Stylized Saved Ribbon Icon

public struct SavedRibbonIcon: View {
    public var color: Color = Color(red: 0.46, green: 0.49, blue: 0.72)
    
    public init(color: Color = Color(red: 0.46, green: 0.49, blue: 0.72)) {
        self.color = color
    }
    
    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Horizontal base arm
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(color)
                .frame(width: 36, height: 12)
            
            // Vertical stem arm
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 26)
        }
        .frame(width: 36, height: 26)
    }
}

// MARK: - Scan Saved View

public struct ScanSavedView: View {
    public var productTitle: String = "Vitamin C Serum"
    public var brand: String = "CeraVe"
    public var routineMatch: Int = 91
    public var isAddedToRoutine: Bool = false
    public var showsTabBar: Bool = false
    public var onSelectTab: ((Int) -> Void)?
    public var onViewProductDetail: () -> Void
    public var onToggleRoutine: () -> Void
    public var onScanAnother: () -> Void
    
    public init(
        productTitle: String = "Vitamin C Serum",
        brand: String = "CeraVe",
        routineMatch: Int = 91,
        isAddedToRoutine: Bool = false,
        showsTabBar: Bool = false,
        onSelectTab: ((Int) -> Void)? = nil,
        onViewProductDetail: @escaping () -> Void = {},
        onToggleRoutine: @escaping () -> Void = {},
        onScanAnother: @escaping () -> Void = {}
    ) {
        self.productTitle = productTitle
        self.brand = brand
        self.routineMatch = routineMatch
        self.isAddedToRoutine = isAddedToRoutine
        self.showsTabBar = showsTabBar
        self.onSelectTab = onSelectTab
        self.onViewProductDetail = onViewProductDetail
        self.onToggleRoutine = onToggleRoutine
        self.onScanAnother = onScanAnother
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Header Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan Result")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(red: 0.38, green: 0.26, blue: 0.18))
                        
                        Text("\(productTitle) · \(brand)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    
                    // 2. Saved to Library Hero Card
                    VStack(spacing: 12) {
                        SavedRibbonIcon()
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                        
                        Text("Saved to Library")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(red: 0.38, green: 0.26, blue: 0.18))
                        
                        Text("\(productTitle) has been added\nto your saved products.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.bottom, 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    
                    // 3. Routine Match Card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(routineMatch)% Routine Match")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                        
                        Text("Compatible with your AM routine")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(red: 0.49, green: 0.51, blue: 0.65))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                    
                    // 4. Action Buttons
                    VStack(spacing: 12) {
                        // Primary Button: View Product Detail (BrandPill)
                        BrandPillButton("View Product Detail") {
                            onViewProductDetail()
                        }
                        
                        // Secondary Button: Add to PM Routine (Secondary)
                        LabeledButton(
                            isAddedToRoutine ? "Added to PM Routine" : "Add to PM Routine",
                            systemImage: isAddedToRoutine ? "checkmark" : nil,
                            variant: .secondary
                        ) {
                            onToggleRoutine()
                        }
                        
                        // Text Button: Scan another product (Tertiary)
                        LabeledButton(
                            "Scan another product",
                            variant: .tertiary
                        ) {
                            onScanAnother()
                        }
                    }
                    .padding(.top, 4)
                    
                    // 5. Recently Saved Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recently Saved")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color(red: 0.38, green: 0.26, blue: 0.18))
                            .padding(.top, 6)
                        
                        // Peach Card
                        Button(action: onViewProductDetail) {
                            HStack(spacing: 12) {
                                // Green rounded square
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.61, green: 0.73, blue: 0.55))
                                    .frame(width: 44, height: 44)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(productTitle)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color(red: 0.38, green: 0.26, blue: 0.18))
                                    
                                    Text("Just saved · \(routineMatch)% match")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.30))
                                }
                                
                                Spacer()
                                
                                // Saved pill tag
                                Text("Saved")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 1.00, green: 0.79, blue: 0.60))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Tab Bar (if standalone)
            if showsTabBar {
                scanTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.95, blue: 0.93))
    }
    
    // MARK: - Bottom Tab Bar (for Standalone / Previews)
    private var scanTabBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Tab 0: Home
                tabButton(title: "Home", systemImage: "house", isSelected: false, index: 0)
                
                // Tab 1: Library
                tabButton(title: "Library", systemImage: "books.vertical", isSelected: false, index: 1)
                
                // Tab 2: Scan (Center Elevated Button - Active)
                Button(action: {
                    onSelectTab?(2)
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.49, green: 0.51, blue: 0.74)) // periwinkle
                                .frame(width: 56, height: 56)
                                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                        }
                        
                        Text("Scan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                        
                        Capsule()
                            .fill(Color(red: 0.31, green: 0.34, blue: 0.56))
                            .frame(width: 16, height: 4)
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
                .frame(height: 34)
        }
        .frame(height: 106)
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

#Preview("Scan Saved - Result Screen") {
    ScanSavedView(showsTabBar: true)
}
