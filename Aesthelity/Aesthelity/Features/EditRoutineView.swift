//
//  EditRoutineView.swift
//  Aesthelity
//
//  Edit Routine screen with step management, step limit banner, swipe to remove,
//  and removal confirmation dialog.
//

import SwiftUI

public struct EditRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Core Routine State
    @State public var routine: RoutineRecord
    @State public var routineName: String
    @State public var selectedPeriod: RoutinePeriod
    @State public var steps: [RoutineStepItem]
    
    // States for Banners & Modals
    @State public var showStepLimitWarning: Bool = false
    @State public var showNetworkError: Bool = false
    @State private var hasAttemptedSave = false
    @State public var removedStepBannerText: String? = nil
    @State public var stepPendingRemoval: RoutineStepItem? = nil
    
    // Sub-screens & sheets
    @State public var showReorderSheet: Bool = false
    @State public var showAddProductSheet: Bool = false
    
    // Callbacks
    public var onBack: () -> Void
    /// Persist changes. Return `true` to dismiss; return `false` to keep the editor open and show an error.
    public var onSave: (RoutineRecord) -> Bool
    
    public init(
        routine: RoutineRecord,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (RoutineRecord) -> Bool = { _ in true }
    ) {
        self._routine = State(wrappedValue: routine)
        self._routineName = State(wrappedValue: routine.name)
        self._selectedPeriod = State(wrappedValue: routine.period)
        self._steps = State(wrappedValue: routine.steps)
        self.onBack = onBack
        self.onSave = onSave
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            // Removal toast banner if active
            if let bannerText = removedStepBannerText {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#2E5224"))
                    Text(bannerText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#2E5224"))
                    Spacer()
                    Button(action: { removedStepBannerText = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#2E5224"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "#D4EDDA"))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Network / Save Error Banner
                    if showNetworkError {
                        networkErrorCard
                    }
                    
                    // Routine Name Input
                    nameInputSection
                    
                    // Period Selector
                    periodSelectorSection
                    
                    // Step Limit Banner (when steps >= 8 or triggered)
                    if showStepLimitWarning || steps.count >= 8 {
                        stepLimitWarningBanner
                    }
                    
                    // Steps List Section
                    stepsSection
                    
                    if hasAttemptedSave && !RoutineEditor.validationErrors(name: routineName, steps: steps).isEmpty {
                        Text(RoutineEditor.validationErrors(name: routineName, steps: steps).joined(separator: " "))
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("routine-validation")
                    }
                    // Save Button
                    saveButton
                }
                .padding(20)
            }
        }
        .background(Color(hex: "#F7F3ED"))
        .confirmationDialog(
            "Remove \(stepPendingRemoval?.title ?? "Product")?",
            isPresented: Binding(
                get: { stepPendingRemoval != nil },
                set: { if !$0 { stepPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove product", role: .destructive) {
                if let item = stepPendingRemoval {
                    steps = RoutineEditor.removing(item.id, from: steps)
                }
                stepPendingRemoval = nil
            }
            Button("Keep product", role: .cancel) {
                stepPendingRemoval = nil
            }
        } message: {
            Text("\(stepPendingRemoval?.title ?? "This product") will be removed from \(routineName). You can add it back from the product library anytime.")
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderStepsView(
                routineName: routineName,
                steps: steps,
                onBack: { showReorderSheet = false },
                onSaveOrder: { newSteps in
                    steps = newSteps
                    showReorderSheet = false
                }
            )
        }
        .sheet(isPresented: $showAddProductSheet) {
            RoutineProductPicker(steps: steps) { step in
                steps = RoutineEditor.adding(step, to: steps)
                showAddProductSheet = false
            }
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Routines")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color(hex: "#6F4E37"))
            }
            
            Spacer()
            
            Text("Edit \(routineName)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "#1A1628"))
            
            Spacer()
            
            // Demo button to test error state
            Button(action: {
                withAnimation { showNetworkError.toggle() }
            }) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#625478"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Network Error Card
    private var networkErrorCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "#D9534F"))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't save routine")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#842029"))
                
                Text("Check your connection, then retry.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#842029").opacity(0.85))
            }
            
            Spacer()
            
            Button("Retry") {
                withAnimation { showNetworkError = false }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color(hex: "#842029"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(hex: "#F8D7DA"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Routine Name Input
    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTINE NAME")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#625478"))
            
            HStack {
                TextField("Routine name", text: $routineName, prompt: Text("Routine name").foregroundStyle(Color(hex: "#625478")))
                    .accessibilityIdentifier("routine-name")
                    .submitLabel(.done)
                    .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
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
                    .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Period Selector Section
    private var periodSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERIOD")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#625478"))
            
            HStack(spacing: 12) {
                Button(action: { selectedPeriod = .am }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                        Text("AM")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selectedPeriod == .am ? Color.white : Color(hex: "#1A1628"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(selectedPeriod == .am ? Color(hex: "#7C83BC") : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: { selectedPeriod = .pm }) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                        Text("PM")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selectedPeriod == .pm ? Color.white : Color(hex: "#1A1628"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(selectedPeriod == .pm ? Color(hex: "#7C83BC") : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
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
                
                Text("Step limit reached — \(routineName) can have up to 8 steps.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#6F4E37").opacity(0.9))
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(hex: "#FECA9B"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Steps List Section
    private var stepsSection: some View {
        VStack {
            Button("Reorder steps") { showReorderSheet = true }
            RoutineStepsEditor(steps: $steps, onAdd: { showAddProductSheet = true })
        }
    }

    // MARK: - Save Button
    private var saveButton: some View {
        LabeledButton("Save changes", variant: .primary) {
            hasAttemptedSave = true
            guard RoutineEditor.validationErrors(name: routineName, steps: steps).isEmpty else { return }
            var updated = routine
            updated.name = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.period = selectedPeriod
            updated.steps = RoutineEditor.numbered(steps)
            if onSave(updated) {
                dismiss()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNetworkError = true
                }
            }
        }
        .accessibilityIdentifier("routine-save")
        .padding(.top, 8)
    }
    
}
