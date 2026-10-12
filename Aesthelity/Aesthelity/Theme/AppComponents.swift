//
//  AppComponents.swift
//  Aesthelity
//
//  Standard reusable SwiftUI components adhering to the Aesthelity design specifications.
//

import SwiftUI

// MARK: - AppCard

/// A surface card component conforming to the design specifications:
/// - Background: Surface/Card Background (#F5F5F5)
/// - Corner Radius: 12pt
/// - Shadow: Y: 4, Blur: 10, 10% opacity
/// - Padding: Standard 16pt
public struct AppCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    
    public init(padding: CGFloat = AppTheme.Spacing.screenPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        content
            .appCardStyle(padding: padding)
    }
}

// MARK: - AppBadge (Tag / Pill)

/// A compact badge component for tags, skin concerns, ingredient safety, and routine steps.
public struct AppBadge: View {
    public enum Style {
        case accent
        case neutral
        case subtle
        
        var backgroundColor: Color {
            switch self {
            case .accent: return AppTheme.Colors.accentLight
            case .neutral: return AppTheme.Colors.cardBackground
            case .subtle: return AppTheme.Colors.primaryText.opacity(0.06)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .accent: return AppTheme.Colors.accent
            case .neutral: return AppTheme.Colors.primaryText
            case .subtle: return AppTheme.Colors.secondaryText
            }
        }
    }
    
    let text: String
    let icon: String?
    let style: Style
    
    public init(_ text: String, icon: String? = nil, style: Style = .accent) {
        self.text = text
        self.icon = icon
        self.style = style
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(AppTheme.Typography.captionBold)
        }
        .foregroundStyle(style.foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(style.backgroundColor)
        .clipShape(Capsule())
    }
}

// MARK: - AppSectionHeader

/// A reusable section header displaying a title (24pt Bold) with optional action button.
public struct AppSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let onAction: (() -> Void)?
    
    public init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.onAction = onAction
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                
                Spacer()
                
                if let actionTitle = actionTitle, let onAction = onAction {
                    Button(action: onAction) {
                        Text(actionTitle)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }
}

// MARK: - RoutineStepCard (Sprint 1 Sample Component)

/// Routine step card matching Sprint 1 RT-01 requirements.
public struct RoutineStepCard: View {
    let stepNumber: Int
    let title: String
    let productType: String
    let isCompleted: Bool
    let onToggle: () -> Void
    
    public init(
        stepNumber: Int,
        title: String,
        productType: String,
        isCompleted: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.stepNumber = stepNumber
        self.title = title
        self.productType = productType
        self.isCompleted = isCompleted
        self.onToggle = onToggle
    }
    
    public var body: some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                // Step Indicator
                ZStack {
                    Circle()
                        .fill(isCompleted ? AppTheme.Colors.accent : AppTheme.Colors.primaryBackground)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.accent, lineWidth: 1.5)
                        )
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(stepNumber)")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    
                    Text(productType)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Toggle Button
                Button(action: onToggle) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isCompleted ? AppTheme.Colors.accent : AppTheme.Colors.secondaryText)
                }
            }
        }
    }
}

// MARK: - AnalysisFindingCard (Sprint 1 Sample Component)

/// Explanatory analysis card matching Sprint 1 AN-01 requirements.
public struct AnalysisFindingCard: View {
    let headline: String
    let explanation: String
    let tag: String
    
    public init(headline: String, explanation: String, tag: String = "Compatibility Notice") {
        self.headline = headline
        self.explanation = explanation
        self.tag = tag
    }
    
    public var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    AppBadge(tag, icon: "sparkles", style: .accent)
                    Spacer()
                }
                
                Text(headline)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                
                Text(explanation)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - ConfidenceCard (Routine Compatibility Card)

/// A card component conforming to the Aesthelity design specifications displaying
/// the user's routine confidence score and AM/PM routine breakdown.
public struct ConfidenceCard: View {
    public let score: Int
    public let title: String
    public let subtitle: String
    public let amSteps: Int
    public let pmSteps: Int
    public let amBadgeText: String?
    public let pmBadgeText: String?
    public let onTap: (() -> Void)?
    
    public init(
        score: Int = 82,
        title: String = "CONFIDENCE SCORE",
        subtitle: String = "Routine compatibility",
        amSteps: Int = 4,
        pmSteps: Int = 5,
        amBadgeText: String? = nil,
        pmBadgeText: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.score = score
        self.title = title
        self.subtitle = subtitle
        self.amSteps = amSteps
        self.pmSteps = pmSteps
        self.amBadgeText = amBadgeText
        self.pmBadgeText = pmBadgeText
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: {
            onTap?()
        }) {
            cardBody
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
    
    private var cardBody: some View {
        HStack(alignment: .center) {
            // Left Column: Title, Percentage Score, and Subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                
                Text("\(score)%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
            }
            .frame(maxWidth: 160, alignment: .leading)
            
            Spacer()
            
            // Right Column: AM / PM Step Count Badges
            VStack(spacing: 8) {
                Text(amBadgeText ?? "AM: \(amSteps) steps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Semantic.inkInverse)
                    .frame(width: 110, height: 26)
                    .background(AppTheme.Semantic.inkAccent)
                    .clipShape(Capsule())
                
                Text(pmBadgeText ?? "PM: \(pmSteps) steps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Semantic.inkInverse)
                    .frame(width: 110, height: 26)
                    .background(AppTheme.Semantic.inkBrand)
                    .clipShape(Capsule())
            }
            .frame(width: 110)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 21)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.Semantic.confidenceGradientStart,
                        AppTheme.Semantic.confidenceGradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(AppTheme.Semantic.surfaceAccent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .offset(x: 100, y: -20)
                Circle()
                    .fill(AppTheme.Semantic.gradientStart.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .offset(x: -80, y: 30)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.cardLarge, style: .continuous))
    }
}

// MARK: - AppButton & Button Variations

/// A standardized button component matching the Aesthelity design system.
/// Supports BrandPill (Capsule) and Labeled (RoundedRectangle 14pt) variations,
/// with Default, Pressed, Disabled, and Loading states.
public struct AppButton: View {
    public var title: String
    public var systemImage: String?
    public var variant: AppButtonVariant
    public var isLoading: Bool
    public var minHeight: CGFloat
    public var action: () -> Void
    
    public init(
        _ title: String,
        systemImage: String? = nil,
        variant: AppButtonVariant = .primary,
        isLoading: Bool = false,
        minHeight: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.isLoading = isLoading
        self.minHeight = minHeight
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            if let systemImage = systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(AppButtonStyle(variant: variant, isLoading: isLoading, minHeight: minHeight))
    }
}

/// Convenience view for BrandPill button variation (Capsule, Rich Brand Brown #6F4E37).
public struct BrandPillButton: View {
    public var title: String
    public var systemImage: String?
    public var isLoading: Bool
    public var minHeight: CGFloat
    public var action: () -> Void
    
    public init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        minHeight: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.minHeight = minHeight
        self.action = action
    }
    
    public var body: some View {
        AppButton(
            title,
            systemImage: systemImage,
            variant: .brandPill,
            isLoading: isLoading,
            minHeight: minHeight,
            action: action
        )
    }
}

/// Convenience view for Labeled button variations (Primary, Secondary, Tertiary, Destructive).
public struct LabeledButton: View {
    public var title: String
    public var systemImage: String?
    public var variant: AppButtonVariant
    public var isLoading: Bool
    public var minHeight: CGFloat
    public var action: () -> Void
    
    public init(
        _ title: String,
        systemImage: String? = nil,
        variant: AppButtonVariant = .primary,
        isLoading: Bool = false,
        minHeight: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.isLoading = isLoading
        self.minHeight = minHeight
        self.action = action
    }
    
    public var body: some View {
        AppButton(
            title,
            systemImage: systemImage,
            variant: variant,
            isLoading: isLoading,
            minHeight: minHeight,
            action: action
        )
    }
}

// MARK: - Previews

#Preview("Confidence Card") {
    VStack(alignment: .leading, spacing: 0) {
        ConfidenceCard(
            score: 82,
            title: "CONFIDENCE SCORE",
            subtitle: "Routine compatibility",
            amSteps: 4,
            pmSteps: 5
        )
        .padding(.horizontal, 24)
        .padding(.top, 40)
        
        Spacer()
    }
    .padding(0)
    .frame(width: 390, height: 844, alignment: .topLeading)
    .background(AppTheme.Semantic.surfaceBase)
}

#Preview("Button Variations - Design Spec") {
    ScrollView {
        VStack(spacing: 24) {
            // BrandPill Section
            VStack(alignment: .leading, spacing: 10) {
                Text("BUTTON / BRANDPILL")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                
                BrandPillButton("BrandPill · Default") {}
                BrandPillButton("BrandPill · Disabled") {}
                    .disabled(true)
                BrandPillButton("BrandPill · Loading", isLoading: true) {}
            }
            
            // Labeled - Primary
            VStack(alignment: .leading, spacing: 10) {
                Text("BUTTON / LABELED · PRIMARY")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                
                LabeledButton("Primary · Default", variant: .primary) {}
                LabeledButton("Primary · Disabled", variant: .primary) {}
                    .disabled(true)
                LabeledButton("Primary · Loading", variant: .primary, isLoading: true) {}
            }
            
            // Labeled - Secondary
            VStack(alignment: .leading, spacing: 10) {
                Text("BUTTON / LABELED · SECONDARY")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                
                LabeledButton("Secondary · Default", variant: .secondary) {}
                LabeledButton("Secondary · Disabled", variant: .secondary) {}
                    .disabled(true)
                LabeledButton("Secondary · Loading", variant: .secondary, isLoading: true) {}
            }
            
            // Labeled - Tertiary
            VStack(alignment: .leading, spacing: 10) {
                Text("BUTTON / LABELED · TERTIARY")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                
                LabeledButton("Tertiary · Default", variant: .tertiary) {}
                LabeledButton("Tertiary · Disabled", variant: .tertiary) {}
                    .disabled(true)
                LabeledButton("Tertiary · Loading", variant: .tertiary, isLoading: true) {}
            }
            
            // Labeled - Destructive
            VStack(alignment: .leading, spacing: 10) {
                Text("BUTTON / LABELED · DESTRUCTIVE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                
                LabeledButton("Destructive · Default", variant: .destructive) {}
                LabeledButton("Destructive · Disabled", variant: .destructive) {}
                    .disabled(true)
                LabeledButton("Destructive · Loading", variant: .destructive, isLoading: true) {}
            }
        }
        .padding(20)
    }
    .background(AppTheme.Semantic.surfaceBase)
}
