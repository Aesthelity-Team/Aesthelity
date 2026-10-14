//
//  ScanLoadingView.swift
//  Aesthelity
//
//  Analyzing / Loading State Screen for Aesthelity Skincare Scanner.
//

import SwiftUI

public struct ScanLoadingView: View {
    public var targetProgress: CGFloat = 0.82
    public var showsTabBar: Bool = false
    public var onSelectTab: ((Int) -> Void)?
    public var onComplete: (() -> Void)?
    
    @State private var animatedProgress: CGFloat = 0.0
    @State private var displayedPercentage: Int = 0
    @State private var auraScale: CGFloat = 0.95
    @State private var auraOpacity: Double = 0.85
    @State private var hasCompleted: Bool = false
    
    public init(
        targetProgress: CGFloat = 0.82,
        showsTabBar: Bool = false,
        onSelectTab: ((Int) -> Void)? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.targetProgress = targetProgress
        self.showsTabBar = showsTabBar
        self.onSelectTab = onSelectTab
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack {
                    // 1. Dreamy Multi-Layer Background Aura
                    ambientAuraBackground(in: geometry)
                    
                    // 2. Foreground Content
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Analyzing...")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(Color(red: 0.38, green: 0.26, blue: 0.18))
                            
                            Text("Reading ingredients and checking compatibility.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.34))
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        
                        Spacer(minLength: 30)
                        
                        // Center Donut Hero with 82% inside
                        HStack {
                            Spacer()
                            donutScoreHero
                            Spacer()
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Progress Bar & Status Text Section
                        VStack(alignment: .leading, spacing: 18) {
                            // Progress bar capsule
                            GeometryReader { barGeometry in
                                ZStack(alignment: .leading) {
                                    // Background track (dark muted slate/indigo)
                                    Capsule()
                                        .fill(Color(red: 0.28, green: 0.33, blue: 0.55))
                                        .frame(height: 9)
                                    
                                    // Progress fill (soft periwinkle)
                                    Capsule()
                                        .fill(Color(red: 0.49, green: 0.55, blue: 0.78))
                                        .frame(width: max(barGeometry.size.width * animatedProgress, 9), height: 9)
                                }
                            }
                            .frame(height: 9)
                            
                            // Status text
                            Text("Matching ingredients against your skin profile...")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.34))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                triggerComplete()
            }
            .onAppear {
                startAnalyzingAnimations()
            }
            
            // Bottom Tab Bar (if standalone)
            if showsTabBar {
                scanTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.95, blue: 0.93))
    }
    
    // MARK: - Ambient glowing aura
    private func ambientAuraBackground(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Base warm cream
            Color(red: 0.97, green: 0.95, blue: 0.93)
                .ignoresSafeArea()
            
            // Warm golden amber top glow
            RadialGradient(
                colors: [
                    Color(red: 1.00, green: 0.83, blue: 0.68).opacity(0.80),
                    Color(red: 1.00, green: 0.88, blue: 0.78).opacity(0.40),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.22),
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            
            // Dreamy multi-stop aura ring centered behind donut
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.95, green: 0.65, blue: 0.72).opacity(0.65), // soft rose
                            Color(red: 0.76, green: 0.70, blue: 0.90).opacity(0.70), // soft lilac
                            Color(red: 0.53, green: 0.56, blue: 0.80).opacity(0.60), // periwinkle
                            Color(red: 0.98, green: 0.75, blue: 0.62).opacity(0.65), // peach
                            Color(red: 0.95, green: 0.65, blue: 0.72).opacity(0.65)
                        ]),
                        center: .center
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 40)
                .scaleEffect(auraScale)
                .opacity(auraOpacity)
            
            // Subtle secondary warm peach center glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.86, blue: 0.75).opacity(0.75),
                            Color(red: 0.95, green: 0.68, blue: 0.75).opacity(0.35),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 180
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 25)
        }
    }
    
    // MARK: - Donut Hero Circle
    private var donutScoreHero: some View {
        ZStack {
            // Inner glowing peach circular cutout
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.90, blue: 0.82),
                            Color(red: 0.98, green: 0.78, blue: 0.68)
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 60
                    )
                )
                .frame(width: 116, height: 116)
                .overlay(
                    // Subtle inner shadow depth
                    Circle()
                        .stroke(Color(red: 0.28, green: 0.16, blue: 0.10).opacity(0.30), lineWidth: 3)
                        .blur(radius: 2)
                )
            
            // Rich coffee brown donut ring
            Circle()
                .strokeBorder(
                    Color(red: 0.38, green: 0.26, blue: 0.18),
                    lineWidth: 54
                )
                .frame(width: 224, height: 224)
                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
            
            // 82% Indigo/Periwinkle Percentage Text
            Text("\(displayedPercentage)%")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.56))
        }
    }
    
    // MARK: - Animations
    private func startAnalyzingAnimations() {
        // Soft aura breathing
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            auraScale = 1.06
            auraOpacity = 1.0
        }
        
        // Progress bar smooth animation
        withAnimation(.easeInOut(duration: 1.8)) {
            animatedProgress = targetProgress
        }
        
        // Animate counter up to target (82%)
        let target = Int(targetProgress * 100)
        let stepDuration = 1.8 / Double(max(target, 1))
        for step in 1...target {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(step) * stepDuration)) {
                if !hasCompleted {
                    displayedPercentage = step
                }
            }
        }
        
        // Auto-advance to saved state after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            triggerComplete()
        }
    }
    
    private func triggerComplete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        displayedPercentage = Int(targetProgress * 100)
        animatedProgress = targetProgress
        onComplete?()
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

#Preview("Scan Loading - Analyzing Screen") {
    ScanLoadingView(showsTabBar: true)
}
