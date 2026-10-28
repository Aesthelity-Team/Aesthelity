//
//  CreateRoutineView.swift
//  Aesthelity
//
//  Create / New Routine screen with validation, step builder, quick-add suggestions,
//  custom step creation, reordering, and limit management.
//

import SwiftUI

public final class CreateRoutineViewModel: ObservableObject {
    @Published public var routineName: String
    @Published public var selectedPeriod: RoutinePeriod
    @Published public var isCustomPeriod: Bool
    @Published public var steps: [RoutineStepItem]
    
    // Schedule & Notification settings
    @Published public var frequency: RoutineFrequency
    @Published public var reminderTime: String
    @Published public var activeDays: Set<RoutineWeekday>
    @Published public var pushRemindersEnabled: Bool
    @Published public var leadTime: NotificationLeadTime
    @Published public var quietHoursEnabled: Bool
    
    // Validation & Error states
    @Published public var showErrorBanner: Bool
    @Published public var hasAttemptedSave: Bool
    @Published public var showStepLimitWarning: Bool
    
    // Navigation sheets
    @Published public var showScheduleSheet: Bool
    @Published public var showNotificationSheet: Bool
    @Published public var showAddProductSheet: Bool
    @Published public var showReorderSheet: Bool
    @Published public var showCustomStepSheet: Bool
    
    // Custom step inputs
    @Published public var customStepTitle: String
    @Published public var customStepCategory: String
    
    public init(
        routineName: String = "",
        selectedPeriod: RoutinePeriod = .am,
        isCustomPeriod: Bool = false,
        steps: [RoutineStepItem] = [],
        frequency: RoutineFrequency = .everyDay,
        reminderTime: String = "7:00 AM",
        activeDays: Set<RoutineWeekday> = [.mon, .wed, .fri],
        pushRemindersEnabled: Bool = false,
        leadTime: NotificationLeadTime = .atTime,
        quietHoursEnabled: Bool = true,
        showErrorBanner: Bool = false,
        hasAttemptedSave: Bool = false,
        showStepLimitWarning: Bool = false,
        showScheduleSheet: Bool = false,
        showNotificationSheet: Bool = false,
        showAddProductSheet: Bool = false,
        showReorderSheet: Bool = false,
        showCustomStepSheet: Bool = false,
        customStepTitle: String = "",
        customStepCategory: String = ""
    ) {
        self.routineName = routineName
        self.selectedPeriod = selectedPeriod
        self.isCustomPeriod = isCustomPeriod
        self.steps = steps
        self.frequency = frequency
        self.reminderTime = reminderTime
        self.activeDays = activeDays
        self.pushRemindersEnabled = pushRemindersEnabled
        self.leadTime = leadTime
        self.quietHoursEnabled = quietHoursEnabled
        self.showErrorBanner = showErrorBanner
        self.hasAttemptedSave = hasAttemptedSave
        self.showStepLimitWarning = showStepLimitWarning
        self.showScheduleSheet = showScheduleSheet
        self.showNotificationSheet = showNotificationSheet
        self.showAddProductSheet = showAddProductSheet
        self.showReorderSheet = showReorderSheet
        self.showCustomStepSheet = showCustomStepSheet
        self.customStepTitle = customStepTitle
        self.customStepCategory = customStepCategory
    }
    
    public func addStep(_ newStep: RoutineStepItem) {
        guard steps.count < 8 else {
            showStepLimitWarning = true
            return
        }
        let item = RoutineStepItem(
            stepNumber: steps.count + 1,
            title: newStep.title,
            subtitle: newStep.subtitle.isEmpty ? "Step \(steps.count + 1)" : newStep.subtitle,
            state: newStep.state,
            hasClash: newStep.hasClash,
            productId: newStep.productId
        )
        steps.append(item)
        if steps.count < 8 {
            showStepLimitWarning = false
        }
    }
    
    public func removeStep(_ step: RoutineStepItem) {
        var updatedSteps = steps.filter { $0.id != step.id }
        for index in 0..<updatedSteps.count {
            let current = updatedSteps[index]
            updatedSteps[index] = RoutineStepItem(
                stepNumber: index + 1,
                title: current.title,
                subtitle: current.subtitle,
                state: current.state,
                hasClash: current.hasClash,
                productId: current.productId
            )
        }
        steps = updatedSteps
        if steps.count < 8 {
            showStepLimitWarning = false
        }
    }
}

public struct CreateRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    
    public let viewModel: CreateRoutineViewModel
    @ObservedObject private var observedViewModel: CreateRoutineViewModel
    
    public var routineName: String {
        get { viewModel.routineName }
        nonmutating set { viewModel.routineName = newValue }
    }
    public var selectedPeriod: RoutinePeriod {
        get { viewModel.selectedPeriod }
        nonmutating set { viewModel.selectedPeriod = newValue }
    }
    public var isCustomPeriod: Bool {
        get { viewModel.isCustomPeriod }
        nonmutating set { viewModel.isCustomPeriod = newValue }
    }
    public var steps: [RoutineStepItem] {
        get { viewModel.steps }
        nonmutating set { viewModel.steps = newValue }
    }
    
    // Schedule & Notification settings
    public var frequency: RoutineFrequency {
        get { viewModel.frequency }
        nonmutating set { viewModel.frequency = newValue }
    }
    public var reminderTime: String {
        get { viewModel.reminderTime }
        nonmutating set { viewModel.reminderTime = newValue }
    }
    public var activeDays: Set<RoutineWeekday> {
        get { viewModel.activeDays }
        nonmutating set { viewModel.activeDays = newValue }
    }
    public var pushRemindersEnabled: Bool {
        get { viewModel.pushRemindersEnabled }
        nonmutating set { viewModel.pushRemindersEnabled = newValue }
    }
    public var leadTime: NotificationLeadTime {
        get { viewModel.leadTime }
        nonmutating set { viewModel.leadTime = newValue }
    }
    public var quietHoursEnabled: Bool {
        get { viewModel.quietHoursEnabled }
        nonmutating set { viewModel.quietHoursEnabled = newValue }
    }
    
    // Validation & Error states
    public var showErrorBanner: Bool {
        get { viewModel.showErrorBanner }
        nonmutating set { viewModel.showErrorBanner = newValue }
    }
    public var hasAttemptedSave: Bool {
        get { viewModel.hasAttemptedSave }
        nonmutating set { viewModel.hasAttemptedSave = newValue }
    }
    public var showStepLimitWarning: Bool {
        get { viewModel.showStepLimitWarning }
        nonmutating set { viewModel.showStepLimitWarning = newValue }
    }
    
    // Navigation sheets
    public var showScheduleSheet: Bool {
        get { viewModel.showScheduleSheet }
        nonmutating set { viewModel.showScheduleSheet = newValue }
    }
    public var showNotificationSheet: Bool {
        get { viewModel.showNotificationSheet }
        nonmutating set { viewModel.showNotificationSheet = newValue }
    }
    public var showAddProductSheet: Bool {
        get { viewModel.showAddProductSheet }
        nonmutating set { viewModel.showAddProductSheet = newValue }
    }
    public var showReorderSheet: Bool {
        get { viewModel.showReorderSheet }
        nonmutating set { viewModel.showReorderSheet = newValue }
    }
    public var showCustomStepSheet: Bool {
        get { viewModel.showCustomStepSheet }
        nonmutating set { viewModel.showCustomStepSheet = newValue }
    }
    
    // Custom step inputs
    public var customStepTitle: String {
        get { viewModel.customStepTitle }
        nonmutating set { viewModel.customStepTitle = newValue }
    }
    public var customStepCategory: String {
        get { viewModel.customStepCategory }
        nonmutating set { viewModel.customStepCategory = newValue }
    }
    
    // Quick Add Suggestions
    public struct QuickStepSuggestion: Identifiable, Equatable {
        public let id = UUID()
        public let title: String
        public let category: String
        public let period: RoutinePeriod
    }
    
    private let commonAMSteps: [QuickStepSuggestion] = [
        QuickStepSuggestion(title: "Gentle Cleanser", category: "Purifying", period: .am),
        QuickStepSuggestion(title: "Hydrating Toner", category: "Balancing", period: .am),
        QuickStepSuggestion(title: "Vitamin C Serum", category: "Brightening", period: .am),
        QuickStepSuggestion(title: "Daily Moisturizer", category: "Hydrating", period: .am),
        QuickStepSuggestion(title: "SPF 50 Sunscreen", category: "Protection", period: .am)
    ]
    
    private let commonPMSteps: [QuickStepSuggestion] = [
        QuickStepSuggestion(title: "Cleansing Oil", category: "Pre-cleanse", period: .pm),
        QuickStepSuggestion(title: "Foaming Cleanser", category: "Purifying", period: .pm),
        QuickStepSuggestion(title: "BHA Exfoliant", category: "Pore care", period: .pm),
        QuickStepSuggestion(title: "Retinol Serum", category: "Renewal", period: .pm),
        QuickStepSuggestion(title: "Barrier Night Cream", category: "Moisturizing", period: .pm),
        QuickStepSuggestion(title: "Lip Sleep Mask", category: "Nourishing", period: .pm)
    ]
    
    private var currentSuggestions: [QuickStepSuggestion] {
        selectedPeriod == .pm ? commonPMSteps : commonAMSteps
    }
    
    // Callbacks
    public var onCancel: () -> Void
    /// Persist the new routine. Return `true` when saved; `false` keeps the form open.
    public var onSaveRoutine: (RoutineRecord) -> Bool
    
    public init(
        initialName: String = "",
        initialPeriod: RoutinePeriod = .am,
        initialSteps: [RoutineStepItem] = [],
        onCancel: @escaping () -> Void = {},
        onSaveRoutine: @escaping (RoutineRecord) -> Bool = { _ in true }
    ) {
        let model = CreateRoutineViewModel(
            routineName: initialName,
            selectedPeriod: initialPeriod,
            steps: initialSteps
        )
        self.viewModel = model
        self._observedViewModel = ObservedObject(wrappedValue: model)
        self.onCancel = onCancel
        self.onSaveRoutine = onSaveRoutine
    }
    
    public init(
        viewModel: CreateRoutineViewModel,
        onCancel: @escaping () -> Void = {},
        onSaveRoutine: @escaping (RoutineRecord) -> Bool = { _ in true }
    ) {
        self.viewModel = viewModel
        self._observedViewModel = ObservedObject(wrappedValue: viewModel)
        self.onCancel = onCancel
        self.onSaveRoutine = onSaveRoutine
    }
    
    private var isNameInvalid: Bool {
        hasAttemptedSave && routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Validation Error Banner
                    if showErrorBanner {
                        errorBannerCard
                    }
                    
                    // Routine Name Input Card
                    routineNameSection
                    
                    // Routine Period Selector
                    periodSelectorSection
                    
                    // Steps Section (Empty state, step list, quick suggestions, and add buttons)
                    stepsSection
                    
                    // Settings Navigation Rows (Schedule & Notifications)
                    settingsNavigationSection
                    
                    // Save Button
                    saveButton
                }
                .padding(20)
            }
        }
        .background(Color(hex: "#F7F3ED"))
        .sheet(isPresented: $observedViewModel.showScheduleSheet) {
            RoutineScheduleView(
                frequency: $observedViewModel.frequency,
                reminderTime: $observedViewModel.reminderTime,
                activeDays: $observedViewModel.activeDays,
                onBack: { showScheduleSheet = false },
                onSave: { showScheduleSheet = false }
            )
        }
        .sheet(isPresented: $observedViewModel.showNotificationSheet) {
            RoutineNotificationSettingsView(
                pushRemindersEnabled: $observedViewModel.pushRemindersEnabled,
                leadTime: $observedViewModel.leadTime,
                quietHoursEnabled: $observedViewModel.quietHoursEnabled,
                onBack: { showNotificationSheet = false },
                onPreview: {},
                onSave: { showNotificationSheet = false }
            )
        }
        .sheet(isPresented: $observedViewModel.showAddProductSheet) {
            AddProductToRoutineView(
                currentRoutineName: routineName.isEmpty ? (selectedPeriod == .am ? "Morning Routine" : "Evening Routine") : routineName,
                existingStepTitles: Set(steps.map { $0.title }),
                onProductSelected: { newStep in
                    addStep(newStep)
                    showAddProductSheet = false
                },
                onCancel: { showAddProductSheet = false }
            )
        }
        .sheet(isPresented: $observedViewModel.showReorderSheet) {
            ReorderStepsView(
                routineName: routineName.isEmpty ? "New routine" : routineName,
                steps: steps,
                onBack: { showReorderSheet = false },
                onSaveOrder: { newSteps in
                    steps = newSteps
                    showReorderSheet = false
                }
            )
        }
        .sheet(isPresented: $observedViewModel.showCustomStepSheet) {
            customStepSheet
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Routines")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color(hex: "#6F4E37"))
            }
            
            Spacer()
            
            Text("New routine")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "#1A1628"))
            
            Spacer()
            
            Button("Cancel") {
                onCancel()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color(hex: "#625478"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Error Banner Card
    private var errorBannerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#D9534F"))
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Couldn't save")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#842029"))
                
                Text(
                    routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Add a routine name, then try again."
                        : "Your routine could not be saved. Please try again."
                )
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#842029").opacity(0.9))
            }
            
            Spacer()
            
            Button(action: {
                withAnimation { showErrorBanner = false }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#842029"))
            }
        }
        .padding(14)
        .background(Color(hex: "#F8D7DA"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#F5C6CB"), lineWidth: 1)
        )
    }
    
    // MARK: - Routine Name Section
    private var routineNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTINE NAME")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#625478"))
            
            HStack {
                TextField("e.g. Morning Glow", text: $observedViewModel.routineName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "#1A1628"))
                    .onChange(of: viewModel.routineName) { _, newValue in
                        if !newValue.isEmpty && showErrorBanner {
                            showErrorBanner = false
                        }
                    }
                
                if !routineName.isEmpty {
                    Button(action: { routineName = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "#625478"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isNameInvalid ? Color(hex: "#D9534F") : Color(hex: "#DFD8F5"), lineWidth: isNameInvalid ? 1.5 : 1)
            )
            
            if isNameInvalid {
                Text("Name is required")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#D9534F"))
                    .padding(.leading, 4)
            }
        }
    }
    
    // MARK: - Period Selector Section
    private var periodSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHEN DO YOU USE THIS")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#625478"))
            
            HStack(spacing: 12) {
                periodPill(title: "AM", icon: "sun.max.fill", isSelected: !isCustomPeriod && selectedPeriod == .am) {
                    isCustomPeriod = false
                    selectedPeriod = .am
                }
                
                periodPill(title: "PM", icon: "moon.fill", isSelected: !isCustomPeriod && selectedPeriod == .pm) {
                    isCustomPeriod = false
                    selectedPeriod = .pm
                }
                
                periodPill(title: "Custom", icon: "slider.horizontal.3", isSelected: isCustomPeriod) {
                    isCustomPeriod = true
                }
            }
        }
    }
    
    private func periodPill(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Color(hex: "#1A1628"))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isSelected ? Color(hex: "#7C83BC") : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: "#DFD8F5"), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Step Limit Warning Banner
    private var stepLimitWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#6F4E37"))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Steps · 8 · max")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#6F4E37"))
                
                Text("Step limit reached — routines can have up to 8 steps.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#6F4E37").opacity(0.9))
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(hex: "#FECA9B"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Steps Section
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STEPS · \(steps.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#625478"))
                
                Spacer()
                
                if steps.count >= 2 {
                    Button(action: { showReorderSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Reorder")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "#50578F"))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if showStepLimitWarning || steps.count >= 8 {
                stepLimitWarningBanner
            }
            
            if steps.isEmpty {
                // Empty state card
                VStack(spacing: 16) {
                    RoutineEmptyIllustration(size: 64)
                    
                    VStack(spacing: 4) {
                        Text("No steps yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        Text("Add products or pick suggested steps below to build your ritual")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#625478"))
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            showAddProductSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Add step")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: "#50578F"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#DFD8F5"))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            showCustomStepSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Custom")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: "#625478"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(steps) { step in
                        stepRow(step: step)
                    }
                }
                
                // Add step buttons row
                HStack(spacing: 10) {
                    LabeledButton("Add step", systemImage: "plus", variant: .secondary) {
                        if steps.count >= 8 {
                            withAnimation { showStepLimitWarning = true }
                        } else {
                            showAddProductSheet = true
                        }
                    }
                    
                    Button(action: {
                        if steps.count >= 8 {
                            withAnimation { showStepLimitWarning = true }
                        } else {
                            showCustomStepSheet = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Custom")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "#625478"))
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            
            // Quick-add suggestions banner / row
            quickAddSuggestionsCard
        }
    }
    
    // MARK: - Step Row
    private func stepRow(step: RoutineStepItem) -> some View {
        HStack(spacing: 12) {
            Text("\(step.stepNumber)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#50578F"))
                .frame(width: 28, height: 28)
                .background(Color(hex: "#DFD8F5"))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Text(step.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            
            Spacer()
            
            Button(action: {
                removeStep(step)
            }) {
                Text("Remove")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#D9534F"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#F8D7DA"))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
        )
    }
    
    // MARK: - Quick Add Suggestions Card
    private var quickAddSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#50578F"))
                    Text("QUICK ADD SUGGESTIONS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#625478"))
                }
                
                Spacer()
                
                Text("Tap to add")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "#625478").opacity(0.8))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(currentSuggestions) { suggestion in
                        let isAlreadyAdded = steps.contains { $0.title == suggestion.title }
                        Button(action: {
                            if !isAlreadyAdded {
                                addStep(
                                    RoutineStepItem(
                                        stepNumber: steps.count + 1,
                                        title: suggestion.title,
                                        subtitle: "\(suggestion.category) · Step \(steps.count + 1)",
                                        state: .active
                                    )
                                )
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isAlreadyAdded ? "checkmark" : "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text(suggestion.title)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(isAlreadyAdded ? Color(hex: "#2E5224") : Color(hex: "#50578F"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isAlreadyAdded ? Color(hex: "#D4EDDA") : Color(hex: "#DFD8F5"))
                            .clipShape(Capsule())
                        }
                        .disabled(isAlreadyAdded || steps.count >= 8)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
        )
    }
    
    // MARK: - Custom Step Sheet
    private var customStepSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Add custom step")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Spacer()
                
                Button(action: { showCustomStepSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "#625478"))
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("STEP OR PRODUCT NAME")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#625478"))
                
                TextField("e.g. Rosewater Mist", text: $observedViewModel.customStepTitle)
                    .font(.system(size: 15))
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("CATEGORY OR NOTE (OPTIONAL)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#625478"))
                
                TextField("e.g. Hydrating mist", text: $observedViewModel.customStepCategory)
                    .font(.system(size: 15))
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
                    )
            }
            
            LabeledButton("Add to routine", variant: .primary) {
                let trimmed = customStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let categoryTrimmed = customStepCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                let subtitle = categoryTrimmed.isEmpty ? "Step \(steps.count + 1)" : "\(categoryTrimmed) · Step \(steps.count + 1)"
                addStep(
                    RoutineStepItem(
                        stepNumber: steps.count + 1,
                        title: trimmed,
                        subtitle: subtitle,
                        state: .active
                    )
                )
                customStepTitle = ""
                customStepCategory = ""
                showCustomStepSheet = false
            }
            .disabled(customStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Spacer()
        }
        .padding(24)
        .background(Color(hex: "#F7F3ED"))
    }
    
    // MARK: - Step Management Methods
    public func addStep(_ newStep: RoutineStepItem) {
        withAnimation {
            viewModel.addStep(newStep)
        }
    }
    
    public func removeStep(_ step: RoutineStepItem) {
        withAnimation {
            viewModel.removeStep(step)
        }
    }
    
    // MARK: - Settings Navigation Section
    private var settingsNavigationSection: some View {
        VStack(spacing: 10) {
            // Schedule row
            Button(action: { showScheduleSheet = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#DFD8F5"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "#50578F"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schedule")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        Text(frequency.rawValue + " · " + reminderTime)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#625478"))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#625478"))
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // Notifications row
            Button(action: { showNotificationSheet = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#DFD8F5"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "#50578F"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        Text(pushRemindersEnabled ? "\(leadTime.rawValue) (\(reminderTime))" : "Off")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#625478"))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#625478"))
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        LabeledButton("Save routine", variant: .primary) {
            hasAttemptedSave = true
            if routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                withAnimation { showErrorBanner = true }
            } else {
                let newRecord = RoutineRecord(
                    name: routineName,
                    period: selectedPeriod,
                    status: .active,
                    frequency: frequency,
                    reminderTime: reminderTime,
                    activeDays: activeDays,
                    steps: steps,
                    pushRemindersEnabled: pushRemindersEnabled,
                    leadTime: leadTime,
                    quietHoursEnabled: quietHoursEnabled
                )
                if !onSaveRoutine(newRecord) {
                    withAnimation { showErrorBanner = true }
                }
            }
        }
        .padding(.top, 8)
    }
}
