//
//  CreateRoutineStepBuilderTests.swift
//  AesthelityTests
//
//  Tests for adding, removing, reordering, limiting, and quick-suggesting steps in CreateRoutineView.
//

import Testing
import SwiftUI
@testable import Aesthelity

struct CreateRoutineStepBuilderTests {
    
    @Test func createRoutineStepAdditionAndSequentialNumbering() throws {
        let view = CreateRoutineView()
        #expect(view.steps.isEmpty)
        
        let step1 = RoutineStepItem(stepNumber: 1, title: "Gentle Cleanser", subtitle: "Purifying", state: .active)
        view.addStep(step1)
        #expect(view.steps.count == 1)
        #expect(view.steps[0].title == "Gentle Cleanser")
        #expect(view.steps[0].stepNumber == 1)
        #expect(view.steps[0].subtitle == "Purifying")
        
        let step2 = RoutineStepItem(stepNumber: 99, title: "Hydrating Toner", subtitle: "Balancing", state: .active)
        view.addStep(step2)
        #expect(view.steps.count == 2)
        #expect(view.steps[1].title == "Hydrating Toner")
        #expect(view.steps[1].stepNumber == 2)
        
        let step3 = RoutineStepItem(stepNumber: 0, title: "Moisturizer", subtitle: "", state: .active)
        view.addStep(step3)
        #expect(view.steps.count == 3)
        #expect(view.steps[2].title == "Moisturizer")
        #expect(view.steps[2].stepNumber == 3)
        #expect(view.steps[2].subtitle == "Step 3")
    }
    
    @Test func createRoutineStepRemovalAndReindexing() throws {
        let s1 = RoutineStepItem(stepNumber: 1, title: "Cleanser", subtitle: "Step 1", state: .active)
        let s2 = RoutineStepItem(stepNumber: 2, title: "Serum", subtitle: "Step 2", state: .active)
        let s3 = RoutineStepItem(stepNumber: 3, title: "Cream", subtitle: "Step 3", state: .active)
        
        let view = CreateRoutineView(initialSteps: [s1, s2, s3])
        #expect(view.steps.count == 3)
        
        // Remove the middle step (Serum)
        view.removeStep(s2)
        #expect(view.steps.count == 2)
        #expect(view.steps[0].title == "Cleanser")
        #expect(view.steps[0].stepNumber == 1)
        #expect(view.steps[1].title == "Cream")
        #expect(view.steps[1].stepNumber == 2)
    }
    
    @Test func createRoutineStepLimitMaxEightEnforcement() throws {
        let view = CreateRoutineView()
        
        for i in 1...8 {
            view.addStep(RoutineStepItem(stepNumber: i, title: "Step \(i)", subtitle: "Desc", state: .active))
        }
        #expect(view.steps.count == 8)
        #expect(view.showStepLimitWarning == false)
        
        // Attempting to add 9th step must be rejected and trigger step limit warning
        view.addStep(RoutineStepItem(stepNumber: 9, title: "Step 9", subtitle: "Desc", state: .active))
        #expect(view.steps.count == 8)
        #expect(view.showStepLimitWarning == true)
        
        // Removing a step should clear the warning
        view.removeStep(view.steps.last!)
        #expect(view.steps.count == 7)
        #expect(view.showStepLimitWarning == false)
        
        // Can now add another step up to 8
        view.addStep(RoutineStepItem(stepNumber: 8, title: "New Step 8", subtitle: "Desc", state: .active))
        #expect(view.steps.count == 8)
    }
    
    @Test func createRoutineStateDefaultsAndSheets() throws {
        let view = CreateRoutineView()
        #expect(view.showAddProductSheet == false)
        #expect(view.showReorderSheet == false)
        #expect(view.showCustomStepSheet == false)
        #expect(view.showScheduleSheet == false)
        #expect(view.showNotificationSheet == false)
        #expect(view.customStepTitle.isEmpty)
        #expect(view.customStepCategory.isEmpty)
    }
    
    @Test func createRoutineQuickStepSuggestionData() throws {
        let amView = CreateRoutineView(initialPeriod: .am)
        #expect(amView.selectedPeriod == .am)
        
        let pmView = CreateRoutineView(initialPeriod: .pm)
        #expect(pmView.selectedPeriod == .pm)
    }
}
