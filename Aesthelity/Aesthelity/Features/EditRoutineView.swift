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
                    removeStep(item)
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
            AddProductToRoutineView(
                currentRoutineName: routineName,
                existingStepTitles: Set(steps.map { $0.title }),
                onProductSelected: { newStep in
                    addStep(newStep)
                    showAddProductSheet = false
                },
                onCancel: { showAddProductSheet = false }
            )
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
                TextField("Routine name", text: $routineName)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STEPS · \(steps.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#625478"))
                
                Spacer()
                
                Button(action: {
                    showReorderSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Reorder")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#50578F"))
                }
            }
            
            VStack(spacing: 10) {
                ForEach(steps) { step in
                    stepRow(step: step)
                }
            }
            
            // Add Step Button
            LabeledButton("Add step", systemImage: "plus", variant: .secondary) {
                if steps.count >= 8 {
                    withAnimation { showStepLimitWarning = true }
                } else {
                    showAddProductSheet = true
                }
            }
            .padding(.top, 4)
        }
    }
    
    private func stepRow(step: RoutineStepItem) -> some View {
        HStack(spacing: 14) {
            // Radio circle indicator
            ZStack {
                Circle()
                    .stroke(Color(hex: "#DFD8F5"), lineWidth: 2)
                    .frame(width: 22, height: 22)
                
                if step.state == .complete || step.state == .active {
                    Circle()
                        .fill(Color(hex: "#7C83BC"))
                        .frame(width: 12, height: 12)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Text(step.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            
            Spacer()
            
            // Edit / Remove trigger
            Button(action: {
                stepPendingRemoval = step
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
        )
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        LabeledButton("Save changes", variant: .primary) {
            var updated = routine
            updated.name = routineName
            updated.period = selectedPeriod
            updated.steps = steps
            if onSave(updated) {
                dismiss()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNetworkError = true
                }
            }
        }
        .padding(.top, 8)
    }
    
    // Step removal logic
    private func removeStep(_ step: RoutineStepItem) {
        withAnimation {
            var updatedSteps = steps.filter { $0.id != step.id }
            // Recalculate step numbers
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
            removedStepBannerText = "\(step.title) removed · \(steps.count) steps left"
            if steps.count < 8 {
                showStepLimitWarning = false
            }
        }
    }
    
    // Step addition logic
    private func addStep(_ newStep: RoutineStepItem) {
        withAnimation {
            let item = RoutineStepItem(
                stepNumber: steps.count + 1,
                title: newStep.title,
                subtitle: newStep.subtitle,
                state: newStep.state,
                hasClash: newStep.hasClash,
                productId: newStep.productId
            )
            steps.append(item)
        }
    }
}
