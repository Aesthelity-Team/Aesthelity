//
//  MyRoutinesView.swift
//  Aesthelity
//
//  My Routines screen featuring list and empty states.
//

import SwiftUI

public struct MyRoutinesView: View {
    @ObservedObject public var repository: RoutineRepository = .shared
    
    // State
    @State public var showEmptyStateDemo: Bool = false
    @State public var selectedRoutineToEdit: RoutineRecord? = nil
    @State public var showCreateRoutineSheet: Bool = false
    
    public var onBack: () -> Void
    
    public init(
        repository: RoutineRepository = .shared,
        initialEmptyDemo: Bool = false,
        onBack: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self._showEmptyStateDemo = State(wrappedValue: initialEmptyDemo)
        self.onBack = onBack
    }
    
    var displayedRoutines: [RoutineRecord] {
        showEmptyStateDemo ? [] : repository.routines
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            if displayedRoutines.isEmpty {
                // Empty state view
                emptyStateView
            } else {
                // Populated list view
                routineListView
            }
        }
        .background(Color(hex: "#F7F3ED"))
        .sheet(isPresented: $showCreateRoutineSheet) {
            CreateRoutineView(
                onCancel: { showCreateRoutineSheet = false },
                onSaveRoutine: { newRoutine in
                    repository.routines.append(newRoutine)
                    showEmptyStateDemo = false
                    showCreateRoutineSheet = false
                }
            )
        }
        .sheet(item: $selectedRoutineToEdit) { routine in
            EditRoutineView(
                routine: routine,
                onBack: { selectedRoutineToEdit = nil },
                onSave: { updatedRoutine in
                    if let index = repository.routines.firstIndex(where: { $0.id == updatedRoutine.id }) {
                        repository.routines[index] = updatedRoutine
                    }
                    selectedRoutineToEdit = nil
                }
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
                    Text("Home")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color(hex: "#6F4E37"))
            }
            
            Spacer()
            
            Text("My routines")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "#1A1628"))
            
            Spacer()
            
            // Demo toggle for Empty vs Populated
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showEmptyStateDemo.toggle()
                }
            }) {
                Text(showEmptyStateDemo ? "Show list" : "Empty")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#50578F"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#DFD8F5"))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                RoutineEmptyIllustration(size: 96)
                
                VStack(spacing: 8) {
                    Text("No routines yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    
                    Text("Create an AM, PM, or weekly ritual to get started.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#625478"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                BrandPillButton("Create routine") {
                    showCreateRoutineSheet = true
                }
                .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
    }
    
    // MARK: - Routine List View
    private var routineListView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("YOUR ROUTINES")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#625478"))
                        .padding(.horizontal, 4)
                    
                    ForEach(displayedRoutines) { routine in
                        routineCard(routine: routine)
                    }
                }
                .padding(20)
                .padding(.bottom, 80) // bottom padding for sticky button
            }
            
            // Bottom Sticky Create routine button
            VStack(spacing: 0) {
                LabeledButton("Create routine", variant: .primary) {
                    showCreateRoutineSheet = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "#F7F3ED"))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(hex: "#DFD8F5").opacity(0.5)),
                alignment: .top
            )
        }
    }
    
    private func routineCard(routine: RoutineRecord) -> some View {
        Button(action: {
            selectedRoutineToEdit = routine
        }) {
            HStack(spacing: 16) {
                // Period Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#DFD8F5"))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: routine.period == .am ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#50578F"))
                }
                
                // Routine Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(routine.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        // Status pill
                        Text(routine.status.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(routine.status == .active ? Color(hex: "#2E5224") : Color(hex: "#625478"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(routine.status == .active ? Color(hex: "#D4EDDA") : Color(hex: "#EFEBF5"))
                            .clipShape(Capsule())
                    }
                    
                    Text("\(routine.scheduleSummary) · \(routine.steps.count) steps")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#625478"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "#DFD8F5"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
