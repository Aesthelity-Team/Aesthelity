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
    init() {
        if CommandLine.arguments.contains("-resetStartupForUITests") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedStartup")
        }
    }
    
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
