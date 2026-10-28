//
//  SettingsView.swift
//  Aesthelity
//
//  Settings screen for Aesthelity Routine Optimizer.
//

import SwiftUI

// MARK: - Custom Pill Toggle Style

/// Custom toggle style matching the Aesthelity design specification:
/// - ON state: Periwinkle background (#7C83BC) with smooth white thumb
/// - OFF state: Soft lavender background (#DFD8F5) with smooth white thumb
public struct AesthelityPillToggleStyle: ToggleStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(
                        configuration.isOn
                            ? Color(red: 0.49, green: 0.51, blue: 0.74)
                            : Color(red: 0.88, green: 0.86, blue: 0.95)
                    )
                    .frame(width: 52, height: 30)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 3)
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isOn)
    }
}

// MARK: - Main SettingsView

/// Dedicated Settings screen for Aesthelity managing skin profile details, notification preferences, and privacy controls.
public struct SettingsView: View {
    // MARK: - Properties & Callbacks
    public var skinType: String
    public var concerns: String
    public var showsTabBar: Bool
    public var selectedTab: Int
    public var onBack: (() -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    public var onDeleteScanHistory: (() -> Void)?
    
    // MARK: - Local State
    @ObservedObject private var authService = FirebaseAuthService.shared
    @ObservedObject private var syncService = FirestoreSyncService.shared
    @State public var amRoutineReminder: Bool
    @State public var pmRoutineReminder: Bool
    @State public var scanAlertsEnabled: Bool
    @State public var weeklySkinReportEnabled: Bool
    @State private var showingDeleteAlert: Bool = false
    @State private var showingDeleteConfirmationToast: Bool = false
    
    // Design constants
    private let cardBorderColor = Color(red: 0.49, green: 0.52, blue: 0.72)
    
    public init(
        skinType: String = "Combination · Sensitive",
        concerns: String = "Acne, Redness, Dullness",
        amRoutineReminder: Bool = true,
        pmRoutineReminder: Bool = true,
        scanAlertsEnabled: Bool = false,
        weeklySkinReportEnabled: Bool = true,
        showsTabBar: Bool = false,
        selectedTab: Int = 4,
        onBack: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil,
        onDeleteScanHistory: (() -> Void)? = nil
    ) {
        self.skinType = skinType
        self.concerns = concerns
        self._amRoutineReminder = State(initialValue: amRoutineReminder)
        self._pmRoutineReminder = State(initialValue: pmRoutineReminder)
        self._scanAlertsEnabled = State(initialValue: scanAlertsEnabled)
        self._weeklySkinReportEnabled = State(initialValue: weeklySkinReportEnabled)
        self.showsTabBar = showsTabBar
        self.selectedTab = selectedTab
        self.onBack = onBack
        self.onSelectTab = onSelectTab
        self.onDeleteScanHistory = onDeleteScanHistory
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Navigation Bar (< Profile)
                    backButtonSection
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    
                    // Screen Title: Settings
                    titleSection
                        .padding(.bottom, 24)
                    
                    // Section 1: Skin Profile
                    skinProfileSection
                        .padding(.bottom, 24)
                    
                    // Section 2: Notifications
                    notificationsSection
                        .padding(.bottom, 24)
                    
                    // Section 3: Privacy & Data
                    privacySection
                        .padding(.bottom, 24)
                    
                    // Section 4: Cloud Sync & Account
                    accountSection
                        .padding(.bottom, showsTabBar ? 24 : 36)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Tab Bar (if displayed standalone)
            if showsTabBar {
                settingsTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.semanticSurfaceBase)
        .alert("Delete scan history?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDeleteScanHistory?()
                showingDeleteConfirmationToast = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove all saved product scans? This action cannot be undone.")
        }
        .overlay(alignment: .bottom) {
            if showingDeleteConfirmationToast {
                Text("Scan history deleted")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Constants.semanticInkPrimary.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, showsTabBar ? 120 : 40)
                    .transition(.opacity.combined(with: .scale))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingDeleteConfirmationToast = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - 1. Back Button
    private var backButtonSection: some View {
        Button(action: {
            onBack?()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                Text("Profile")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(Constants.semanticInkBrand)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Title Section
    private var titleSection: some View {
        Text("Settings")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(Constants.semanticInkBrand)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 3. Skin Profile Section
    private var skinProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skin Profile")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            VStack(alignment: .leading, spacing: 12) {
                // Skin Type Row
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skin Type")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkBrand)
                    
                    Text(skinType)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Constants.semanticInkAccent)
                }
                
                // Thin Divider
                Rectangle()
                    .fill(cardBorderColor.opacity(0.4))
                    .frame(height: 1)
                
                // Concerns Row
                VStack(alignment: .leading, spacing: 4) {
                    Text("Concerns")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkBrand)
                    
                    Text(concerns)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Constants.semanticInkAccent)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(cardBorderColor, lineWidth: 1.2)
            )
        }
    }
    
    // MARK: - 4. Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            VStack(spacing: 10) {
                notificationCardRow(
                    title: "AM Routine Reminder",
                    subtitle: "7:00 AM daily",
                    isOn: $amRoutineReminder
                )
                
                notificationCardRow(
                    title: "PM Routine Reminder",
                    subtitle: "9:00 PM daily",
                    isOn: $pmRoutineReminder
                )
                
                notificationCardRow(
                    title: "Scan Alerts",
                    subtitle: "New ingredient conflicts",
                    isOn: $scanAlertsEnabled
                )
                
                notificationCardRow(
                    title: "Weekly Skin Report",
                    subtitle: "Every Sunday",
                    isOn: $weeklySkinReportEnabled
                )
            }
        }
    }
    
    private func notificationCardRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkBrand)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Constants.semanticInkAccent)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(AesthelityPillToggleStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Constants.semanticSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1.2)
        )
    }
    
    // MARK: - 5. Privacy & Data Section
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy & Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Delete all scan history")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Constants.semanticInkBrand)
                        
                        Text("Remove all saved product scans")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Constants.semanticInkAccent)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Constants.semanticSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1.2)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 5.5. Cloud Sync & Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cloud Sync & Account")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(authService.isAuthenticated && !authService.isAnonymous ? (authService.userEmail ?? "Signed in") : "Using this device")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkBrand)
                    
                    Text(CloudSyncConfiguration.isEnabled
                         ? "Cloud sync is enabled"
                         : "Routines and skin profile stay on this device. Cloud sync is not enabled.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Constants.semanticInkAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 8)
                
                if authService.isAuthenticated && !authService.isAnonymous {
                    Button("Sign Out") {
                        syncService.stopRoutineListener()
                        try? authService.signOut()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#842029"))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(cardBorderColor, lineWidth: 1.2)
            )
        }
    }
    
    // MARK: - 6. Bottom Tab Bar
    private var settingsTabBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                // Tab 0: Home
                tabButton(title: "Home", systemImage: "house", tabIndex: 0)
                
                // Tab 1: Library
                tabButton(title: "Library", systemImage: "books.vertical", tabIndex: 1)
                
                // Tab 2: Scan (Elevated Center Button)
                Button(action: {
                    onSelectTab?(2)
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Constants.semanticSurfaceAccent.opacity(0.3))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "viewfinder")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Constants.semanticInkPrimary)
                        }
                        
                        Text("Scan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Constants.semanticInkBrand)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                // Tab 3: Explore
                tabButton(title: "Explore", systemImage: "magnifyingglass", tabIndex: 3)
                
                // Tab 4: Profile (Active)
                tabButton(title: "Profile", systemImage: "person", tabIndex: 4)
            }
            .frame(height: 72)
            
            // Safe Area bottom spacer
            Color.clear
                .frame(height: 34)
        }
        .frame(height: 106)
        .frame(maxWidth: .infinity)
        .background(Constants.semanticSurfaceBase)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Constants.semanticLineHairline),
            alignment: .top
        )
    }
    
    private func tabButton(title: String, systemImage: String, tabIndex: Int) -> some View {
        Button(action: {
            onSelectTab?(tabIndex)
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(selectedTab == tabIndex ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selectedTab == tabIndex ? Constants.semanticInkAccent : Constants.semanticInkBrand)
                
                if selectedTab == tabIndex {
                    Capsule()
                        .fill(Constants.semanticInkAccent)
                        .frame(width: 16, height: 4)
                } else {
                    Color.clear
                        .frame(width: 16, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Settings - With Tab Bar") {
    SettingsView(showsTabBar: true)
}

#Preview("Settings - Standalone") {
    SettingsView(showsTabBar: false)
}
