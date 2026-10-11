//
//  ContentView.swift
//  Aesthelity
//
//  Home Screen for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - Constants & Design Tokens

struct Constants {
    // Semantic Surface Colors
    static let semanticSurfaceBase: Color = Color(red: 0.97, green: 0.95, blue: 0.93)       // #F7F3ED
    static let semanticSurfaceRaised: Color = Color.white                                    // #FFFFFF
    static let semanticSurfaceSubtle: Color = Color(red: 0.87, green: 0.85, blue: 0.96)     // #DFD8F5
    static let semanticSurfaceAccent: Color = Color(red: 0.49, green: 0.51, blue: 0.74)     // #7C83BC
    
    // Semantic Ink Colors
    static let semanticInkPrimary: Color = Color(red: 0.10, green: 0.09, blue: 0.16)        // #1A1628
    static let semanticInkSecondary: Color = Color(red: 0.38, green: 0.33, blue: 0.47)      // #625478
    static let semanticInkBrand: Color = Color(red: 0.44, green: 0.31, blue: 0.22)          // #6F4E37
    static let semanticInkAccent: Color = Color(red: 0.31, green: 0.34, blue: 0.56)         // #50578F
    static let semanticInkInverse: Color = Color(red: 0.97, green: 0.95, blue: 0.93)        // #F7F3ED
    
    // Semantic Lines
    static let semanticLineHairline: Color = Color(red: 0.85, green: 0.81, blue: 0.94)      // #D8CFF0
    
    // Gradient Stops for Routine Card
    static let gradientStart: Color = Color(red: 1.00, green: 0.79, blue: 0.61)             // #FECA9B
    static let gradientMiddle: Color = Color(red: 0.94, green: 0.66, blue: 0.73)            // #F0A8BA
    static let gradientEnd: Color = Color(red: 0.49, green: 0.51, blue: 0.74)               // #7C83BC
    static let analysisLink: Color = Color(red: 1.00, green: 0.80, blue: 0.60)              // #FFCC99
    
    // Confidence Card Gradient Background
    static let confidenceGradientStart: Color = Color(red: 1.00, green: 0.95, blue: 0.90)   // #FFF2E6
    static let confidenceGradientEnd: Color = Color(red: 0.99, green: 0.89, blue: 0.93)     // #FCE4EC
}

// MARK: - Routine Models

enum RoutinePeriod: String, CaseIterable {
    case am = "AM"
    case pm = "PM"
}

enum StepState {
    case complete
    case active
    case incomplete
}

struct RoutineStepItem: Identifiable {
    let id = UUID()
    let stepNumber: Int
    let title: String
    let subtitle: String
    var state: StepState
}

// MARK: - Main ContentView / Home Screen

struct ContentView: View {
    // State
    @State private var selectedPeriod: RoutinePeriod = .am
    @State private var selectedTab: Int = 0
    @State private var showAnalysisSheet: Bool = false
    @State private var showClashDemo: Bool = false
    @State private var showJournalSheet: Bool = false
    
    // AM Steps
    @State private var amSteps: [RoutineStepItem] = [
        RoutineStepItem(stepNumber: 1, title: "Gentle Cleanser", subtitle: "Completed · Step 1", state: .complete),
        RoutineStepItem(stepNumber: 2, title: "Vitamin C Serum", subtitle: "Ready · Step 2", state: .active),
        RoutineStepItem(stepNumber: 3, title: "Daily Moisturizer", subtitle: "Pending · Step 3", state: .incomplete),
        RoutineStepItem(stepNumber: 4, title: "SPF 46", subtitle: "Pending · Step 4", state: .incomplete)
    ]
    
    // PM Steps
    @State private var pmSteps: [RoutineStepItem] = [
        RoutineStepItem(stepNumber: 1, title: "Oil Cleanser", subtitle: "Completed · Step 1", state: .complete),
        RoutineStepItem(stepNumber: 2, title: "Gentle Cleanser", subtitle: "Ready · Step 2", state: .active),
        RoutineStepItem(stepNumber: 3, title: "Niacinamide Serum", subtitle: "Pending · Step 3", state: .incomplete),
        RoutineStepItem(stepNumber: 4, title: "Night Recovery Cream", subtitle: "Pending · Step 4", state: .incomplete),
        RoutineStepItem(stepNumber: 5, title: "Hydrating Eye Balm", subtitle: "Pending · Step 5", state: .incomplete)
    ]
    
    var currentSteps: [RoutineStepItem] {
        selectedPeriod == .am ? amSteps : pmSteps
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scrollable Home Screen Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    manageRoutinesRow
                    editRoutineCard
                    confidenceScoreCard
                    todaysRoutineCard
                    whyThisOrderCard
                    demoClashBanner
                    skinJournalSection
                }
                .padding(.top, 40)
                .padding(.bottom, 32)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Fixed Bottom Tab Bar
            customTabBar
        }
        .padding(0)
        .frame(width: 390, height: 844, alignment: .topLeading)
        .background(Constants.semanticSurfaceBase)
        .sheet(isPresented: $showAnalysisSheet) {
            analysisDetailSheet
        }
        .sheet(isPresented: $showJournalSheet) {
            journalDetailSheet
        }
    }
    
    // MARK: - 1. Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center) {
                Text("Home")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Constants.semanticInkPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("Aesthelity")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkBrand)
                    .lineLimit(1)
            }
            
            Text("Welcome, User")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Constants.semanticInkPrimary)
                .padding(.top, 2)
            
            Text("Your personalized routine, one step at a time.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Constants.semanticInkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 2. Manage Routines Row
    private var manageRoutinesRow: some View {
        Button(action: {
            // Manage routines action
        }) {
            HStack {
                Text("Manage routines")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Constants.semanticInkBrand)
                
                Spacer()
                
                Text("›")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Constants.semanticInkBrand)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(height: 44)
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 3. Edit Routine Card
    private var editRoutineCard: some View {
        Button(action: {
            // Edit routine action
        }) {
            HStack {
                Text("Edit routine")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkAccent)
                
                Spacer()
                
                Text("AM Glow ›")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Constants.semanticInkSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Constants.semanticLineHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 4. Confidence Score Card
    private var confidenceScoreCard: some View {
        HStack(alignment: .center) {
            // Left Column
            VStack(alignment: .leading, spacing: 4) {
                Text("CONFIDENCE SCORE")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Constants.semanticInkPrimary)
                
                Text("82%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Constants.semanticInkPrimary)
                
                Text("Routine compatibility")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Constants.semanticInkSecondary)
            }
            .frame(maxWidth: 160, alignment: .leading)
            
            Spacer()
            
            // Right Badges
            VStack(spacing: 8) {
                Text("AM: 4 steps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Constants.semanticInkInverse)
                    .frame(width: 110, height: 26)
                    .background(Constants.semanticInkAccent)
                    .clipShape(Capsule())
                
                Text("PM: 5 steps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Constants.semanticInkInverse)
                    .frame(width: 110, height: 26)
                    .background(Constants.semanticInkBrand)
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
                        Constants.confidenceGradientStart,
                        Constants.confidenceGradientEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Constants.semanticSurfaceAccent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .offset(x: 100, y: -20)
                Circle()
                    .fill(Constants.gradientStart.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .offset(x: -80, y: 30)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - 5. Today's Routine Card (Gradient)
    private var todaysRoutineCard: some View {
        VStack(alignment: .leading, spacing: 20.67) {
            // Header & Segmented Control
            VStack(alignment: .leading, spacing: 16) {
                Text("Today's Routine")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkBrand)
                
                // AM / PM Toggle
                HStack(spacing: 9) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = .am
                        }
                    }) {
                        Text("AM")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedPeriod == .am ? Constants.semanticInkInverse : Constants.semanticInkPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(selectedPeriod == .am ? Constants.semanticInkBrand : Constants.semanticSurfaceBase)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = .pm
                        }
                    }) {
                        Text("PM")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedPeriod == .pm ? Constants.semanticInkInverse : Constants.semanticInkPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(selectedPeriod == .pm ? Constants.semanticInkBrand : Constants.semanticSurfaceBase)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 44)
            }
            
            // Steps List
            VStack(spacing: 6.67) {
                ForEach(currentSteps) { step in
                    stepRowView(for: step)
                }
            }
            
            // View Analysis Link
            Button(action: {
                showAnalysisSheet = true
            }) {
                Text(">> View analysis")
                    .font(.system(size: 11, weight: .medium))
                    .underline()
                    .foregroundStyle(Constants.analysisLink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 24)
        .padding(.bottom, 15)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Constants.gradientStart, location: 0.16),
                    .init(color: Constants.gradientMiddle, location: 0.50),
                    .init(color: Constants.gradientEnd, location: 0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
    }
    
    // Routine Step Row Builder
    private func stepRowView(for step: RoutineStepItem) -> some View {
        Button(action: {
            toggleStep(step)
        }) {
            HStack(spacing: 12) {
                // Circle Indicator
                ZStack {
                    if step.state == .complete {
                        Circle()
                            .fill(Constants.semanticSurfaceAccent)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(Constants.semanticLineHairline, lineWidth: 1)
                            )
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                    } else if step.state == .active {
                        Circle()
                            .fill(Constants.semanticSurfaceRaised)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(Constants.semanticInkAccent, lineWidth: 1)
                            )
                        Circle()
                            .fill(Constants.semanticInkAccent)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Constants.semanticSurfaceRaised)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(Constants.semanticLineHairline, lineWidth: 1)
                            )
                    }
                }
                .frame(width: 44, height: 44)
                
                // Titles
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkPrimary)
                    
                    Text(step.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Constants.semanticInkSecondary)
                }
                
                Spacer()
                
                // Trailing Status Text
                Group {
                    switch step.state {
                    case .complete:
                        Text("Complete")
                            .foregroundStyle(Constants.semanticInkAccent)
                    case .active:
                        Text("Active")
                            .foregroundStyle(Constants.semanticInkSecondary)
                    case .incomplete:
                        Text("Incomplete")
                            .foregroundStyle(Constants.semanticInkSecondary)
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(step.state == .active ? Constants.semanticSurfaceSubtle : Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Constants.semanticLineHairline, lineWidth: step.state == .complete ? 0 : 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func toggleStep(_ step: RoutineStepItem) {
        if selectedPeriod == .am {
            if let idx = amSteps.firstIndex(where: { $0.id == step.id }) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    switch amSteps[idx].state {
                    case .complete:
                        amSteps[idx].state = .incomplete
                    case .active:
                        amSteps[idx].state = .complete
                    case .incomplete:
                        amSteps[idx].state = .active
                    }
                }
            }
        } else {
            if let idx = pmSteps.firstIndex(where: { $0.id == step.id }) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    switch pmSteps[idx].state {
                    case .complete:
                        pmSteps[idx].state = .incomplete
                    case .active:
                        pmSteps[idx].state = .complete
                    case .incomplete:
                        pmSteps[idx].state = .active
                    }
                }
            }
        }
    }
    
    // MARK: - 6. Why This Order? Card
    private var whyThisOrderCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Why this order?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Constants.semanticInkAccent)
            
            Text(selectedPeriod == .am
                 ? "AM order: cleanse → serum → moisturize → sunscreen. You can still reorder steps anytime."
                 : "PM order: oil cleanse → cleanse → serum → moisturize → eye balm. You can still reorder steps anytime.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Constants.semanticInkSecondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Constants.semanticSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Constants.semanticLineHairline, lineWidth: 1)
        )
    }
    
    // MARK: - 7. Demo Banner
    private var demoClashBanner: some View {
        Button(action: {
            showClashDemo.toggle()
        }) {
            HStack(spacing: 4) {
                Text(showClashDemo ? "Demo: Active Clash Detected (Retinol + Vitamin C) ›" : "Demo: AM ingredient clash state ›")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(showClashDemo ? Color(red: 0.70, green: 0.23, blue: 0.28) : Constants.semanticInkSecondary)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(showClashDemo ? Color(red: 1.0, green: 0.92, blue: 0.93) : Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(showClashDemo ? Color(red: 0.70, green: 0.23, blue: 0.28).opacity(0.3) : Constants.semanticLineHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 8. Skin Journal Section
    private var skinJournalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skin Journal")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Constants.semanticInkPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Skin Journal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkPrimary)
                
                Text("Sep 16 · Hydration improving · 3 entries this week")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Constants.semanticInkSecondary)
                
                Button(action: {
                    showJournalSheet = true
                }) {
                    Text("View journal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Constants.semanticInkPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Constants.semanticSurfaceAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Constants.semanticLineHairline, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 9. Bottom Tab Bar
    private var customTabBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Tab 0: Home (Active)
                Button(action: { selectedTab = 0 }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedTab == 0 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                            .frame(width: 24, height: 24)
                        
                        Text("Home")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedTab == 0 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                        
                        if selectedTab == 0 {
                            Capsule()
                                .fill(Constants.semanticInkAccent)
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
                
                // Tab 1: Library
                Button(action: { selectedTab = 1 }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == 1 ? "books.vertical.fill" : "books.vertical")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedTab == 1 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                            .frame(width: 24, height: 24)
                        
                        Text("Library")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedTab == 1 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                        
                        if selectedTab == 1 {
                            Capsule()
                                .fill(Constants.semanticInkAccent)
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
                
                // Tab 2: Scan (Center Elevated Button)
                Button(action: { selectedTab = 2 }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Constants.semanticSurfaceAccent)
                                .frame(width: 56, height: 56)
                                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "viewfinder")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Constants.semanticInkPrimary)
                        }
                        
                        Text("Scan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Constants.semanticInkBrand)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                // Tab 3: Explore
                Button(action: { selectedTab = 3 }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == 3 ? "safari.fill" : "safari")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedTab == 3 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                            .frame(width: 24, height: 24)
                        
                        Text("Explore")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedTab == 3 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                        
                        if selectedTab == 3 {
                            Capsule()
                                .fill(Constants.semanticInkAccent)
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
                
                // Tab 4: Profile
                Button(action: { selectedTab = 4 }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == 4 ? "person.crop.circle.fill" : "person.crop.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedTab == 4 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                            .frame(width: 24, height: 24)
                        
                        Text("Profile")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedTab == 4 ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                        
                        if selectedTab == 4 {
                            Capsule()
                                .fill(Constants.semanticInkAccent)
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
            .frame(height: 72)
            
            // Safe Area bottom spacer (34pt)
            Color.clear
                .frame(height: 34)
        }
        .frame(height: 106)
        .frame(maxWidth: .infinity)
        .background(Constants.semanticSurfaceBase)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Constants.semanticLineHairline),
            alignment: .top
        )
    }
    
    // MARK: - Sheets
    private var analysisDetailSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Routine Analysis")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Constants.semanticInkPrimary)
                
                Text("Compatibility Score: 82%")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkAccent)
                
                Text("Your morning routine is well-balanced for skin barrier protection and antioxidant delivery.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Constants.semanticInkSecondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Synergies:")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkPrimary)
                    
                    Text("• Vitamin C pairs with SPF 46 to enhance UV defense.")
                        .font(.system(size: 14))
                        .foregroundStyle(Constants.semanticInkSecondary)
                    
                    Text("• Daily Moisturizer locks in hydration before sun protection.")
                        .font(.system(size: 14))
                        .foregroundStyle(Constants.semanticInkSecondary)
                }
                
                Spacer()
            }
            .padding(24)
            .background(Constants.semanticSurfaceBase)
            .navigationTitle("Analysis")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showAnalysisSheet = false
                    }
                    .foregroundStyle(Constants.semanticInkBrand)
                }
            }
        }
    }
    
    private var journalDetailSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Skin Journal")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Constants.semanticInkPrimary)
                
                Text("Sep 16 · Hydration improving · 3 entries this week")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Constants.semanticInkSecondary)
                
                Text("Skin barrier feels intact. No redness reported after Vitamin C application. Retinol introduced on Wednesday evening with moisturizer sandwich method.")
                    .font(.system(size: 14))
                    .foregroundStyle(Constants.semanticInkPrimary)
                    .padding()
                    .background(Constants.semanticSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding(24)
            .background(Constants.semanticSurfaceBase)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showJournalSheet = false
                    }
                    .foregroundStyle(Constants.semanticInkBrand)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview {
    ContentView()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
