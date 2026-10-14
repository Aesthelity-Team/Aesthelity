//
//  ProfileView.swift
//  Aesthelity
//
//  Skincare Profile Screen for Aesthelity Routine Optimizer.
//

import SwiftUI

public struct ProfileView: View {
    @EnvironmentObject private var profileStore: SkinProfileStore
    // MARK: - Properties & Callbacks
    public var productsCount: Int
    public var routinesCount: Int
    public var score: Int
    public var amStepsCount: Int
    public var pmStepsCount: Int
    public var onOpenJournal: (() -> Void)?
    public var onOpenAnalysis: (() -> Void)?
    public var onSelectRoutine: ((RoutinePeriod) -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onOpenStartup: (() -> Void)?
    public var onEditSkinProfile: (() -> Void)?
    public var onSelectTab: ((Int) -> Void)?
    
    // MARK: - Local State
    @State private var clashAlertsEnabled: Bool = true
    @State private var routineRemindersEnabled: Bool = true
    @State public var showSettings: Bool = false
    
    public init(
        productsCount: Int = 24,
        routinesCount: Int = 2,
        score: Int = 82,
        amStepsCount: Int = 4,
        pmStepsCount: Int = 5,
        showSettings: Bool = false,
        onOpenJournal: (() -> Void)? = nil,
        onOpenAnalysis: (() -> Void)? = nil,
        onSelectRoutine: ((RoutinePeriod) -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onOpenStartup: (() -> Void)? = nil,
        onEditSkinProfile: (() -> Void)? = nil,
        onSelectTab: ((Int) -> Void)? = nil
    ) {
        self.productsCount = productsCount
        self.routinesCount = routinesCount
        self.score = score
        self.amStepsCount = amStepsCount
        self.pmStepsCount = pmStepsCount
        self._showSettings = State(initialValue: showSettings)
        self.onOpenJournal = onOpenJournal
        self.onOpenAnalysis = onOpenAnalysis
        self.onSelectRoutine = onSelectRoutine
        self.onOpenSettings = onOpenSettings
        self.onOpenStartup = onOpenStartup
        self.onEditSkinProfile = onEditSkinProfile
        self.onSelectTab = onSelectTab
    }
    
    public var body: some View {
        if showSettings {
            SettingsView(
                skinType: profileStore.profile.skinType?.displayName ?? "Not provided",
                concerns: profileStore.profile.concernSummary,
                showsTabBar: false,
                onBack: {
                    showSettings = false
                },
                onSelectTab: onSelectTab
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. Screen Title
                    titleHeader
                    
                    // 2. Avatar & Skincare Profile Info
                    avatarSection
                    
                    // 3. Stats Gradient Card (24 Products / 2 Routines / 82% Score)
                    statsGradientCard
                    
                    // 4. Skin Type Section
                    skinTypeSection
                    
                    // 5. Skin Journal Section
                    skinJournalSection
                    
                    // 6. My Routines Section
                    myRoutinesSection
                    
                    // 7. Preferences Section
                    preferencesSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Constants.semanticSurfaceBase)
            .accessibilityIdentifier("profile-summary-scroll")
        }
    }
    
    // MARK: - 1. Title Header
    private var titleHeader: some View {
        HStack(alignment: .center) {
            Text("Profile")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            Spacer()
            
            Button(action: {
                showSettings = true
                onOpenSettings?()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Constants.semanticInkBrand)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 2. Avatar & Profile Info
    private var avatarSection: some View {
        VStack(spacing: 14) {
            // Circular Avatar Photo
            Group {
                if let uiImage = UIImage(named: "profile_avatar") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.78, green: 0.87, blue: 0.88),
                                        Color(red: 0.87, green: 0.85, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Constants.semanticInkBrand.opacity(0.8))
                    }
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            
            // Name & Skin Type Subtitle
            VStack(spacing: 5) {
                Text("Your Skincare Profile")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Constants.semanticInkBrand)
                
                Text(profileStore.profile.skinType.map { "\($0.displayName) skin" } ?? "Skin type not provided")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Constants.semanticInkBrand.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
    
    // MARK: - 3. Stats Gradient Card
    private var statsGradientCard: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(productsCount)", title: "Products")
            
            statColumn(value: "\(routinesCount)", title: "Routines")
            
            Button(action: {
                onOpenAnalysis?()
            }) {
                statColumn(value: "\(score)%", title: "Score")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.00, green: 0.77, blue: 0.58), location: 0.0),  // Warm peach / apricot
                    .init(color: Color(red: 0.96, green: 0.65, blue: 0.69), location: 0.52), // Soft rose pink
                    .init(color: Color(red: 0.92, green: 0.60, blue: 0.74), location: 1.0)   // Soft blush / lavender pink
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(red: 0.96, green: 0.65, blue: 0.69).opacity(0.35), radius: 10, x: 0, y: 5)
    }
    
    private func statColumn(value: String, title: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Constants.semanticInkBrand.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 4. Skin Type Section
    private var skinTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skin Profile").font(.headline).foregroundStyle(Constants.semanticInkBrand)
            VStack(alignment: .leading, spacing: 16) {
                if let error = profileStore.loadError {
                    Text(error).font(.subheadline).foregroundStyle(.red)
                }
                SkinProfileSummaryView(profile: profileStore.profile)
                Button("Edit skin profile") { onEditSkinProfile?() }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("edit-skin-profile")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - 5. Skin Journal Section
    private var skinJournalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skin Journal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skin Journal")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Constants.semanticInkPrimary)
                    
                    Text("Sep 16 · Hydration improving · 3 entries this week")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.28, green: 0.36, blue: 0.42))
                }
                
                LabeledButton("View journal", variant: .primary) {
                    onOpenJournal?()
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.74, green: 0.82, blue: 0.67), // Soft matcha / sage green
                        Color(red: 0.83, green: 0.88, blue: 0.77)  // Light warm green
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
    }
    
    // MARK: - 6. My Routines Section
    private var myRoutinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Routines")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Constants.semanticInkBrand)
            
            VStack(spacing: 12) {
                routineCard(
                    period: .am,
                    title: "Morning Glow Routine",
                    stepsCount: amStepsCount,
                    subtitle: "Cleanse · Serum · Moisturize · SPF 46",
                    iconName: "sun.max.fill",
                    accentColor: Constants.semanticInkBrand
                )
                
                routineCard(
                    period: .pm,
                    title: "Night Recovery Routine",
                    stepsCount: pmStepsCount,
                    subtitle: "Double Cleanse · Niacinamide · Recovery Cream · Eye Balm",
                    iconName: "moon.stars.fill",
                    accentColor: Constants.semanticInkAccent
                )
            }
        }
    }
    
    private func routineCard(
        period: RoutinePeriod,
        title: String,
        stepsCount: Int,
        subtitle: String,
        iconName: String,
        accentColor: Color
    ) -> some View {
        Button(action: {
            onSelectRoutine?(period)
        }) {
            HStack(spacing: 14) {
                // Routine Period Badge
                ZStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkInverse)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Constants.semanticInkPrimary)
                        
                        Spacer()
                        
                        Text("\(stepsCount) steps")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Constants.semanticSurfaceSubtle.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Constants.semanticInkSecondary)
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Constants.semanticLineHairline)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Constants.semanticLineHairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 7. Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preferences")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkBrand)
                
                Spacer()
                
                Button(action: {
                    showSettings = true
                    onOpenSettings?()
                }) {
                    Text("All Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Constants.semanticInkAccent)
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 0) {
                preferenceToggleRow(
                    title: "Ingredient Clash Alerts",
                    subtitle: "Instant warnings when combining conflicting actives",
                    icon: "exclamationmark.triangle.fill",
                    isOn: $clashAlertsEnabled
                )
                
                Divider()
                    .padding(.leading, 54)
                    .overlay(Constants.semanticLineHairline)
                
                preferenceToggleRow(
                    title: "Routine Reminders",
                    subtitle: "AM & PM notifications to stay consistent",
                    icon: "bell.badge.fill",
                    isOn: $routineRemindersEnabled
                )
                
                Divider()
                    .padding(.leading, 54)
                    .overlay(Constants.semanticLineHairline)
                
                // Startup & Auth Screens Preview Row
                Button(action: {
                    onOpenStartup?()
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Constants.semanticSurfaceSubtle)
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 15))
                                .foregroundStyle(Constants.semanticInkAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Startup & Auth Screens")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Constants.semanticInkPrimary)
                            
                            Text("Review welcome, concerns, and sign-in states")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Constants.semanticInkSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Constants.semanticLineHairline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .background(Constants.semanticSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Constants.semanticLineHairline, lineWidth: 1)
            )
        }
    }
    
    private func preferenceToggleRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Constants.semanticSurfaceSubtle)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Constants.semanticInkAccent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Constants.semanticInkPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Constants.semanticInkSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Constants.semanticInkAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Previews

#Preview("Profile Screen") {
    ProfileView()
        .environmentObject(SkinProfileStore(fileURL: URL.temporaryDirectory.appendingPathComponent("pf01-preview/profile.json")))
}
