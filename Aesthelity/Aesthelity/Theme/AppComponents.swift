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
