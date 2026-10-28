//
//  AesthelityApp.swift
//  Aesthelity
//
//  Main application entry point for Aesthelity Routine Optimizer.
//

import FirebaseCore
import SwiftUI

@main
struct AesthelityApp: App {
    @AppStorage("hasCompletedStartup") private var hasCompletedStartup: Bool = false
    @StateObject private var profileStore: SkinProfileStore
    @StateObject private var authService = FirebaseAuthService.shared
    @StateObject private var syncService = FirestoreSyncService.shared

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--pf01-ui-testing")
        if arguments.contains("-resetStartupForUITests") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedStartup")
        }
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

        if arguments.contains("--seed-routines") {
            try? RoutineStore.shared.seedDefaults()
        }
        if arguments.contains("--reset-routines") {
            try? RoutineStore.shared.resetToEmpty()
        }
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
            .environmentObject(authService)
            .environmentObject(syncService)
            .task {
                guard !isRunningInTestEnvironment else { return }
                await authService.ensureAuthenticated()
                if let userId = authService.userId {
                    syncService.startRoutineListener(for: userId)
                }
            }
        }
    }
    
    private var isRunningInTestEnvironment: Bool {
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--pf01-ui-testing") ||
               args.contains("-resetStartupForUITests") ||
               env["XCTestConfigurationFilePath"] != nil ||
               env["XCInjectBundleInto"] != nil ||
               NSClassFromString("XCTestCase") != nil
    }
}
