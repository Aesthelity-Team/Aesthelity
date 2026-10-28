//
//  ContentView.swift
//  Aesthelity
//
//  Home Screen for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - Constants & Design Tokens

struct Constants {
    // Semantic Surface Canvas
    static let semanticSurfaceCanvas: Color = Color(red: 0.98, green: 0.97, blue: 1)
    
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

public enum RoutinePeriod: String, CaseIterable, Identifiable, Codable {
    case am = "AM"
    case pm = "PM"
    
    public var id: String { rawValue }
}

public enum StepState: String, Codable, Equatable {
    case complete
    case active
    case incomplete
}

public struct RoutineStepItem: Identifiable, Codable {
    public let id: UUID
    public let stepNumber: Int
    public let title: String
    public let subtitle: String
    public var state: StepState
    public var hasClash: Bool
    public var productId: UUID?
    
    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        title: String,
        subtitle: String,
        state: StepState,
        hasClash: Bool = false,
        productId: UUID? = nil
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.hasClash = hasClash
        self.productId = productId
    }

    private enum CodingKeys: String, CodingKey {
        case id, stepNumber, title, subtitle, state, hasClash, productId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.stepNumber = try container.decode(Int.self, forKey: .stepNumber)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        self.state = try container.decodeIfPresent(StepState.self, forKey: .state) ?? .incomplete
        self.hasClash = try container.decodeIfPresent(Bool.self, forKey: .hasClash) ?? false
        self.productId = try container.decodeIfPresent(UUID.self, forKey: .productId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(stepNumber, forKey: .stepNumber)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(state, forKey: .state)
        try container.encode(hasClash, forKey: .hasClash)
        try container.encodeIfPresent(productId, forKey: .productId)
    }
}

final class ContentViewStepModel: ObservableObject {
    @Published var amSteps: [RoutineStepItem]
    @Published var amClashSteps: [RoutineStepItem]
    @Published var pmSteps: [RoutineStepItem]
    
    init(
        amSteps: [RoutineStepItem] = ContentViewStepModel.defaultAMSteps,
        amClashSteps: [RoutineStepItem] = ContentViewStepModel.defaultAMClashSteps,
        pmSteps: [RoutineStepItem] = ContentViewStepModel.defaultPMSteps
    ) {
        self.amSteps = amSteps
        self.amClashSteps = amClashSteps
        self.pmSteps = pmSteps
    }
    
    static let defaultAMSteps: [RoutineStepItem] = [
        RoutineStepItem(stepNumber: 1, title: "Gentle Cleanser", subtitle: "Completed · Step 1", state: .complete),
        RoutineStepItem(stepNumber: 2, title: "Vitamin C Serum", subtitle: "Ready · Step 2", state: .active),
        RoutineStepItem(stepNumber: 3, title: "Daily Moisturizer", subtitle: "Pending · Step 3", state: .incomplete),
        RoutineStepItem(stepNumber: 4, title: "SPF 46", subtitle: "Pending · Step 4", state: .incomplete)
    ]
    
    static let defaultAMClashSteps: [RoutineStepItem] = [
        RoutineStepItem(stepNumber: 1, title: "Gentle Cleanser", subtitle: "Completed · Step 1", state: .complete, hasClash: false),
        RoutineStepItem(stepNumber: 2, title: "Vitamin C Serum", subtitle: "Ready · Step 2", state: .active, hasClash: true),
        RoutineStepItem(stepNumber: 3, title: "Retinol Night Cream", subtitle: "Ready · Step 3", state: .active, hasClash: true),
        RoutineStepItem(stepNumber: 4, title: "Daily Moisturizer", subtitle: "Pending · Step 4", state: .incomplete, hasClash: false),
        RoutineStepItem(stepNumber: 5, title: "SPF 46", subtitle: "Pending · Step 5", state: .incomplete, hasClash: false)
    ]
    
    static let defaultPMSteps: [RoutineStepItem] = [
        RoutineStepItem(stepNumber: 1, title: "Oil Cleanser", subtitle: "Completed · Step 1", state: .complete),
        RoutineStepItem(stepNumber: 2, title: "Gentle Cleanser", subtitle: "Ready · Step 2", state: .active),
        RoutineStepItem(stepNumber: 3, title: "Niacinamide Serum", subtitle: "Pending · Step 3", state: .incomplete),
        RoutineStepItem(stepNumber: 4, title: "Night Recovery Cream", subtitle: "Pending · Step 4", state: .incomplete),
        RoutineStepItem(stepNumber: 5, title: "Hydrating Eye Balm", subtitle: "Pending · Step 5", state: .incomplete)
    ]
}

// MARK: - Main ContentView / Home Screen

struct ContentView: View {
    // State
    @State var selectedPeriod: RoutinePeriod = .am
    @State var selectedTab: Int = 0
    @State var showAnalysisSheet: Bool = false
    @State var showClashDemo: Bool = false
    @State var showJournalSheet: Bool = false
    @State var showCalendarSheet: Bool = false
    @State var showIngredientClashDetail: Bool = false
    @State var showManageRoutinesView: Bool = false
    @State var showEditRoutineView: Bool = false
    @State var showStartupFlowSheet: Bool = false
    @State private var showSkinProfileSetupSheet = false
    public var onResetStartup: (() -> Void)? = nil

    /// When false, Home reads steps from `routineStore` for the selected period.
    private let usesInjectedSteps: Bool
    let stepModel: ContentViewStepModel
    @ObservedObject private var observedStepModel: ContentViewStepModel
    @ObservedObject private var routineStore: RoutineStore
    
    var amSteps: [RoutineStepItem] {
        get { stepModel.amSteps }
        nonmutating set { stepModel.amSteps = newValue }
    }
    var amClashSteps: [RoutineStepItem] {
        get { stepModel.amClashSteps }
        nonmutating set { stepModel.amClashSteps = newValue }
    }
    var pmSteps: [RoutineStepItem] {
        get { stepModel.pmSteps }
        nonmutating set { stepModel.pmSteps = newValue }
    }

    public init(
        selectedPeriod: RoutinePeriod = .am,
        selectedTab: Int = 0,
        showAnalysisSheet: Bool = false,
        showClashDemo: Bool = false,
        showJournalSheet: Bool = false,
        showCalendarSheet: Bool = false,
        showIngredientClashDetail: Bool = false,
        showManageRoutinesView: Bool = false,
        showEditRoutineView: Bool = false,
        onResetStartup: (() -> Void)? = nil,
        routineStore: RoutineStore = .shared
    ) {
        self._selectedPeriod = State(initialValue: selectedPeriod)
        self._selectedTab = State(initialValue: selectedTab)
        self._showAnalysisSheet = State(initialValue: showAnalysisSheet)
        self._showClashDemo = State(initialValue: showClashDemo)
        self._showJournalSheet = State(initialValue: showJournalSheet)
        self._showCalendarSheet = State(initialValue: showCalendarSheet)
        self._showIngredientClashDetail = State(initialValue: showIngredientClashDetail)
        self._showManageRoutinesView = State(initialValue: showManageRoutinesView)
        self._showEditRoutineView = State(initialValue: showEditRoutineView)
        self.onResetStartup = onResetStartup
        self.usesInjectedSteps = false
        // Empty placeholders — live Home uses `routineStore`.
        let model = ContentViewStepModel(amSteps: [], amClashSteps: [], pmSteps: [])
        self.stepModel = model
        self._observedStepModel = ObservedObject(wrappedValue: model)
        self._routineStore = ObservedObject(wrappedValue: routineStore)
    }
    
    init(
        selectedPeriod: RoutinePeriod = .am,
        showClashDemo: Bool = true,
        amSteps: [RoutineStepItem],
        amClashSteps: [RoutineStepItem],
        pmSteps: [RoutineStepItem],
        routineStore: RoutineStore = .shared
    ) {
        self._selectedPeriod = State(initialValue: selectedPeriod)
        self._selectedTab = State(initialValue: 0)
        self._showAnalysisSheet = State(initialValue: false)
        self._showClashDemo = State(initialValue: showClashDemo)
        self._showJournalSheet = State(initialValue: false)
        self._showCalendarSheet = State(initialValue: false)
        self._showIngredientClashDetail = State(initialValue: false)
        self._showManageRoutinesView = State(initialValue: false)
        self._showEditRoutineView = State(initialValue: false)
        self.onResetStartup = nil
        self.usesInjectedSteps = true
        let model = ContentViewStepModel(amSteps: amSteps, amClashSteps: amClashSteps, pmSteps: pmSteps)
        self.stepModel = model
        self._observedStepModel = ObservedObject(wrappedValue: model)
        self._routineStore = ObservedObject(wrappedValue: routineStore)
    }
    
    var currentSteps: [RoutineStepItem] {
        if usesInjectedSteps {
            if selectedPeriod == .am {
                return showClashDemo ? stepModel.amClashSteps : stepModel.amSteps
            }
            return stepModel.pmSteps
        }
        return routineStore.routines.first(where: { $0.period == selectedPeriod })?.steps ?? []
    }

    private var displayedAMStepCount: Int {
        if usesInjectedSteps { return stepModel.amSteps.count }
        return routineStore.routines.first(where: { $0.period == .am })?.steps.count ?? 0
    }

    private var displayedPMStepCount: Int {
        if usesInjectedSteps { return stepModel.pmSteps.count }
        return routineStore.routines.first(where: { $0.period == .pm })?.steps.count ?? 0
    }

    private var selectedRoutineDisplayName: String {
        if let name = routineStore.routines.first(where: { $0.period == selectedPeriod })?.name {
            return name
        }
        return selectedPeriod == .am ? "AM routine" : "PM routine"
    }
    
    var emptyRoutineMessage: String? {
        currentSteps.isEmpty ? "No \(selectedPeriod.rawValue) routine steps to show yet." : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab Content: All current and future tab screens are wrapped in ScrollView
            Group {
                switch selectedTab {
                case 0:
                    if showIngredientClashDetail {
                        IngredientClashView(onBack: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showIngredientClashDetail = false
                            }
                        })
                    } else if showManageRoutinesView {
                        MyRoutinesView(onBack: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showManageRoutinesView = false
                            }
                        })
                    } else if showEditRoutineView {
                        EditRoutineView(
                            routine: routineStore.routines.first(where: { $0.period == selectedPeriod })
                                ?? routineStore.routines.first
                                ?? RoutineRecord(
                                    name: selectedPeriod == .am ? "Morning Routine" : "Evening Routine",
                                    period: selectedPeriod
                                ),
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showEditRoutineView = false
                                }
                            },
                            onSave: { updatedRoutine in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    do {
                                        try routineStore.update(updatedRoutine)
                                    } catch {
                                        try? routineStore.save(updatedRoutine)
                                    }
                                    showEditRoutineView = false
                                }
                            }
                        )
                    } else {
                        homeContentView
                    }
                case 1:
                    libraryContentView
                case 2:
                    scanContentView
                case 3:
                    exploreContentView
                case 4:
                    profileContentView
                default:
                    homeContentView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Fixed Bottom Tab Bar
            customTabBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Constants.semanticSurfaceBase)
        .ignoresSafeArea(.all, edges: .bottom)
        .sheet(isPresented: $showAnalysisSheet) {
            analysisDetailSheet
        }
        .sheet(isPresented: $showJournalSheet) {
            journalDetailSheet
        }
        .sheet(isPresented: $showCalendarSheet) {
            calendarDetailSheet
        }
        .sheet(isPresented: $showStartupFlowSheet) {
            StartupFlowView(
                initialScreen: .welcome,
                onFinish: {
                    showStartupFlowSheet = false
                }
            )
        }
        .sheet(isPresented: $showSkinProfileSetupSheet) {
            StartupFlowView(
                initialScreen: .concerns,
                onCancel: { showSkinProfileSetupSheet = false },
                onFinish: { showSkinProfileSetupSheet = false }
            )
        }
        .onAppear {
            RoutineRepository.shared.load()
        }
    }
    
    // MARK: - Tab Views (All Scrollable)
    
    private var homeContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Top Demo Banner
                demoClashBanner
                
                // Header (Home & Welcome)
                headerSection
                
                if showClashDemo && selectedPeriod == .am {
                    // Ingredient Clash Warning Banner
                    ingredientClashAlertBanner
                    
                    // Routine Card with Clashing Steps
                    todaysRoutineCard
                    
                    // Why this order card
                    whyThisOrderCard
                    
                    // Other sections below routine
                    confidenceScoreCard
                    manageRoutinesRow
                    editRoutineCard
                    skinJournalSection
                } else {
                    manageRoutinesRow
                    editRoutineCard
                    confidenceScoreCard
                    todaysRoutineCard
                    whyThisOrderCard
                    skinJournalSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            
            if !showClashDemo {
                Text("Your personalized routine, one step at a time.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Constants.semanticInkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Ingredient Clash Alert Banner
    private var ingredientClashAlertBanner: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showIngredientClashDetail = true
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(hex: "#6D122B"))
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingredient clash")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: "#6D122B"))
                    
                    Text("Vitamin C Serum + Retinol Night Cream are both in AM Glow. Tap a flagged step for why.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: "#6D122B"))
                        .lineSpacing(2)
                }
                
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#EDA5B7"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Manage Routines Row
    private var manageRoutinesRow: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showManageRoutinesView = true
            }
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
            withAnimation(.easeInOut(duration: 0.2)) {
                showEditRoutineView = true
            }
        }) {
            HStack {
                Text("Edit routine")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkAccent)
                
                Spacer()
                
                Text("\(selectedRoutineDisplayName) ›")
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
        ConfidenceCard(
            score: (usesInjectedSteps && showClashDemo && selectedPeriod == .am) ? 64 : 82,
            subtitle: (usesInjectedSteps && showClashDemo && selectedPeriod == .am) ? "Active clash detected" : "Routine compatibility",
            amSteps: displayedAMStepCount,
            pmSteps: displayedPMStepCount,
            onTap: {
                showAnalysisSheet = true
            }
        )
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
                if let emptyRoutineMessage {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(emptyRoutineMessage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Constants.semanticInkPrimary)

                        Text("Save a \(selectedPeriod.rawValue) routine to see its steps here.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Constants.semanticInkSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Constants.semanticSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ForEach(currentSteps) { step in
                        stepRowView(for: step)
                    }
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
            if step.hasClash {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showIngredientClashDetail = true
                }
            } else {
                toggleStep(step)
            }
        }) {
            HStack(spacing: 12) {
                // Circle Indicator
                ZStack {
                    if step.hasClash {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1)
                            )
                    } else if step.state == .complete {
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
                
                // Titles & Clash Badge
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkPrimary)
                    
                    Text(step.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Constants.semanticInkSecondary)
                    
                    if step.hasClash {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(hex: "#6D122B"))
                                .frame(width: 14, height: 14)
                            Text("Ingredient clash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#6D122B"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Trailing Status Text
                Group {
                    if step.hasClash {
                        Text("Active")
                            .foregroundStyle(Constants.semanticInkSecondary)
                    } else {
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
                }
                .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, step.hasClash ? 12 : 14)
            .frame(maxWidth: .infinity)
            .background(
                step.hasClash
                    ? Color(hex: "#EDA5B7")
                    : (step.state == .active ? Constants.semanticSurfaceSubtle : Constants.semanticSurfaceRaised)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        step.hasClash
                            ? Color(hex: "#6D122B").opacity(0.15)
                            : (step.state == .complete ? Color.clear : Constants.semanticLineHairline),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(step.hasClash ? 0.08 : 0.15), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func toggleStep(_ step: RoutineStepItem) {
        if usesInjectedSteps {
            toggleInjectedStep(step)
            return
        }

        guard var routine = routineStore.routines.first(where: { $0.period == selectedPeriod }),
              let idx = routine.steps.firstIndex(where: { $0.id == step.id }) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            switch routine.steps[idx].state {
            case .complete:
                routine.steps[idx].state = .incomplete
            case .active:
                routine.steps[idx].state = .complete
            case .incomplete:
                routine.steps[idx].state = .active
            }
            try? routineStore.update(routine)
        }
    }

    private func toggleInjectedStep(_ step: RoutineStepItem) {
        if selectedPeriod == .am {
            if showClashDemo {
                if let idx = amClashSteps.firstIndex(where: { $0.id == step.id }) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        switch amClashSteps[idx].state {
                        case .complete:
                            amClashSteps[idx].state = .incomplete
                        case .active:
                            amClashSteps[idx].state = .complete
                        case .incomplete:
                            amClashSteps[idx].state = .active
                        }
                    }
                }
            } else if let idx = amSteps.firstIndex(where: { $0.id == step.id }) {
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
        } else if let idx = pmSteps.firstIndex(where: { $0.id == step.id }) {
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
    
    // MARK: - 7. Demo Banner (Peach)
    private var demoClashBanner: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showClashDemo.toggle()
                }
            }) {
                HStack {
                    Text(showClashDemo ? "DEMO · AM clash — Vitamin C + Retinol in routine" : "DEMO · Tap to preview AM clash (Vitamin C + Retinol)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#6F4E37"))
                    Spacer()
                    Image(systemName: showClashDemo ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#6F4E37"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#FECA9B"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button(action: {
                if let onReset = onResetStartup {
                    onReset()
                } else {
                    showStartupFlowSheet = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Preview Startup Screens (Welcome · Invalid · Network Error)")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#50578F"))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(hex: "#DFD8F5").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
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
                
                HStack(spacing: 10) {
                    Button(action: {
                        showJournalSheet = true
                    }) {
                        Text("View journal")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Constants.semanticInkPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Constants.semanticSurfaceAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showCalendarSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .medium))
                            Text("Calendar")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Constants.semanticInkBrand)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Constants.semanticSurfaceBase)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Constants.semanticLineHairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
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
                Button(action: {
                    selectedTab = 0
                    showIngredientClashDetail = false
                    showManageRoutinesView = false
                    showEditRoutineView = false
                }) {
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
                .accessibilityIdentifier("tab.home")
                
                // Tab 1: Library
                Button(action: {
                    selectedTab = 1
                    showIngredientClashDetail = false
                    showManageRoutinesView = false
                    showEditRoutineView = false
                }) {
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
                .accessibilityIdentifier("tab.library")
                
                // Tab 2: Scan (Center Elevated Button)
                Button(action: {
                    selectedTab = 2
                    showIngredientClashDetail = false
                    showManageRoutinesView = false
                    showEditRoutineView = false
                }) {
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
                .accessibilityIdentifier("tab.scan")
                
                // Tab 3: Explore
                Button(action: {
                    selectedTab = 3
                    showIngredientClashDetail = false
                    showManageRoutinesView = false
                    showEditRoutineView = false
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == 3 ? "magnifyingglass" : "magnifyingglass")
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
                .accessibilityIdentifier("tab.explore")
                
                // Tab 4: Profile
                Button(action: {
                    selectedTab = 4
                    showIngredientClashDetail = false
                    showManageRoutinesView = false
                    showEditRoutineView = false
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == 4 ? "person.fill" : "person")
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
                .accessibilityIdentifier("profile-tab")
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
        ConfidenceScoreView(
            score: (showClashDemo && selectedPeriod == .am) ? 64 : 82,
            amStepsCount: currentSteps.count,
            pmStepsCount: pmSteps.count,
            onDismiss: {
                showAnalysisSheet = false
            }
        )
    }
    
    private var journalDetailSheet: some View {
        SkinJournalView(
            store: .shared,
            backTitle: "Home",
            onBack: {
                showJournalSheet = false
            },
            onOpenCalendar: {
                showJournalSheet = false
                showCalendarSheet = true
            },
            onSelectTab: { tab in
                selectedTab = tab
                showJournalSheet = false
            }
        )
    }
    
    private var calendarDetailSheet: some View {
        SkinCalendarView(
            store: .shared,
            backTitle: "Journal",
            onBack: {
                showCalendarSheet = false
            },
            onOpenJournal: {
                showCalendarSheet = false
                showJournalSheet = true
            },
            onSelectTab: { tab in
                selectedTab = tab
                showCalendarSheet = false
            }
        )
    }
    
    // MARK: - Library Tab Content (Scrollable)
    private var libraryContentView: some View {
        LibraryView(showsTabBar: false, fullScreenFrame: false)
    }

    // MARK: - Scan Tab Content (Scrollable)
    private var scanContentView: some View {
        ScanView(showsTabBar: false, onSelectTab: { tab in
            selectedTab = tab
            showIngredientClashDetail = false
            showManageRoutinesView = false
            showEditRoutineView = false
        })
    }

    // MARK: - Explore Tab Content (Scrollable)
    private var exploreContentView: some View {
        ExploreView(showsTabBar: false, fullScreenFrame: false)
    }

    // MARK: - Profile Tab Content (Scrollable)
    private var profileContentView: some View {
        ProfileView(
            productsCount: 24,
            routinesCount: 2,
            score: (showClashDemo && selectedPeriod == .am) ? 64 : 82,
            amStepsCount: currentSteps.count,
            pmStepsCount: pmSteps.count,
            onOpenJournal: {
                showJournalSheet = true
            },
            onOpenAnalysis: {
                showAnalysisSheet = true
            },
            onSelectRoutine: { period in
                selectedPeriod = period
                selectedTab = 0
                showIngredientClashDetail = false
                showManageRoutinesView = false
                showEditRoutineView = false
            },
            onOpenStartup: {
                if let onReset = onResetStartup {
                    onReset()
                } else {
                    showStartupFlowSheet = true
                }
            },
            onEditSkinProfile: {
                showSkinProfileSetupSheet = true
            }
        )
    }
}

// MARK: - Previews

#Preview {
    ContentView()
        .environmentObject(SkinProfileStore(fileURL: URL.temporaryDirectory.appendingPathComponent("pf01-preview/profile.json")))
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SkinProfileStore(fileURL: URL.temporaryDirectory.appendingPathComponent("pf01-preview/profile.json")))
    }
}
