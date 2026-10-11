//
//  AesthelityTests.swift
//  AesthelityTests
//
//  Unit tests for Aesthelity design theme and tokens.
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
}
