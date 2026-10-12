//
//  IngredientClashView.swift
//  Aesthelity
//
//  Ingredient Clash detail screen explaining routine conflicts,
//  proper timing references, and compatible formulas.
//

import SwiftUI

/// Screen displaying active ingredient conflicts and timing recommendations.
public struct IngredientClashView: View {
    public var onBack: (() -> Void)? = nil
    @State private var showResolutionSheet: Bool = false
    
    public init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header / Navigation Bar
            topNavigationBar
            
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    clashCard
                    timingReferenceCard
                    compatibleCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.Semantic.surfaceBase.ignoresSafeArea())
        .sheet(isPresented: $showResolutionSheet) {
            resolutionSheet
        }
    }
    
    // MARK: - Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                onBack?()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Home")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(AppTheme.Semantic.inkBrand)
            }
            .buttonStyle(.plain)
            
            Text("Ingredient clash")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Semantic.inkPrimary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
    
    // MARK: - 1. Clash Card (Vitamin C + Retinol)
    private var clashCard: some View {
        Button(action: {
            showResolutionSheet = true
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("Vitamin C + Retinol")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.Semantic.inkPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("Clash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#9C4E28"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#FDD1AE"))
                            .clipShape(Capsule())
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.Semantic.inkBrand)
                    }
                }
                
                Text("Vitamin C Serum · Retinol Night Cream — both in AM Glow")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.Semantic.inkBrand)
                
                Text("These two products are flagged because they appear in the same AM routine. L-ascorbic acid and retinol should not be used in the same sitting — split them AM/PM or remove one.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                    .lineSpacing(3)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Semantic.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Timing Reference Card
    private var timingReferenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Normal timing (reference)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                
                Spacer()
                
                Text("Timing OK")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#2F4A24"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#9CB88D"))
                    .clipShape(Capsule())
            }
            
            Text("AM Vitamin C · PM Retinol — when split correctly")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.Semantic.inkBrand)
            
            Text("When Vitamin C stays AM and Retinol stays PM, this is only a timing caution — not an active same-routine clash. Keep them split.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
                .lineSpacing(3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Semantic.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 3. Compatible Card
    private var compatibleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Cleanser + moisturizer")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                
                Spacer()
                
                Text("Compatible")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#2F4A24"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#9CB88D"))
                    .clipShape(Capsule())
            }
            
            Text("Gentle Cleanser · Daily Moisturizer")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.Semantic.inkBrand)
            
            Text("Non-stripping cleanse plus a bland moisturizer supports combination and acne-prone skin. No active clash.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.Semantic.inkSecondary)
                .lineSpacing(3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Semantic.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Resolution Detail Sheet
    private var resolutionSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "#6D122B"))
                        .frame(width: 18, height: 18)
                    Text("Clash Resolution Guide")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.Semantic.inkPrimary)
                }
                
                Text("How to safely separate Vitamin C & Retinoids:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Semantic.inkBrand)
                
                VStack(alignment: .leading, spacing: 12) {
                    recommendationStep(
                        number: "1",
                        title: "Keep Vitamin C in AM Glow",
                        detail: "Antioxidants work best in the morning to protect against UV and environmental oxidative stress."
                    )
                    
                    recommendationStep(
                        number: "2",
                        title: "Move Retinol Night Cream to PM",
                        detail: "Retinol stimulates nocturnal cell turnover and degrades rapidly when exposed to daylight."
                    )
                    
                    recommendationStep(
                        number: "3",
                        title: "Buffer with Moisturizer",
                        detail: "If irritation occurs, apply moisturizer before and after retinol (the sandwich method)."
                    )
                }
                
                Spacer()
                
                BrandPillButton("Got It") {
                    showResolutionSheet = false
                }
            }
            .padding(24)
            .background(AppTheme.Semantic.surfaceBase)
            .navigationTitle("Resolution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showResolutionSheet = false
                    }
                    .foregroundStyle(AppTheme.Semantic.inkBrand)
                }
            }
        }
    }
    
    private func recommendationStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Semantic.surfaceAccent)
                .frame(width: 24, height: 24)
                .background(AppTheme.Semantic.inkPrimary)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.Semantic.inkPrimary)
                
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.Semantic.inkSecondary)
                    .lineSpacing(2)
            }
        }
    }
}

#Preview {
    IngredientClashView()
}
