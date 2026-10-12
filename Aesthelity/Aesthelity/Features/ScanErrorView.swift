//
//  ScanErrorView.swift
//  Aesthelity
//
//  Error states for "Unable to read label" and "Unable to read barcode"
//  in Aesthelity Skincare Routine Optimizer scanner.
//

import SwiftUI
import PhotosUI

// MARK: - Scan Error Type

public enum ScanErrorType: String, CaseIterable, Identifiable {
    case unableToReadLabel = "Unable to Read Label"
    case unableToReadBarcode = "Unable to Read Barcode"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .unableToReadLabel:
            return "Unable to Read Label"
        case .unableToReadBarcode:
            return "Unable to Read Barcode"
        }
    }
    
    public var badgeText: String {
        switch self {
        case .unableToReadLabel:
            return "Unreadable Label"
        case .unableToReadBarcode:
            return "Unreadable Barcode"
        }
    }
    
    public var message: String {
        switch self {
        case .unableToReadLabel:
            return "We couldn't clearly detect the active ingredient list on this packaging."
        case .unableToReadBarcode:
            return "We couldn't detect or decode a valid barcode on this product."
        }
    }
    
    public var iconName: String {
        switch self {
        case .unableToReadLabel:
            return "text.viewfinder"
        case .unableToReadBarcode:
            return "barcode.viewfinder"
        }
    }
    
    public var primaryActionTitle: String {
        "Try Again"
    }
    
    public var secondaryActionTitle: String {
        switch self {
        case .unableToReadLabel:
            return "Upload Photo Instead"
        case .unableToReadBarcode:
            return "Scan Ingredient Label Instead"
        }
    }
    
    public var tips: [(title: String, subtitle: String, icon: String)] {
        switch self {
        case .unableToReadLabel:
            return [
                ("Bright, Even Light", "Position product away from harsh shadows or glare.", "sun.max.fill"),
                ("Hold Steady & Flat", "Keep bottle 4–6 inches away with text perpendicular.", "hand.raised.fill"),
                ("Curved Bottles", "Rotate curved cylinders slowly or smooth out crinkled tubes.", "arrow.triangle.2.circlepath")
            ]
        case .unableToReadBarcode:
            return [
                ("Align in Frame", "Fit the entire barcode and numbers inside the scan box.", "viewfinder"),
                ("Avoid Surface Glare", "Angle glossy surfaces slightly away from direct overhead lighting.", "lightbulb.fill"),
                ("Try Label Scan", "If the barcode is torn or curved, scan the ingredient text directly.", "doc.text.viewfinder")
            ]
        }
    }
}

// MARK: - Scan Error Hero Illustration

public struct ScanErrorHeroGraphic: View {
    public let errorType: ScanErrorType
    @State private var pulseScale: CGFloat = 1.0
    @State private var warningGlow: Double = 0.5
    
    public init(errorType: ScanErrorType) {
        self.errorType = errorType
    }
    
    public var body: some View {
        ZStack {
            // Ambient Aura Halo
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.95, green: 0.65, blue: 0.72).opacity(0.40),
                                Color(red: 1.00, green: 0.79, blue: 0.61).opacity(0.35),
                                Color(red: 0.87, green: 0.85, blue: 0.96).opacity(0.35),
                                Color(red: 0.95, green: 0.65, blue: 0.72).opacity(0.40)
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: 250, height: 250)
                    .blur(radius: 28)
                    .scaleEffect(pulseScale)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.93, green: 0.65, blue: 0.72).opacity(0.35),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 220, height: 220)
                    .blur(radius: 20)
            }
            
            // Frosted Center Card Frame
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 220, height: 200)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1.5)
                    )
                
                // Visual Reticle & Icon Content
                VStack(spacing: 12) {
                    ZStack {
                        // Soft round container
                        Circle()
                            .fill(Color(red: 0.99, green: 0.89, blue: 0.93))
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.93, green: 0.65, blue: 0.72).opacity(0.5), lineWidth: 1.5)
                            )
                        
                        // Icon according to error type
                        if errorType == .unableToReadLabel {
                            VStack(spacing: 3) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.43, green: 0.07, blue: 0.17))
                            }
                        } else {
                            VStack(spacing: 3) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.43, green: 0.07, blue: 0.17))
                            }
                        }
                    }
                    
                    // Alert Pill
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.43, green: 0.07, blue: 0.17))
                        
                        Text(errorType.badgeText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.43, green: 0.07, blue: 0.17))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.93, green: 0.65, blue: 0.72).opacity(0.85))
                    .clipShape(Capsule())
                    
                    Text(errorType == .unableToReadLabel ? "Text blurry or obscured" : "No barcode pattern detected")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.34))
                }
            }
            .frame(width: 220, height: 200)
        }
        .frame(height: 220)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
                warningGlow = 0.8
            }
        }
    }
}

// MARK: - Scan Error Tips Card

public struct ScanErrorTipsCard: View {
    public let tips: [(title: String, subtitle: String, icon: String)]
    
    public init(tips: [(title: String, subtitle: String, icon: String)]) {
        self.tips = tips
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                
                Text("Troubleshooting Tips")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
            }
            
            VStack(spacing: 12) {
                ForEach(0..<tips.count, id: \.self) { index in
                    let tip = tips[index]
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.87, green: 0.85, blue: 0.96))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: tip.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                            
                            Text(tip.subtitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    
                    if index < tips.count - 1 {
                        Divider()
                            .overlay(Color(red: 0.85, green: 0.81, blue: 0.94).opacity(0.6))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Main ScanErrorView

public struct ScanErrorView: View {
    public var errorType: ScanErrorType
    public var showsTabBar: Bool = false
    public var onTryAgain: () -> Void
    public var onSecondaryAction: () -> Void
    public var onDismiss: () -> Void
    public var onSelectTab: ((Int) -> Void)?
    
    // Photo picker item for direct image upload
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var currentErrorType: ScanErrorType
    
    public init(
        errorType: ScanErrorType = .unableToReadLabel,
        showsTabBar: Bool = false,
        onTryAgain: @escaping () -> Void = {},
        onSecondaryAction: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {},
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.errorType = errorType
        self.showsTabBar = showsTabBar
        self.onTryAgain = onTryAgain
        self.onSecondaryAction = onSecondaryAction
        self.onDismiss = onDismiss
        self.onSelectTab = onSelectTab
        self._currentErrorType = State(initialValue: errorType)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Navigation / Top Bar
                    topBarSection
                    
                    // 2. Error Type Switcher (Interactive for preview/testing)
                    typeSwitcherSection
                    
                    // 3. Hero Visual Graphic
                    ScanErrorHeroGraphic(errorType: currentErrorType)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    
                    // 4. Headline & Descriptive Explanation
                    descriptionSection
                    
                    // 5. Troubleshooting Tips Card
                    ScanErrorTipsCard(tips: currentErrorType.tips)
                    
                    // 6. Action Buttons
                    actionButtonsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, showsTabBar ? 24 : 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Standalone Bottom Tab Bar if requested
            if showsTabBar {
                scanTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.95, blue: 0.93))
        .onChange(of: errorType) { _, newValue in
            currentErrorType = newValue
        }
        .onChange(of: selectedPickerItem) { _, newItem in
            guard newItem != nil else { return }
            onSecondaryAction()
        }
    }
    
    // MARK: - Subviews
    
    private var topBarSection: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Scanner")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Aesthelity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
        }
    }
    
    private var typeSwitcherSection: some View {
        HStack(spacing: 8) {
            ForEach(ScanErrorType.allCases) { type in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentErrorType = type
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 12, weight: .medium))
                        Text(type.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(currentErrorType == type ? Color(red: 0.97, green: 0.95, blue: 0.93) : Color(red: 0.38, green: 0.33, blue: 0.47))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(currentErrorType == type ? Color(red: 0.44, green: 0.31, blue: 0.22) : Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: currentErrorType == type ? 0 : 1)
                    )
                    .shadow(color: currentErrorType == type ? Color.black.opacity(0.08) : Color.clear, radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(red: 0.92, green: 0.90, blue: 0.88).opacity(0.5))
        .clipShape(Capsule())
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentErrorType.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color(red: 0.38, green: 0.26, blue: 0.18))
            
            Text(currentErrorType.message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.34))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Button 1: Primary Try Again Pill
            BrandPillButton(currentErrorType.primaryActionTitle, systemImage: "arrow.clockwise", action: onTryAgain)
            
            // Button 2: Secondary Action
            if currentErrorType == .unableToReadLabel {
                PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(currentErrorType.secondaryActionTitle)
                    }
                }
                .buttonStyle(.appSecondary)
            } else {
                LabeledButton(currentErrorType.secondaryActionTitle, systemImage: "text.viewfinder", variant: .secondary, action: onSecondaryAction)
            }
            
            // Button 3: Return to Viewfinder text button
            LabeledButton("Return to Scanner", variant: .tertiary, action: onDismiss)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Standalone Tab Bar
    
    private var scanTabBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                tabButton(title: "Home", systemImage: "house", isSelected: false, index: 0)
                tabButton(title: "Library", systemImage: "books.vertical", isSelected: false, index: 1)
                
                Button(action: {
                    onSelectTab?(2)
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.49, green: 0.51, blue: 0.74))
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
                
                tabButton(title: "Explore", systemImage: "magnifyingglass", isSelected: false, index: 3)
                tabButton(title: "Profile", systemImage: "person", isSelected: false, index: 4)
            }
            .frame(height: 72)
            
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

// MARK: - Previews

#Preview("Scan Error - Unable to Read Label") {
    ScanErrorView(errorType: .unableToReadLabel, showsTabBar: true)
}

#Preview("Scan Error - Unable to Read Barcode") {
    ScanErrorView(errorType: .unableToReadBarcode, showsTabBar: true)
}
