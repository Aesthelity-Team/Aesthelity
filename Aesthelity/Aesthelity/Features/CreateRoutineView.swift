//
//  CreateRoutineView.swift
//  Aesthelity
//
//  Create / New Routine screen with validation and empty step states.
//

import SwiftUI

public struct CreateRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    
    // State
    @State public var routineName: String = ""
    @State public var selectedPeriod: RoutinePeriod = .am
    @State public var isCustomPeriod: Bool = false
    @State public var steps: [RoutineStepItem] = []
    
    // Schedule & Notification settings
    @State public var frequency: RoutineFrequency = .everyDay
    @State public var reminderTime: String = "7:00 AM"
    @State public var activeDays: Set<RoutineWeekday> = [.mon, .wed, .fri]
    @State public var pushRemindersEnabled: Bool = false
    @State public var leadTime: NotificationLeadTime = .atTime
    @State public var quietHoursEnabled: Bool = true
    
    // Validation & Error states
    @State public var showErrorBanner: Bool = false
    @State public var hasAttemptedSave: Bool = false
    
    // Navigation sheets
    @State public var showScheduleSheet: Bool = false
    @State public var showNotificationSheet: Bool = false
    @State public var showAddProductSheet: Bool = false
    
    // Callbacks
    public var onCancel: () -> Void
    public var onSaveRoutine: (RoutineRecord) -> Void
    
    public init(
        initialName: String = "",
        initialPeriod: RoutinePeriod = .am,
        onCancel: @escaping () -> Void = {},
        onSaveRoutine: @escaping (RoutineRecord) -> Void = { _ in }
    ) {
        self._routineName = State(wrappedValue: initialName)
        self._selectedPeriod = State(wrappedValue: initialPeriod)
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
                    
                    // Steps Section (Empty state or List)
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
        .sheet(isPresented: $showScheduleSheet) {
            RoutineScheduleView(
                frequency: $frequency,
                reminderTime: $reminderTime,
                activeDays: $activeDays,
                onBack: { showScheduleSheet = false },
                onSave: { showScheduleSheet = false }
            )
        }
        .sheet(isPresented: $showNotificationSheet) {
            RoutineNotificationSettingsView(
                pushRemindersEnabled: $pushRemindersEnabled,
                leadTime: $leadTime,
                quietHoursEnabled: $quietHoursEnabled,
                onBack: { showNotificationSheet = false },
                onPreview: {},
                onSave: { showNotificationSheet = false }
            )
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
                
                Text("Add a routine name, then try again.")
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
                TextField("e.g. Morning Glow", text: $routineName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "#1A1628"))
                    .onChange(of: routineName) { _, newValue in
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
    
    // MARK: - Steps Section
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STEPS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#625478"))
                
                Spacer()
                
                Text("\(steps.count) steps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            
            if steps.isEmpty {
                // Empty state card
                VStack(spacing: 14) {
                    RoutineEmptyIllustration(size: 64)
                    
                    VStack(spacing: 4) {
                        Text("No steps yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        Text("Add your first step to start building this routine")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#625478"))
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        // Demo add step
                        steps.append(
                            RoutineStepItem(
                                stepNumber: 1,
                                title: "Gentle Cleanser",
                                subtitle: "Purifying · Step 1",
                                state: .active
                            )
                        )
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
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
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
                onSaveRoutine(newRecord)
            }
        }
        .padding(.top, 8)
    }
}
