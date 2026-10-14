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
    @StateObject private var profileStore: SkinProfileStore

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--pf01-ui-testing")
        let defaults = testing ? UserDefaults(suiteName: "PF01.UITests")! : .standard
        let fileURL = testing
            ? URL.applicationSupportDirectory.appendingPathComponent("PF01UITests/profile.json")
            : SkinProfileStore.defaultFileURL
        if testing && ProcessInfo.processInfo.arguments.contains("--pf01-reset-profile") {
            defaults.removeObject(forKey: "hasCompletedStartup")
            try? FileManager.default.removeItem(at: fileURL)
        }
        _hasCompletedStartup = AppStorage(wrappedValue: false, "hasCompletedStartup", store: defaults)
        _profileStore = StateObject(wrappedValue: SkinProfileStore(fileURL: fileURL))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
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
            .environmentObject(profileStore)
        }
    }
}
