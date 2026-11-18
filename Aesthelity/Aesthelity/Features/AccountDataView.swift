import SwiftUI

/// User-initiated transfers only. Local stores remain authoritative until the
/// user explicitly confirms replacement of a validated download.
struct AccountDataView: View {
    enum Scope { case profile, routines }
    let scope: Scope
    @ObservedObject var routines: RoutineStore = .shared
    @EnvironmentObject private var profile: SkinProfileStore
    @EnvironmentObject private var products: ManualProductStore
    @ObservedObject private var auth = FirebaseAuthService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var task: Task<Void, Never>?
    @State private var operation = UUID()
    @State private var busy = false
    @State private var message: String?
    @State private var needsSignIn = false
    @State private var showSignIn = false
    @State private var pendingProfile: SkinProfile?
    @State private var pendingRoutines: RoutineStorageDocument?
    @State private var pendingAccount: AccountIdentity?
    @State private var baseline: Data?
    @State private var showReplacement = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account storage") {
                    Text("Save a copy to your signed-in account, or load a saved copy onto this device. Transfers happen only when you choose them.")
                    if let email = auth.userEmail, !auth.isAnonymous {
                        Text("Account: \(email)")
                    }
                    if (try? ProtectedAPIConfiguration.baseURL()) == nil {
                        Text("Account storage is awaiting a secure backend connection. Your data remains on this device.")
                            .foregroundStyle(.secondary)
                    }
                    if busy { ProgressView("Contacting your account…") }
                    if let message { Text(message).accessibilityIdentifier("account-transfer-message") }
                    if needsSignIn || auth.userId == nil || auth.isAnonymous {
                        Button("Sign in") { showSignIn = true }
                            .accessibilityIdentifier("account-sign-in")
                    }
                    Button("Save to account") { transfer(load: false) }
                        .disabled(busy || localLoadError != nil)
                        .accessibilityIdentifier("account-save")
                    Button("Load from account") { transfer(load: true) }
                        .disabled(busy || localLoadError != nil)
                        .accessibilityIdentifier("account-load")
                    if let error = localLoadError { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Text(scope == .profile
                         ? "Loading replaces your local skin profile only after confirmation."
                         : "Loading replaces your local routines only after confirmation. Product details already attached to saved steps travel with the routine. Your product library stays on this device.")
                    Text("Automatic cloud synchronization is off. Saving replaces the previous account copy of this data.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(scope == .profile ? "Profile account storage" : "Routine account storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showSignIn) {
                AuthSignInView(onSuccess: { showSignIn = false },
                               onContinueWithoutAccount: { showSignIn = false })
            }
            .confirmationDialog("Replace local data?", isPresented: $showReplacement, titleVisibility: .visible) {
                Button("Replace local \(scope == .profile ? "profile" : "routines")", role: .destructive) { applyDownload() }
                Button("Cancel", role: .cancel) { clearPending() }
            } message: {
                Text(scope == .profile ? "Your downloaded profile will replace the profile on this device."
                     : "The downloaded routines will replace all routines on this device. Your product library will be kept.")
            }
        }
        .onChange(of: auth.apiSessionRevision) { _, _ in invalidate() }
        .onChange(of: auth.userId) { _, _ in invalidate() }
        .onChange(of: auth.isAnonymous) { _, _ in invalidate() }
        .onDisappear { invalidate() }
    }

    private var localLoadError: String? { scope == .profile ? profile.loadError : routines.loadError }

    private func localData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if scope == .profile { return try encoder.encode(profile.profile) }
        return try encoder.encode(RoutineStorageDocument(routines: routines.routines))
    }

    private func transfer(load: Bool) {
        task?.cancel()
        clearPending()
        message = nil
        needsSignIn = false
        busy = true
        let id = UUID()
        operation = id
        task = Task { @MainActor in
            defer { if operation == id { busy = false } }
            do {
                let api = try AccountDataAPI.configured()
                let original = try localData()
                if scope == .profile {
                    if load {
                        let value = try await api.load("profile", id: "skinProfile", as: SkinProfile.self)
                        try AccountDataValidation.profile(value)
                        try api.checkSession()
                        guard operation == id else { return }
                        pendingProfile = value
                    } else {
                        try AccountDataValidation.profile(profile.profile)
                        try await api.save(profile.profile, kind: "profile", id: "skinProfile")
                    }
                } else {
                    if load {
                        let value = try await api.load("routines", id: "savedRoutines", as: RoutineStorageDocument.self)
                        try AccountDataValidation.routines(value)
                        try api.checkSession()
                        guard operation == id else { return }
                        pendingRoutines = value
                    } else {
                        // Legacy manual steps may predate embedded product snapshots.
                        let values = routines.routines.map { routine in
                            var value = routine
                            value.steps = routine.steps.map { step in
                                guard step.product == nil, let productID = step.productId,
                                      let product = products.products.first(where: { $0.id == productID }) else { return step }
                                return RoutineStepItem(id: step.id, stepNumber: step.stepNumber, title: step.title,
                                                       subtitle: step.subtitle, state: step.state, hasClash: step.hasClash,
                                                       productId: productID, product: RoutineProductSnapshot(product))
                            }
                            return value
                        }
                        let value = RoutineStorageDocument(routines: values)
                        try AccountDataValidation.routines(value)
                        try await api.save(value, kind: "routines", id: "savedRoutines")
                    }
                }
                try api.checkSession()
                guard operation == id else { return }
                if load {
                    pendingAccount = api.identity
                    baseline = original
                    showReplacement = true
                } else {
                    message = "Saved to your account. Your local data has been kept."
                }
            } catch is CancellationError {
                // Dismissal or account changes deliberately discard completions.
            } catch {
                guard operation == id else { return }
                clearPending()
                message = error.localizedDescription
                needsSignIn = (error as? APIClientError) == .signInRequired
            }
        }
    }

    private func applyDownload() {
        do {
            guard let pendingAccount, AccountIdentity.current() == pendingAccount else { throw APIClientError.signInRequired }
            guard localLoadError == nil, baseline == (try localData()) else {
                clearPending()
                message = "Local data changed while loading. Load again to review the current account copy."
                return
            }
            if let value = pendingProfile { try profile.save(value) }
            if let value = pendingRoutines { try routines.saveAll(value.routines) }
            message = "Loaded from your account."
        } catch {
            message = error.localizedDescription
            needsSignIn = (error as? APIClientError) == .signInRequired
        }
        clearPending()
    }

    private func clearPending() {
        pendingProfile = nil
        pendingRoutines = nil
        pendingAccount = nil
        baseline = nil
        showReplacement = false
    }

    private func invalidate() {
        operation = UUID()
        task?.cancel()
        busy = false
        message = nil
        needsSignIn = false
        clearPending()
    }
}
