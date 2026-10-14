//
//  MockAnalysisFindings.swift
//  Aesthelity
//
//  Created by Gaurav Pandey on 10/13/26.
//

import Foundation

/// Sprint 1 mocked analysis results. Product and ingredient names mirror the Home routine demo
/// until the DATA-01 catalog is available.
public enum MockAnalysisFindings {
    public static let vitaminCWithRetinol = AnalysisFinding(
        id: "mock-caution-vitamin-c-retinol",
        productName: "Vitamin C Serum",
        ingredientName: "L-Ascorbic Acid",
        category: "Active ingredient overlap",
        severity: .caution,
        headline: "Vitamin C and Retinol in the same routine",
        explanation: "Using a strong Vitamin C serum and a retinol cream back to back can leave skin red, dry, or stinging. Try Vitamin C in the morning and retinol at night instead.",
        reason: "Your AM routine has Vitamin C Serum (L-Ascorbic Acid) and Retinol Night Cream (Retinol) as consecutive steps, and both are potent actives that can irritate when layered."
    )

    public static let sunscreenFinalStep = AnalysisFinding(
        id: "mock-normal-spf-zinc",
        productName: "SPF 46",
        ingredientName: "Zinc Oxide",
        category: "Sun protection",
        severity: .normal,
        headline: "Sunscreen is in the right place",
        explanation: "Your sunscreen is the last step of your morning routine, so nothing applied after it dilutes its protection.",
        reason: "SPF 46 (Zinc Oxide) is the final AM step and no listed ingredients conflict with it."
    )

    public static let incompleteIngredientList = AnalysisFinding(
        id: "mock-unknown-toner",
        productName: "Botanical Essence Toner",
        ingredientName: "Fragrance (Parfum)",
        category: "Incomplete product data",
        severity: .unknown,
        headline: "We can't fully check this toner yet",
        explanation: "This product lists \"Fragrance (Parfum)\", which can hide many individual ingredients. We can't tell whether any of them interact with the rest of your routine.",
        reason: "Part of the ingredient list couldn't be matched to known ingredients.",
        limitation: "We couldn't verify the full ingredient list, so this isn't a definitive result."
    )

    public static let all: [AnalysisFinding] = [
        vitaminCWithRetinol,
        sunscreenFinalStep,
        incompleteIngredientList
    ]

    /// Matches the Home screen demo: the caution finding only applies while the AM clash demo is shown.
    public static func forClashDemo(_ on: Bool) -> [AnalysisFinding] {
        on ? all : all.filter { $0.severity != .caution }
    }
}
