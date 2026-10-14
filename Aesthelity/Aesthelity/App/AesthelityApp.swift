//
//  AesthelityApp.swift
//  Aesthelity
//
//  Main application entry point for Aesthelity Routine Optimizer.
//

import SwiftUI

@main
struct AesthelityApp: App {
    @AppStorage("hasCompletedStartup") private var hasCompletedStartup: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedStartup {
                ContentView(onResetStartup: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasCompletedStartup = false
                    }
                })
            } else {
                StartupFlowView(
                    initialScreen: .welcome,
                    onFinish: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasCompletedStartup = true
                        }
                    }
                )
            }
        }
    }
}
