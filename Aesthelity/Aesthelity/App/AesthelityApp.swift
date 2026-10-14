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
    /// Held for this launch only. Saving it across launches is later persistence work.
    @State private var skinProfile = SkinProfile()
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedStartup {
                ContentView(
                    skinProfile: $skinProfile,
                    onResetStartup: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasCompletedStartup = false
                        }
                    }
                )
            } else {
                StartupFlowView(
                    initialScreen: .welcome,
                    onFinish: { profile in
                        skinProfile = profile
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasCompletedStartup = true
                        }
                    }
                )
            }
        }
    }
}
