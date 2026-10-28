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
    @StateObject private var manualProductStore: ManualProductStore
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
        let productTesting = arguments.contains("--pd02-ui-testing")
        let defaults = productTesting ? UserDefaults(suiteName: "PD02.UITests")!
            : testing ? UserDefaults(suiteName: "PF01.UITests")! : .standard
        if productTesting { defaults.set(true, forKey: "hasCompletedStartup") }
        let productsURL = productTesting
            ? URL.applicationSupportDirectory.appendingPathComponent("PD02UITests/products.json")
            : ManualProductStore.defaultFileURL
        if productTesting && arguments.contains("--pd02-reset-products") {
            try? FileManager.default.removeItem(at: productsURL.deletingLastPathComponent())
        }
        let storeURL: URL
        if productTesting && arguments.contains("--pd02-save-failure") {
            try? FileManager.default.createDirectory(at: productsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let blocker = productsURL.deletingLastPathComponent().appendingPathComponent("blocked")
            try? Data().write(to: blocker)
            storeURL = blocker.appendingPathComponent("products.json")
        } else {
            storeURL = productsURL
        }
        _manualProductStore = StateObject(wrappedValue: ManualProductStore(fileURL: storeURL))
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
            .environmentObject(manualProductStore)
            .environmentObject(authService)
            .environmentObject(syncService)
            .task {
                // Cloud routine/profile sync stays off until isolation, rules, and DB ID are verified.
                guard CloudSyncConfiguration.isEnabled else {
                    syncService.stopRoutineListener()
                    return
                }
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
               args.contains("--pd02-ui-testing") ||
               args.contains("-resetStartupForUITests") ||
               env["XCTestConfigurationFilePath"] != nil ||
               env["XCInjectBundleInto"] != nil ||
               NSClassFromString("XCTestCase") != nil
    }
}
