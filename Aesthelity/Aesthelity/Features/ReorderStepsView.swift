//
//  ReorderStepsView.swift
//  Aesthelity
//
//  Step reordering screen with manual up/down chevrons and order updated confirmation.
//

import SwiftUI

public struct ReorderStepsView: View {
    @Environment(\.dismiss) private var dismiss
    
    public var routineName: String = "AM Glow"
    @State public var steps: [RoutineStepItem]
    @State public var showSuccessView: Bool = false
    
    public var onBack: () -> Void
    public var onSaveOrder: ([RoutineStepItem]) -> Void
    
    public init(
        routineName: String = "AM Glow",
        steps: [RoutineStepItem],
        onBack: @escaping () -> Void = {},
        onSaveOrder: @escaping ([RoutineStepItem]) -> Void = { _ in }
    ) {
        self.routineName = routineName
        self._steps = State(wrappedValue: steps)
        self.onBack = onBack
        self.onSaveOrder = onSaveOrder
    }
    
    public var body: some View {
        ZStack {
            if showSuccessView {
                OrderUpdatedView(
                    routineName: routineName,
                    onBackToEdit: {
                        onSaveOrder(steps)
                        dismiss()
                    },
                    onViewRoutine: {
                        onSaveOrder(steps)
                        dismiss()
                    }
                )
            } else {
                reorderContent
            }
        }
    }
    
    private var reorderContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#6F4E37"))
                }
                
                Spacer()
                
                Text("Reorder steps")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Spacer()
                
                Button("Cancel") {
                    onBack()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "#625478"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("REORDER STEPS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#625478"))
                    
                    VStack(spacing: 12) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            stepReorderRow(step: step, index: index)
                        }
                    }
                    
                    // Buttons
                    VStack(spacing: 10) {
                        LabeledButton("Save new order", variant: .primary) {
                            withAnimation {
                                showSuccessView = true
                            }
                        }
                        
                        LabeledButton("Cancel", variant: .secondary) {
                            onBack()
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(20)
            }
        }
        .background(Color(hex: "#F7F3ED"))
    }
    
    private func stepReorderRow(step: RoutineStepItem, index: Int) -> some View {
        HStack(spacing: 14) {
            // Drag handle icon
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#625478"))
                .frame(width: 24)
            
            // Step title and position
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Text("Position \(index + 1) of \(steps.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            
            Spacer()
            
            // Move Up chevron
            Button(action: {
                moveStep(from: index, to: index - 1)
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(index > 0 ? Color(hex: "#50578F") : Color(hex: "#DFD8F5"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#F7F3ED"))
                    .clipShape(Circle())
            }
            .disabled(index == 0)
            .buttonStyle(.plain)
            
            // Move Down chevron
            Button(action: {
                moveStep(from: index, to: index + 1)
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(index < steps.count - 1 ? Color(hex: "#50578F") : Color(hex: "#DFD8F5"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#F7F3ED"))
                    .clipShape(Circle())
            }
            .disabled(index >= steps.count - 1)
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
    
    private func moveStep(from source: Int, to destination: Int) {
        guard destination >= 0 && destination < steps.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            steps = RoutineEditor.moving(steps, from: source, to: destination)
        }
    }
}

// MARK: - Order Updated Confirmation Screen

public struct OrderUpdatedView: View {
    public var routineName: String = "AM Glow"
    public var onBackToEdit: () -> Void
    public var onViewRoutine: () -> Void
    
    public init(
        routineName: String = "AM Glow",
        onBackToEdit: @escaping () -> Void = {},
        onViewRoutine: @escaping () -> Void = {}
    ) {
        self.routineName = routineName
        self.onBackToEdit = onBackToEdit
        self.onViewRoutine = onViewRoutine
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Success top banner
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#2E5224"))
                Text("Steps reordered")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#2E5224"))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "#D4EDDA"))
            
            Spacer()
            
            VStack(spacing: 24) {
                // Graphic / Checkmark circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#7C83BC"), Color(hex: "#EDA5B7")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                    
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.white)
                }
                
                VStack(spacing: 8) {
                    Text("Order updated")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    
                    Text("\(routineName) steps are in your new order.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#625478"))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    LabeledButton("Back to Edit", variant: .primary) {
                        onBackToEdit()
                    }
                    
                    LabeledButton("View reordered routine", variant: .secondary) {
                        onViewRoutine()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .padding(24)
            
            Spacer()
        }
        .background(Color(hex: "#F7F3ED"))
    }
}
