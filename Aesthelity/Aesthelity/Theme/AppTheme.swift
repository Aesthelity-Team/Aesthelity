//
//  AppTheme.swift
//  Aesthelity
//
//  Design system tokens and theme definitions.
//

import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
    /// Initializes a Color from a hexadecimal string (e.g., "#A3B18A" or "A3B18A").
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - AppTheme Namespace

/// Central design system theme tokens for Aesthelity.
public enum AppTheme {
    
    // MARK: - Semantic Tokens (from Figma / Design System)
    public enum Semantic {
        /// Canvas surface: #FAF7FF (Color(red: 0.98, green: 0.97, blue: 1))
        public static let surfaceCanvas = Color(red: 0.98, green: 0.97, blue: 1)
        /// Base background: #F7F3ED (warm cream)
        public static let surfaceBase = Color(hex: "#F7F3ED")
        /// Raised surface / Card background: #FFFFFF
        public static let surfaceRaised = Color(hex: "#FFFFFF")
        /// Subtle surface: #DFD8F5 (light lavender)
        public static let surfaceSubtle = Color(hex: "#DFD8F5")
        /// Accent surface: #7C83BC (periwinkle lavender)
        public static let surfaceAccent = Color(hex: "#7C83BC")
        
        /// Primary ink: #1A1628 (deep dark plum/navy)
        public static let inkPrimary = Color(hex: "#1A1628")
        /// Secondary ink: #625478 (muted slate purple)
        public static let inkSecondary = Color(hex: "#625478")
        /// Brand ink: #6F4E37 (rich coffee brown)
        public static let inkBrand = Color(hex: "#6F4E37")
        /// Accent ink: #50578F (indigo purple)
        public static let inkAccent = Color(hex: "#50578F")
        /// Inverse ink: #F7F3ED (warm cream text on dark backgrounds)
        public static let inkInverse = Color(hex: "#F7F3ED")
        
        /// Hairline border: #D8CFF0
        public static let lineHairline = Color(hex: "#D8CFF0")
        
        // Gradient stops for Routine Card
        public static let gradientStart = Color(hex: "#FECA9B")
        public static let gradientMiddle = Color(hex: "#F0A8BA")
        public static let gradientEnd = Color(hex: "#7C83BC")
        public static let analysisLink = Color(hex: "#FFCC99")
        
        // Confidence Card Gradient Background
        public static let confidenceGradientStart = Color(hex: "#FFF2E6")
        public static let confidenceGradientEnd = Color(hex: "#FCE4EC")
    }
    
    // MARK: - Colors
    public enum Colors {
        /// Primary Background: #FFFFFF
        public static let primaryBackground = Color(hex: "#FFFFFF")
        
        /// Surface/Card Background: #F5F5F5
        public static let cardBackground = Color(hex: "#F5F5F5")
        
        /// Primary Text: #1A1A1A
        public static let primaryText = Color(hex: "#1A1A1A")
        
        /// Secondary Text: #808080
        public static let secondaryText = Color(hex: "#808080")
        
        /// Accent/Brand Color: #A3B18A
        public static let accent = Color(hex: "#A3B18A")
        
        /// Light tint of accent for backgrounds/chips
        public static let accentLight = Color(hex: "#A3B18A").opacity(0.15)
        
        /// Border color for subtle dividers and cards
        public static let border = Color(hex: "#1A1A1A").opacity(0.08)
        
        // Aliases to Semantic tokens
        public static let surfaceCanvas = Semantic.surfaceCanvas
        public static let surfaceBase = Semantic.surfaceBase
        public static let surfaceRaised = Semantic.surfaceRaised
        public static let surfaceSubtle = Semantic.surfaceSubtle
        public static let surfaceAccent = Semantic.surfaceAccent
        public static let inkPrimary = Semantic.inkPrimary
        public static let inkSecondary = Semantic.inkSecondary
        public static let inkBrand = Semantic.inkBrand
        public static let inkAccent = Semantic.inkAccent
        public static let inkInverse = Semantic.inkInverse
        public static let lineHairline = Semantic.lineHairline
    }
    
    // MARK: - Typography
    public enum Typography {
        /// Large title for hero sections: 32pt Bold
        public static let largeTitle = Font.system(size: 32, weight: .bold, design: .default)
        
        /// Home Title: 28pt Bold
        public static let homeTitle = Font.system(size: 28, weight: .bold, design: .default)
        
        /// Title: 24pt Bold (from specification)
        public static let title = Font.system(size: 24, weight: .bold, design: .default)
        
        /// Title 2 / Subtitle: 20pt Semibold
        public static let title2 = Font.system(size: 20, weight: .semibold, design: .default)
        
        /// Section Title: 22pt Semibold
        public static let sectionTitle = Font.system(size: 22, weight: .semibold, design: .default)
        
        /// Headline: 18pt Semibold
        public static let headline = Font.system(size: 18, weight: .semibold, design: .default)
        
        /// Brand Headline / Greeting: 17pt Semibold (weight 590)
        public static let headline17 = Font.system(size: 17, weight: .semibold, design: .default)
        
        /// Body: 16pt Regular (from specification)
        public static let body = Font.system(size: 16, weight: .regular, design: .default)
        
        /// Body Medium: 16pt Medium
        public static let bodyMedium = Font.system(size: 16, weight: .medium, design: .default)
        
        /// Subheadline: 14pt Regular
        public static let subheadline = Font.system(size: 14, weight: .regular, design: .default)
        
        /// Row item: 15pt Regular
        public static let rowRegular = Font.system(size: 15, weight: .regular, design: .default)
        
        /// Row item semibold: 15pt Semibold
        public static let rowSemibold = Font.system(size: 15, weight: .semibold, design: .default)
        
        /// Caption 13: 13pt Regular
        public static let caption13 = Font.system(size: 13, weight: .regular, design: .default)
        
        /// Caption: 12pt Regular
        public static let caption = Font.system(size: 12, weight: .regular, design: .default)
        
        /// Caption Medium: 12pt Medium / Semibold (weight 510)
        public static let captionMedium = Font.system(size: 12, weight: .medium, design: .default)
        
        /// Caption Bold: 12pt Bold (for tags/badges)
        public static let captionBold = Font.system(size: 12, weight: .bold, design: .default)
        
        /// Tiny Link / Note: 11pt Medium
        public static let tiny11 = Font.system(size: 11, weight: .medium, design: .default)
    }
    
    // MARK: - Layout & Spacing
    public enum Spacing {
        /// 2pt
        public static let xxxs: CGFloat = 2
        /// 4pt
        public static let xxs: CGFloat = 4
        /// 8pt
        public static let sm: CGFloat = 8
        /// 12pt
        public static let md: CGFloat = 12
        /// 16pt (Standard screen padding from specification)
        public static let screenPadding: CGFloat = 16
        /// 20pt
        public static let lg: CGFloat = 20
        /// 24pt
        public static let xl: CGFloat = 24
        /// 32pt
        public static let xxl: CGFloat = 32
        /// 40pt
        public static let xxxl: CGFloat = 40
    }
    
    // MARK: - Corner Radii
    public enum Radius {
        /// Small radius: 8pt
        public static let small: CGFloat = 8
        /// Corner radius for buttons and cards: 12pt (from specification)
        public static let standard: CGFloat = 12
        /// Card radius: 12pt
        public static let card: CGFloat = 12
        /// Button radius: 12pt
        public static let button: CGFloat = 12
        /// Toggle pill: 18pt
        public static let togglePill: CGFloat = 18
        /// Large Card radius: 20pt
        public static let cardLarge: CGFloat = 20
        /// Gradient Hero Card radius: 24pt
        public static let cardHero: CGFloat = 24
        /// Pill / Capsule radius: 999pt
        public static let pill: CGFloat = 999
        /// Labeled Button radius: 14pt (from button variations design specification)
        public static let buttonLabeled: CGFloat = 14
    }
    
    // MARK: - Shadows
    public enum Shadows {
        /// Standard shadow: Y: 4, Blur: 10, 10% opacity (from specification)
        public static let standardColor = Color.black.opacity(0.10)
        public static let standardRadius: CGFloat = 10
        public static let standardX: CGFloat = 0
        public static let standardY: CGFloat = 4
        
        /// Card drop shadow: 0px 4px 4px rgba(0, 0, 0, 0.25)
        public static let cardShadowColor = Color.black.opacity(0.25)
        public static let cardShadowRadius: CGFloat = 4
        public static let cardShadowX: CGFloat = 0
        public static let cardShadowY: CGFloat = 4
        
        /// Subtle shadow for smaller interactive components
        public static let subtleColor = Color.black.opacity(0.05)
        public static let subtleRadius: CGFloat = 6
        public static let subtleX: CGFloat = 0
        public static let subtleY: CGFloat = 2
    }
}

// MARK: - Color Convenience Extensions

public extension Color {
    static let appPrimaryBackground = AppTheme.Colors.primaryBackground
    static let appCardBackground = AppTheme.Colors.cardBackground
    static let appPrimaryText = AppTheme.Colors.primaryText
    static let appSecondaryText = AppTheme.Colors.secondaryText
    static let appAccent = AppTheme.Colors.accent
    static let appAccentLight = AppTheme.Colors.accentLight
    static let appBorder = AppTheme.Colors.border
    
    // Semantic color convenience
    static let semanticSurfaceBase = AppTheme.Semantic.surfaceBase
    static let semanticSurfaceRaised = AppTheme.Semantic.surfaceRaised
    static let semanticSurfaceSubtle = AppTheme.Semantic.surfaceSubtle
    static let semanticSurfaceAccent = AppTheme.Semantic.surfaceAccent
    static let semanticInkPrimary = AppTheme.Semantic.inkPrimary
    static let semanticInkSecondary = AppTheme.Semantic.inkSecondary
    static let semanticInkBrand = AppTheme.Semantic.inkBrand
    static let semanticInkAccent = AppTheme.Semantic.inkAccent
    static let semanticInkInverse = AppTheme.Semantic.inkInverse
    static let semanticLineHairline = AppTheme.Semantic.lineHairline
    static let semanticConfidenceGradientStart = AppTheme.Semantic.confidenceGradientStart
    static let semanticConfidenceGradientEnd = AppTheme.Semantic.confidenceGradientEnd
}

// MARK: - Font Convenience Extensions

public extension Font {
    static let appLargeTitle = AppTheme.Typography.largeTitle
    static let appTitle = AppTheme.Typography.title
    static let appTitle2 = AppTheme.Typography.title2
    static let appHeadline = AppTheme.Typography.headline
    static let appBody = AppTheme.Typography.body
    static let appBodyMedium = AppTheme.Typography.bodyMedium
    static let appSubheadline = AppTheme.Typography.subheadline
    static let appCaption = AppTheme.Typography.caption
    static let appCaptionBold = AppTheme.Typography.captionBold
}

// MARK: - View Modifiers

public struct AppCardModifier: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat
    
    public init(padding: CGFloat = AppTheme.Spacing.screenPadding, cornerRadius: CGFloat = AppTheme.Radius.card) {
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: AppTheme.Shadows.standardColor,
                radius: AppTheme.Shadows.standardRadius,
                x: AppTheme.Shadows.standardX,
                y: AppTheme.Shadows.standardY
            )
    }
}

public struct AppStandardShadowModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .shadow(
                color: AppTheme.Shadows.standardColor,
                radius: AppTheme.Shadows.standardRadius,
                x: AppTheme.Shadows.standardX,
                y: AppTheme.Shadows.standardY
            )
    }
}

public extension View {
    /// Applies standard Aesthelity card styling: #F5F5F5 background, 12pt corner radius, custom shadow, and padding.
    func appCardStyle(padding: CGFloat = AppTheme.Spacing.screenPadding, cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        modifier(AppCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
    
    /// Applies standard Aesthelity drop shadow: Y: 4, Blur: 10, 10% opacity.
    func appShadow() -> some View {
        modifier(AppStandardShadowModifier())
    }
    
    /// Applies standard screen horizontal padding (16pt).
    func appScreenPadding() -> some View {
        self.padding(.horizontal, AppTheme.Spacing.screenPadding)
    }
}

// MARK: - Button Variations & Unified Button Styles

/// Standard button variants conforming to the Aesthelity design system specification.
public enum AppButtonVariant: String, CaseIterable, Sendable {
    /// BrandPill: Full capsule shape, rich coffee brown background (#6F4E37)
    case brandPill
    /// Primary: Rounded rectangle 14pt, periwinkle blue-purple background (#7C83BC)
    case primary
    /// Secondary: Rounded rectangle 14pt, white background, hairline border (#D8CFF0)
    case secondary
    /// Tertiary: Rounded rectangle 14pt, ghost/transparent background, indigo purple text (#50578F)
    case tertiary
    /// Destructive: Rounded rectangle 14pt, soft crimson background (#F8D7DA), dark crimson text (#842029)
    case destructive
}

/// Unified button style implementing BrandPill and Labeled variations
/// with support for Default, Pressed, Disabled, and Loading states.
public struct AppButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public var variant: AppButtonVariant
    public var isLoading: Bool
    public var minHeight: CGFloat
    public var cornerRadius: CGFloat
    
    public init(
        variant: AppButtonVariant = .primary,
        isLoading: Bool = false,
        minHeight: CGFloat = 44,
        cornerRadius: CGFloat = AppTheme.Radius.buttonLabeled
    ) {
        self.variant = variant
        self.isLoading = isLoading
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let effectiveEnabled = isEnabled && !isLoading
        
        let fg = foregroundColor(isPressed: isPressed, isEnabled: effectiveEnabled)
        let bg = backgroundColor(isPressed: isPressed, isEnabled: effectiveEnabled)
        let border = borderColor(isPressed: isPressed, isEnabled: effectiveEnabled)
        let strokeW = borderWidth
        let isPill = (variant == .brandPill)
        
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: fg))
                    .scaleEffect(0.9)
            }
            
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(fg)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bg)
        .modifier(ButtonShapeModifier(isPill: isPill, cornerRadius: cornerRadius))
        .modifier(ButtonBorderModifier(isPill: isPill, cornerRadius: cornerRadius, color: border, width: strokeW))
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
    }
    
    private func foregroundColor(isPressed: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else {
            switch variant {
            case .brandPill:
                return AppTheme.Semantic.inkSecondary
            case .primary, .secondary, .tertiary, .destructive:
                return Color(hex: "#9E97B4")
            }
        }
        
        switch variant {
        case .brandPill:
            return AppTheme.Semantic.inkInverse
        case .primary, .secondary:
            return AppTheme.Semantic.inkPrimary
        case .tertiary:
            return AppTheme.Semantic.inkAccent
        case .destructive:
            return Color(hex: "#842029")
        }
    }
    
    private func backgroundColor(isPressed: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else {
            switch variant {
            case .brandPill, .primary, .secondary, .destructive:
                return AppTheme.Semantic.surfaceSubtle
            case .tertiary:
                return Color.clear
            }
        }
        
        switch variant {
        case .brandPill:
            return isPressed ? Color(hex: "#563A26") : AppTheme.Semantic.inkBrand
        case .primary:
            return isPressed ? Color(hex: "#6C73AC") : AppTheme.Semantic.surfaceAccent
        case .secondary:
            return isPressed ? Color(hex: "#FAF7FF") : AppTheme.Semantic.surfaceRaised
        case .tertiary:
            return isPressed ? AppTheme.Semantic.surfaceSubtle : Color.clear
        case .destructive:
            return isPressed ? Color(hex: "#F1B0B7") : Color(hex: "#F8D7DA")
        }
    }
    
    private func borderColor(isPressed: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        
        switch variant {
        case .secondary:
            return AppTheme.Semantic.lineHairline
        case .destructive:
            return Color(hex: "#F5C6CB")
        case .brandPill, .primary, .tertiary:
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch variant {
        case .secondary, .destructive:
            return 1.5
        case .brandPill, .primary, .tertiary:
            return 0
        }
    }
}

private struct ButtonShapeModifier: ViewModifier {
    let isPill: Bool
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if isPill {
            content.clipShape(Capsule())
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

private struct ButtonBorderModifier: ViewModifier {
    let isPill: Bool
    let cornerRadius: CGFloat
    let color: Color
    let width: CGFloat
    
    func body(content: Content) -> some View {
        if width > 0 {
            if isPill {
                content.overlay(Capsule().stroke(color, lineWidth: width))
            } else {
                content.overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(color, lineWidth: width))
            }
        } else {
            content
        }
    }
}

public extension ButtonStyle where Self == AppButtonStyle {
    /// Applies unified button style with given variant and state.
    static func appStyle(_ variant: AppButtonVariant = .primary, isLoading: Bool = false, minHeight: CGFloat = 44) -> AppButtonStyle {
        AppButtonStyle(variant: variant, isLoading: isLoading, minHeight: minHeight)
    }
    
    /// BrandPill (Capsule, Brand brown #6F4E37).
    static var brandPill: AppButtonStyle {
        AppButtonStyle(variant: .brandPill)
    }
    
    /// Primary Labeled (RoundedRectangle 14pt, Accent periwinkle #7C83BC).
    static var appPrimary: AppButtonStyle {
        AppButtonStyle(variant: .primary)
    }
    
    /// Secondary Labeled (RoundedRectangle 14pt, Surface raised with hairline border).
    static var appSecondary: AppButtonStyle {
        AppButtonStyle(variant: .secondary)
    }
    
    /// Tertiary Labeled (RoundedRectangle 14pt, Ghost transparent).
    static var appTertiary: AppButtonStyle {
        AppButtonStyle(variant: .tertiary)
    }
    
    /// Destructive Labeled (RoundedRectangle 14pt, Crimson soft alert).
    static var appDestructive: AppButtonStyle {
        AppButtonStyle(variant: .destructive)
    }
}

// MARK: - Backwards Compatibility Button Styles

/// Legacy Primary button style using the brand accent color.
public struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.bodyMedium)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isEnabled ? AppTheme.Colors.accent : AppTheme.Colors.secondaryText.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.button, style: .continuous))
            .shadow(
                color: isEnabled ? AppTheme.Shadows.standardColor : .clear,
                radius: AppTheme.Shadows.standardRadius,
                x: AppTheme.Shadows.standardX,
                y: AppTheme.Shadows.standardY
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Legacy Secondary button style using card surface background.
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.bodyMedium)
            .foregroundStyle(AppTheme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.button, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
