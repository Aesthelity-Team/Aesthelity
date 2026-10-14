//
//  ScanView.swift
//  Aesthelity
//
//  Aesthetic AI Skincare Ingredient Scanner & Routine Harmony Checker.
//

import SwiftUI
import PhotosUI

// MARK: - Scan Screen State

public enum ScanScreenState: String, CaseIterable, Identifiable {
    case viewfinder = "Viewfinder"
    case loading = "Analyzing"
    case saved = "Saved"
    case unableToReadLabel = "Unable to Read Label"
    case unableToReadBarcode = "Unable to Read Barcode"
    
    public var id: String { rawValue }
}

// MARK: - Scan Models & Data

public enum ScanMode: String, CaseIterable, Identifiable {
    case ingredients = "Ingredients"
    case barcode = "Barcode"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .ingredients: return "text.viewfinder"
        case .barcode: return "barcode.viewfinder"
        }
    }
}

public struct ScannedActiveIngredient: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let concentration: String
    public let role: String
    public let safetyLevel: IngredientSafetyLevel
    public let compatibilityNote: String
    
    public init(name: String, concentration: String, role: String, safetyLevel: IngredientSafetyLevel, compatibilityNote: String) {
        self.name = name
        self.concentration = concentration
        self.role = role
        self.safetyLevel = safetyLevel
        self.compatibilityNote = compatibilityNote
    }
}

public enum IngredientSafetyLevel: String, Equatable {
    case safe = "Harmonious"
    case caution = "Routine Caution"
    case clash = "Formula Clash"
    
    public var badgeColor: Color {
        switch self {
        case .safe: return Color(red: 0.62, green: 0.74, blue: 0.55) // #9EBD8D
        case .caution: return Color(red: 0.95, green: 0.78, blue: 0.45) // Amber
        case .clash: return Color(red: 0.95, green: 0.65, blue: 0.65) // Soft red
        }
    }
    
    public var textColor: Color {
        switch self {
        case .safe: return Color(red: 0.18, green: 0.32, blue: 0.14) // #2E5224
        case .caution: return Color(red: 0.45, green: 0.30, blue: 0.05)
        case .clash: return Color(red: 0.55, green: 0.15, blue: 0.18)
        }
    }
    
    public var iconName: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .clash: return "xmark.octagon.fill"
        }
    }
}

public struct ScanHistoryItem: Identifiable, Equatable {
    public let id = UUID()
    public let brand: String
    public let productName: String
    public let timeAgo: String
    public let safetyText: String
    public let safetyLevel: IngredientSafetyLevel
    public let actives: [String]
    
    public init(brand: String, productName: String, timeAgo: String, safetyText: String, safetyLevel: IngredientSafetyLevel, actives: [String]) {
        self.brand = brand
        self.productName = productName
        self.timeAgo = timeAgo
        self.safetyText = safetyText
        self.safetyLevel = safetyLevel
        self.actives = actives
    }
}

// MARK: - Viewfinder Reticle Corner Shape

struct ReticleCornerShape: Shape {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let corner: Corner
    let length: CGFloat
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
            
        case .topRight:
            path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.minY))
            
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
            
        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        }
        
        return path
    }
}

// MARK: - Animated Viewfinder Hero View

public struct AestheticScannerViewfinder: View {
    @Binding var scanMode: ScanMode
    @Binding var isFlashlightOn: Bool
    var onTriggerScan: () -> Void
    
    // Animation States
    @State private var scanLineOffset: CGFloat = -110
    @State private var auraPulse: CGFloat = 1.0
    @State private var auraOpacity: Double = 0.85
    
    public init(scanMode: Binding<ScanMode>, isFlashlightOn: Binding<Bool>, onTriggerScan: @escaping () -> Void) {
        self._scanMode = scanMode
        self._isFlashlightOn = isFlashlightOn
        self.onTriggerScan = onTriggerScan
    }
    
    public var body: some View {
        ZStack {
            // 1. Organic Ambient Glow Halo
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.45),
                                Color(red: 0.64, green: 0.73, blue: 0.56).opacity(0.40),
                                Color(red: 1.00, green: 0.79, blue: 0.61).opacity(0.45),
                                Color(red: 0.87, green: 0.85, blue: 0.96).opacity(0.50),
                                Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.45)
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: 310, height: 310)
                    .blur(radius: 28)
                    .scaleEffect(auraPulse)
                    .opacity(auraOpacity)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.94, green: 0.66, blue: 0.73).opacity(0.35),
                                Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.20),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 155
                        )
                    )
                    .frame(width: 290, height: 290)
                    .blur(radius: 20)
            }
            
            // 2. Viewfinder Frosted Squircle Frame
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 260, height: 260)
                    .shadow(color: Color(red: 0.10, green: 0.09, blue: 0.16).opacity(0.08), radius: 18, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(red: 0.85, green: 0.81, blue: 0.94).opacity(0.6),
                                        Color.white.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // 3. Subtle Target Silhouette inside frame
                VStack(spacing: 12) {
                    ZStack {
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.30), lineWidth: 1.5)
                                .frame(width: 22, height: 16)
                            Rectangle()
                                .fill(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.25))
                                .frame(width: 12, height: 6)
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.30), lineWidth: 1.5)
                                .frame(width: 48, height: 64)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Capsule()
                                            .fill(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.20))
                                            .frame(width: 28, height: 2.5)
                                        Capsule()
                                            .fill(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.15))
                                            .frame(width: 20, height: 2)
                                        Capsule()
                                            .fill(Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.15))
                                            .frame(width: 24, height: 2)
                                    }
                                )
                        }
                    }
                    .frame(height: 90)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.42, green: 0.69, blue: 0.38))
                            .frame(width: 6, height: 6)
                            .shadow(color: Color(red: 0.42, green: 0.69, blue: 0.38).opacity(0.6), radius: 3)
                        
                        Text(scanMode == .ingredients ? "Ready for Ingredients" : "Ready for Barcode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.97, green: 0.95, blue: 0.93))
                    .clipShape(Capsule())
                    
                    Text("Align label within frame")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.55, green: 0.50, blue: 0.65))
                }
                
                // 4. Precision Corner Reticle Brackets
                Group {
                    ReticleCornerShape(corner: .topLeft, length: 28, cornerRadius: 8)
                        .stroke(Color(red: 0.10, green: 0.09, blue: 0.16).opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                        .position(x: 24, y: 24)
                    
                    ReticleCornerShape(corner: .topRight, length: 28, cornerRadius: 8)
                        .stroke(Color(red: 0.10, green: 0.09, blue: 0.16).opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                        .position(x: 236, y: 24)
                    
                    ReticleCornerShape(corner: .bottomLeft, length: 28, cornerRadius: 8)
                        .stroke(Color(red: 0.10, green: 0.09, blue: 0.16).opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                        .position(x: 24, y: 236)
                    
                    ReticleCornerShape(corner: .bottomRight, length: 28, cornerRadius: 8)
                        .stroke(Color(red: 0.10, green: 0.09, blue: 0.16).opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                        .position(x: 236, y: 236)
                }
                
                // 5. Dynamic Animated Scanning Beam
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.clear, Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 200, height: 18)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.49, green: 0.51, blue: 0.74),
                                    Color(red: 0.50, green: 0.75, blue: 0.65),
                                    Color(red: 1.00, green: 0.79, blue: 0.61)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 210, height: 3.5)
                        .shadow(color: Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.6), radius: 6, x: 0, y: 0)
                    
                    LinearGradient(
                        colors: [Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.18), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 200, height: 18)
                }
                .offset(y: scanLineOffset)
                .clipped()
                
                // 6. Interactive Flashlight & Focus Controls
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isFlashlightOn.toggle()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isFlashlightOn ? Color(red: 0.44, green: 0.31, blue: 0.22) : Color.white.opacity(0.85))
                                    .frame(width: 32, height: 32)
                                    .shadow(color: Color.black.opacity(0.08), radius: 3)
                                
                                Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(isFlashlightOn ? Color.white : Color(red: 0.44, green: 0.31, blue: 0.22))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 18)
                        .padding(.top, 18)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: scanMode.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(scanMode.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.97, green: 0.95, blue: 0.93))
                        .clipShape(Capsule())
                        .padding(.trailing, 18)
                        .padding(.top, 18)
                    }
                    
                    Spacer()
                }
            }
            .frame(width: 260, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .onTapGesture {
                onTriggerScan()
            }
        }
        .frame(width: 310, height: 310)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            scanLineOffset = 110
        }
        
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            auraPulse = 1.06
            auraOpacity = 1.0
        }
    }
}

// MARK: - Pro Tip Card View

public struct ScanProTipCard: View {
    @State private var currentTipIndex: Int = 0
    
    let tips: [(title: String, body: String, icon: String)] = [
        ("Pro tip", "AI reads ingredient lists best in bright lighting.", "sparkles"),
        ("Clear View", "Hold bottles steady 4–6 inches away with text flat.", "viewfinder"),
        ("Safety First", "Ingredients are instantly checked against your routine to avoid clashes.", "shield.lefthalf.filled")
    ]
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentTipIndex = (currentTipIndex + 1) % tips.count
            }
        }) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.88, blue: 0.80),
                                    Color(red: 1.00, green: 0.82, blue: 0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: tips[currentTipIndex].icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.40, blue: 0.20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tips[currentTipIndex].title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            ForEach(0..<tips.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentTipIndex ? Color(red: 0.44, green: 0.31, blue: 0.22) : Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.25))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                    
                    Text(tips[currentTipIndex].body)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.95, blue: 0.90),
                        Color(red: 0.99, green: 0.89, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 1.00, green: 0.84, blue: 0.78).opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Scan Card

public struct RecentScanRowCard: View {
    public let item: ScanHistoryItem
    var onTap: () -> Void
    
    public init(item: ScanHistoryItem, onTap: @escaping () -> Void) {
        self.item = item
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.87, green: 0.85, blue: 0.96))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.productName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                        .lineLimit(1)
                    
                    Text("\(item.brand) · \(item.timeAgo)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: item.safetyLevel.iconName)
                        .font(.system(size: 11, weight: .bold))
                    Text(item.safetyText)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(item.safetyLevel.textColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(item.safetyLevel.badgeColor.opacity(0.85))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scan Analysis Result Sheet

public struct ScanResultSheet: View {
    public let scannedTitle: String
    public let scannedBrand: String
    public let compatibilityScore: Int
    public let actives: [ScannedActiveIngredient]
    public let routineSummary: String
    public var onDismiss: () -> Void
    
    @State private var isSavedToLibrary: Bool = false
    @State private var isAddedToRoutine: Bool = false
    
    public init(
        scannedTitle: String = "Niacinamide 10% + Zinc 1%",
        scannedBrand: String = "The Ordinary",
        compatibilityScore: Int = 94,
        actives: [ScannedActiveIngredient]? = nil,
        routineSummary: String = "Harmonious with your AM Routine. Safely layers before Daily Moisturizer and SPF 46.",
        onDismiss: @escaping () -> Void
    ) {
        self.scannedTitle = scannedTitle
        self.scannedBrand = scannedBrand
        self.compatibilityScore = compatibilityScore
        self.routineSummary = routineSummary
        self.onDismiss = onDismiss
        self.actives = actives ?? [
            ScannedActiveIngredient(
                name: "Niacinamide",
                concentration: "10%",
                role: "Sebum balancer & pores",
                safetyLevel: .safe,
                compatibilityNote: "Synergistic with your Gentle Cleanser & SPF 46."
            ),
            ScannedActiveIngredient(
                name: "Zinc PCA",
                concentration: "1%",
                role: "Anti-inflammatory & oil control",
                safetyLevel: .safe,
                compatibilityNote: "No clash detected with daytime actives."
            ),
            ScannedActiveIngredient(
                name: "Hyaluronic Acid",
                concentration: "1%",
                role: "Hydration booster",
                safetyLevel: .safe,
                compatibilityNote: "Enhances moisture retention."
            )
        ]
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.87, green: 0.85, blue: 0.96))
                                .frame(width: 52, height: 52)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(scannedBrand.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                            
                            Text(scannedTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ROUTINE HARMONY")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                                
                                Text("Confidence Score")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                            }
                            
                            Spacer()
                            
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(compatibilityScore)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                                Text("/100")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                            }
                        }
                        
                        Divider()
                            .overlay(Color(red: 0.85, green: 0.81, blue: 0.94))
                        
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(red: 0.28, green: 0.55, blue: 0.22))
                            Text(routineSummary)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                        }
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.00, green: 0.95, blue: 0.90), Color(red: 0.99, green: 0.89, blue: 0.93)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detected Active Ingredients (\(actives.count))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                        
                        ForEach(actives) { active in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(active.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                                    
                                    Text(active.concentration)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.87, green: 0.85, blue: 0.96))
                                        .clipShape(Capsule())
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: active.safetyLevel.iconName)
                                            .font(.system(size: 11))
                                        Text(active.safetyLevel.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundStyle(active.safetyLevel.textColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(active.safetyLevel.badgeColor.opacity(0.85))
                                    .clipShape(Capsule())
                                }
                                
                                Text(active.role)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
                                
                                Text(active.compatibilityNote)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16).opacity(0.8))
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1)
                            )
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAddedToRoutine.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: isAddedToRoutine ? "checkmark" : "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(isAddedToRoutine ? "Added to AM Routine" : "Add to AM Routine")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.44, green: 0.31, blue: 0.22))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSavedToLibrary.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: isSavedToLibrary ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(isSavedToLibrary ? "Saved in Library" : "Save to My Library")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Color(red: 0.97, green: 0.95, blue: 0.93))
            .navigationTitle("Scan Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                }
            }
        }
    }
}

// MARK: - Main ScanView

public struct ScanView: View {
    public var showsTabBar: Bool
    public var onSelectTab: ((Int) -> Void)?
    
    // State Variables
    @State private var screenState: ScanScreenState
    @State private var scanMode: ScanMode = .ingredients
    @State private var isFlashlightOn: Bool = false
    @State private var showScanResultSheet: Bool = false
    @State private var selectedHistoryItem: ScanHistoryItem?
    @State private var showProductDetailSheet: Bool = false
    @State private var isAddedToPMRoutine: Bool = false
    
    // Photo Picker State
    @State private var selectedPickerItem: PhotosPickerItem?
    
    // Sample Recent Scans
    @State private var recentScans: [ScanHistoryItem] = [
        ScanHistoryItem(
            brand: "The Ordinary",
            productName: "Niacinamide 10% + Zinc 1%",
            timeAgo: "2 hours ago",
            safetyText: "Harmonious",
            safetyLevel: .safe,
            actives: ["Niacinamide", "Zinc PCA"]
        ),
        ScanHistoryItem(
            brand: "Paula's Choice",
            productName: "Skin Perfecting 2% BHA Liquid",
            timeAgo: "Yesterday",
            safetyText: "PM Routine Only",
            safetyLevel: .caution,
            actives: ["Salicylic Acid", "Green Tea"]
        ),
        ScanHistoryItem(
            brand: "CeraVe",
            productName: "Hydrating Facial Cleanser",
            timeAgo: "3 days ago",
            safetyText: "Harmonious",
            safetyLevel: .safe,
            actives: ["Ceramides 1, 3, 6-II", "Hyaluronic Acid"]
        )
    ]
    
    public init(
        initialState: ScanScreenState = .viewfinder,
        showsTabBar: Bool = false,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self._screenState = State(initialValue: initialState)
        self.showsTabBar = showsTabBar
        self.onSelectTab = onSelectTab
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch screenState {
                case .viewfinder:
                    viewfinderContentView
                        .transition(.opacity)
                case .loading:
                    ScanLoadingView(
                        targetProgress: 0.82,
                        showsTabBar: false,
                        onSelectTab: onSelectTab,
                        onComplete: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .saved
                            }
                        }
                    )
                    .transition(.opacity)
                case .saved:
                    ScanSavedView(
                        productTitle: "Vitamin C Serum",
                        brand: "CeraVe",
                        routineMatch: 91,
                        isAddedToRoutine: isAddedToPMRoutine,
                        showsTabBar: false,
                        onSelectTab: onSelectTab,
                        onViewProductDetail: {
                            showProductDetailSheet = true
                        },
                        onToggleRoutine: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAddedToPMRoutine.toggle()
                            }
                        },
                        onScanAnother: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .viewfinder
                            }
                        }
                    )
                    .transition(.opacity)
                case .unableToReadLabel:
                    ScanErrorView(
                        errorType: .unableToReadLabel,
                        showsTabBar: false,
                        onTryAgain: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .loading
                            }
                        },
                        onSecondaryAction: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .loading
                            }
                        },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .viewfinder
                            }
                        },
                        onSelectTab: onSelectTab
                    )
                    .transition(.opacity)
                case .unableToReadBarcode:
                    ScanErrorView(
                        errorType: .unableToReadBarcode,
                        showsTabBar: false,
                        onTryAgain: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .loading
                            }
                        },
                        onSecondaryAction: {
                            scanMode = .ingredients
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .viewfinder
                            }
                        },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .viewfinder
                            }
                        },
                        onSelectTab: onSelectTab
                    )
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Standalone Bottom Tab Bar if requested
            if showsTabBar {
                scanTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.95, blue: 0.93))
        .sheet(isPresented: $showScanResultSheet) {
            ScanResultSheet(
                scannedTitle: selectedHistoryItem?.productName ?? "Niacinamide 10% + Zinc 1%",
                scannedBrand: selectedHistoryItem?.brand ?? "The Ordinary",
                compatibilityScore: selectedHistoryItem?.safetyLevel == .caution ? 74 : 94,
                routineSummary: selectedHistoryItem?.safetyLevel == .caution
                    ? "Contains 2% Salicylic Acid. Alternate with Vitamin C in AM to avoid skin barrier irritation."
                    : "Harmonious with your current AM routine. Safely layers before moisturizer and SPF 46.",
                onDismiss: {
                    showScanResultSheet = false
                    selectedHistoryItem = nil
                }
            )
        }
        .sheet(isPresented: $showProductDetailSheet) {
            ProductDetailView(
                product: ProductDatabase.shared.detail(forTitle: "Vitamin C Serum"),
                showsTabBar: false,
                fullScreenFrame: false,
                onBack: {
                    showProductDetailSheet = false
                }
            )
        }
        .onChange(of: selectedPickerItem) { _, newItem in
            guard newItem != nil else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                screenState = .loading
            }
        }
    }
    
    // MARK: - Viewfinder Content
    private var viewfinderContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                headerSection
                modeSelectorSection
                
                VStack(spacing: 0) {
                    AestheticScannerViewfinder(
                        scanMode: $scanMode,
                        isFlashlightOn: $isFlashlightOn,
                        onTriggerScan: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                screenState = .loading
                            }
                        }
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                
                actionButtonsSection
                ScanProTipCard()
                recentScansSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 24)
            .padding(.bottom, showsTabBar ? 24 : 36)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 1. Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center) {
                Text("Scan")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                    .lineLimit(1)
                
                Spacer()
                
                Text("Aesthelity")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                    .lineLimit(1)
            }
            
            Text("Analyze products instantly.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                .padding(.top, 2)
            
            Text("Check skincare labels for active synergy and routine harmony.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.47))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 2. Scan Mode Selector
    private var modeSelectorSection: some View {
        HStack(spacing: 8) {
            ForEach(ScanMode.allCases) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scanMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 13, weight: .medium))
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(scanMode == mode ? Color(red: 0.97, green: 0.95, blue: 0.93) : Color(red: 0.38, green: 0.33, blue: 0.47))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(scanMode == mode ? Color(red: 0.44, green: 0.31, blue: 0.22) : Color.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.85, green: 0.81, blue: 0.94), lineWidth: scanMode == mode ? 0 : 1)
                    )
                    .shadow(color: scanMode == mode ? Color.black.opacity(0.08) : Color.clear, radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(red: 0.92, green: 0.90, blue: 0.88).opacity(0.5))
        .clipShape(Capsule())
    }
    
    // MARK: - 4. Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Button 1: Scan Product (Primary Brand Coffee Brown Pill)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.35)) {
                    screenState = .loading
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Scan Product")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.47, green: 0.33, blue: 0.24),
                            Color(red: 0.40, green: 0.28, blue: 0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(red: 0.44, green: 0.31, blue: 0.22).opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Simulate: Unable to Read Label") {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        screenState = .unableToReadLabel
                    }
                }
                Button("Simulate: Unable to Read Barcode") {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        screenState = .unableToReadBarcode
                    }
                }
            }
            
            // Button 2: Upload Image (Periwinkle Pill with PhotosPicker)
            PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 17, weight: .medium))
                    Text("Upload Image")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.52, green: 0.54, blue: 0.77),
                            Color(red: 0.46, green: 0.48, blue: 0.71)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(red: 0.49, green: 0.51, blue: 0.74).opacity(0.28), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 6. Recent Scans Section
    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Scans")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.16))
                
                Spacer()
                
                Button(action: {
                    showScanResultSheet = true
                }) {
                    Text("View all")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.44, green: 0.31, blue: 0.22))
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 10) {
                ForEach(recentScans) { scan in
                    RecentScanRowCard(item: scan) {
                        selectedHistoryItem = scan
                        withAnimation(.easeInOut(duration: 0.35)) {
                            screenState = .saved
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Bottom Tab Bar (for Standalone / Previews)
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

#Preview("Scan - Viewfinder") {
    ScanView(initialState: .viewfinder, showsTabBar: true)
}

#Preview("Scan - Loading State") {
    ScanView(initialState: .loading, showsTabBar: true)
}

#Preview("Scan - Saved State") {
    ScanView(initialState: .saved, showsTabBar: true)
}

#Preview("Scan - Unable to Read Label") {
    ScanView(initialState: .unableToReadLabel, showsTabBar: true)
}

#Preview("Scan - Unable to Read Barcode") {
    ScanView(initialState: .unableToReadBarcode, showsTabBar: true)
}
