//
//  StartupViews.swift
//  Aesthelity
//
//  Startup, Onboarding, and Authentication screens for Aesthelity.
//  Includes Welcome, Skin Concerns selection, and Sign In flows
//  with support for Normal, Validation Error, and Network Failure states.
//

import SwiftUI

// MARK: - Startup Navigation State

public enum StartupScreen: String, CaseIterable, Identifiable {
    case welcome = "Welcome"
    case concerns = "Concerns"
    case signInNormal = "Sign In"
    case signInInvalid = "Invalid Form"
    case signInFailed = "Network Error"
    
    public var id: String { rawValue }
}

// MARK: - Master Startup Container View

public struct StartupFlowView: View {
    @State public var currentScreen: StartupScreen
    @EnvironmentObject private var profileStore: SkinProfileStore
    @State private var draft = SkinProfileDraft()
    @State private var loadedDraft = false
    @State private var attemptedSubmit = false
    @State private var saveError: String?
    private let normalizer = try? IngredientNormalizer(catalog: .loadBundled())
    public var onFinish: () -> Void
    public var onCancel: (() -> Void)?
    
    public init(
        initialScreen: StartupScreen = .welcome,
        onCancel: (() -> Void)? = nil,
        onFinish: @escaping () -> Void = {}
    ) {
        self._currentScreen = State(initialValue: initialScreen)
        self.onFinish = onFinish
        self.onCancel = onCancel
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Screen Content
            VStack(spacing: 0) {
                // Top Demo Switcher Toolbar for Quick State Inspection
                demoStateSwitcher
                    .padding(.top, 44)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                // Active Screen
                Group {
                    switch currentScreen {
                    case .welcome:
                        OnboardingWelcomeView(
                            onGetStarted: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .concerns
                                }
                            },
                            onSignIn: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .signInNormal
                                }
                            },
                            onSkip: skipProfile
                        )
                        
                    case .concerns:
                        OnboardingConcernsView(
                            draft: $draft,
                            errors: attemptedSubmit ? draft.validationErrors() : [],
                            saveError: saveError ?? profileStore.loadError,
                            normalizer: normalizer,
                            onBack: {
                                if let onCancel {
                                    onCancel()
                                    return
                                }
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .welcome
                                }
                            },
                            onContinue: submitProfile,
                            onSkip: skipProfile
                        )
                        
                    case .signInNormal:
                        AuthSignInView(
                            initialMode: .normal,
                            onSuccess: finishSignIn,
                            onSwitchToSetup: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .welcome
                                }
                            }
                        )
                        
                    case .signInInvalid:
                        AuthSignInView(
                            initialMode: .invalid,
                            onSuccess: finishSignIn,
                            onSwitchToSetup: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .welcome
                                }
                            }
                        )
                        
                    case .signInFailed:
                        AuthSignInView(
                            initialMode: .failed,
                            onSuccess: finishSignIn,
                            onSwitchToSetup: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .welcome
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(startupBackground)
        .ignoresSafeArea(.container, edges: .all)
        .onAppear {
            guard !loadedDraft else { return }
            draft = SkinProfileDraft(skinType: profileStore.profile.skinType,
                                     concerns: profileStore.profile.concerns,
                                     avoidedIngredientInputs: profileStore.profile.avoidedIngredients.map(\.originalText))
            loadedDraft = true
        }
        .alert("Profile could not be saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func submitProfile() {
        attemptedSubmit = true
        guard let normalizer else {
            saveError = "Ingredient lookup is unavailable. Please try again."
            return
        }
        if case .completed(let profile) = draft.submit(using: normalizer) {
            saveAndFinish(profile)
        }
    }

    private func skipProfile() { saveAndFinish(draft.skip()) }

    private func finishSignIn() {
        if profileStore.profile.setupStatus == .notStarted {
            skipProfile()
        } else {
            onFinish()
        }
    }

    private func saveAndFinish(_ profile: SkinProfile) {
        do {
            try profileStore.save(profile)
            onFinish()
        } catch {
            saveError = "Your choices could not be saved. They are still here; please try again."
        }
    }
    
    // Shared Background Wallpaper
    private var startupBackground: some View {
        ZStack {
            // Primary Sky Image Asset
            Image("startup_sky_bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Subtle gradient overlay for readability
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.clear,
                    Color(hex: "#1A1628").opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
    
    // Interactive Demo State Switcher Bar
    private var demoStateSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("DEMO:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#6F4E37"))
                    .padding(.trailing, 2)
                
                ForEach(StartupScreen.allCases) { screen in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentScreen = screen
                        }
                    }) {
                        Text(screen.rawValue)
                            .font(.system(size: 12, weight: currentScreen == screen ? .bold : .medium))
                            .foregroundStyle(currentScreen == screen ? Color.white : Color(hex: "#1A1628"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                currentScreen == screen
                                    ? Color(hex: "#7C83BC")
                                    : Color.white.opacity(0.85)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#D8CFF0"), lineWidth: currentScreen == screen ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Instant bypass button to enter app
                Button(action: finishSignIn) {
                    HStack(spacing: 4) {
                        Text("Enter App")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#6F4E37"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.7).background(.ultraThinMaterial))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - 1. Auth Sign In View (Supports Normal, Invalid Form, & Network Failure)

public enum AuthMode: Equatable {
    case normal
    case invalid
    case failed
}

public struct AuthSignInView: View {
    @State public var mode: AuthMode
    @State public var email: String
    @State public var password: String
    @State public var isRetrying: Bool = false
    @State public var showForgotPasswordAlert: Bool = false
    
    public var onSuccess: () -> Void
    public var onSwitchToSetup: () -> Void
    
    public init(
        initialMode: AuthMode = .normal,
        onSuccess: @escaping () -> Void = {},
        onSwitchToSetup: @escaping () -> Void = {}
    ) {
        self._mode = State(initialValue: initialMode)
        switch initialMode {
        case .invalid:
            self._email = State(initialValue: "maya")
            self._password = State(initialValue: "")
        case .failed:
            self._email = State(initialValue: "maya@aesthelity.app")
            self._password = State(initialValue: "")
        case .normal:
            self._email = State(initialValue: "maya@aesthelity.app")
            self._password = State(initialValue: "")
        }
        self.onSuccess = onSuccess
        self.onSwitchToSetup = onSwitchToSetup
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Top Logo & Dynamic Header
                headerSection
                    .padding(.top, 12)
                
                // Network Error Card (Visible in Failed mode)
                if mode == .failed {
                    networkErrorCard
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }
                
                // Credentials Input Fields
                credentialsSection
                
                // Primary Action Button
                primaryActionButton
                
                // Secondary Button (Back to sign in when failed)
                if mode == .failed {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = .normal
                        }
                    }) {
                        Text("Back to sign in")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#D8CFF0"), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                
                // "or continue with" Divider
                orDivider
                    .padding(.vertical, 4)
                
                // Social Sign In Buttons (Google & Apple)
                socialButtonsSection
                
                // Footer Links
                footerLinksSection
                    .padding(.top, 8)
                    .padding(.bottom, 36)
            }
            .padding(.horizontal, 24)
        }
        .alert("Reset Password", isPresented: $showForgotPasswordAlert) {
            Button("Send Reset Link", role: .none) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We will send a password reset link to \(email.isEmpty ? "your email" : email).")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Floral Logo Mark
            logoMarkView
                .frame(width: 58, height: 58)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            
            // Dynamic Title
            Text(mode == .invalid ? "Check your details" : "Sign in")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "#1A1628"))
                .multilineTextAlignment(.center)
            
            // Dynamic Subtitle
            Group {
                switch mode {
                case .invalid:
                    Text("Fix the highlighted fields, then try signing in again.")
                case .failed:
                    Text("We couldn't reach Aesthelity. Nothing was lost.")
                case .normal:
                    Text("Welcome back. Enter your details to continue.")
                }
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Color(hex: "#625478"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
        }
    }
    
    // Logo Mark Display
    private var logoMarkView: some View {
        Image("logo_mark")
            .resizable()
            .scaledToFit()
    }
    
    // MARK: - Network Error Card
    
    private var networkErrorCard: some View {
        VStack(spacing: 14) {
            // Circular Badge with Wi-Fi Slash Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#FAD2DC"))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: "#6D122B"))
            }
            
            // Error Title
            Text("Couldn't sign in")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#1A1628"))
            
            // Explanation
            Text("Check your connection, then try again. Your email is still here.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "#625478"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            
            // Retry Pill Button
            Button(action: handleRetry) {
                HStack(spacing: 8) {
                    if isRetrying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    Text("Retry")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color(hex: "#7C83BC"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#7C83BC").opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(isRetrying)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "#FAD2DC"), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
    
    private func handleRetry() {
        isRetrying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRetrying = false
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = .normal
            }
        }
    }
    
    // MARK: - Credentials Section
    
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "#625478"))
                    
                    TextField("Enter email", text: $email)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#1A1628"))
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                    
                    if !email.isEmpty {
                        Button(action: { email = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#A096AF"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            mode == .invalid ? Color(hex: "#8A1538") : Color(hex: "#D8CFF0"),
                            lineWidth: mode == .invalid ? 2 : 1
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                
                // Helper / Error Text
                if mode == .invalid {
                    Text("Enter a valid email address.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#8A1538"))
                } else {
                    Text("Use the email on your Aesthelity account.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "#625478"))
                }
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "#625478"))
                    
                    SecureField("Enter password", text: $password)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    
                    if !password.isEmpty {
                        Button(action: { password = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#A096AF"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            mode == .invalid ? Color(hex: "#8A1538") : Color(hex: "#D8CFF0"),
                            lineWidth: mode == .invalid ? 2 : 1
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                
                // Helper / Error Text
                if mode == .invalid {
                    Text("Password is required.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#8A1538"))
                } else {
                    Text("At least 8 characters.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "#625478"))
                }
            }
        }
    }
    
    // MARK: - Primary Action Button
    
    private var primaryActionButton: some View {
        Button(action: handlePrimaryAction) {
            Text(mode == .invalid ? "Try again" : "Sign in")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(mode == .invalid ? Color(hex: "#1A1628") : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "#7C83BC"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#7C83BC").opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
    
    private func handlePrimaryAction() {
        if mode == .invalid {
            // Fix credentials to valid format and switch to normal
            email = "maya@aesthelity.app"
            password = "password123"
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = .normal
            }
        } else {
            if !email.isEmpty && !password.isEmpty && !ProcessInfo.processInfo.arguments.contains("--pf01-ui-testing") {
                Task {
                    do {
                        try await FirebaseAuthService.shared.signIn(email: email, password: password)
                    } catch {
                        // Attempt sign up if account doesn't exist yet
                        try? await FirebaseAuthService.shared.signUp(email: email, password: password)
                    }
                    onSuccess()
                }
            } else {
                onSuccess()
            }
        }
    }
    
    // MARK: - Or Divider
    
    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color(hex: "#D8CFF0"))
                .frame(height: 1)
            
            Text("or continue with")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#625478"))
            
            Rectangle()
                .fill(Color(hex: "#D8CFF0"))
                .frame(height: 1)
        }
    }
    
    // MARK: - Social Sign In
    
    private var socialButtonsSection: some View {
        VStack(spacing: 12) {
            // Google Button
            Button(action: onSuccess) {
                HStack(spacing: 12) {
                    googleLogo
                        .frame(width: 20, height: 20)
                    
                    Text("Continue with Google")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#D8CFF0"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Apple Button
            Button(action: onSuccess) {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    
                    Text("Continue with Apple")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#D8CFF0"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
    // Google Logo Vector Drawing
    private var googleLogo: some View {
        ZStack {
            Text("G")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .yellow, .green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Footer Links
    
    private var footerLinksSection: some View {
        VStack(spacing: 12) {
            Button(action: { showForgotPasswordAlert = true }) {
                Text("Forgot password?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            .buttonStyle(.plain)
            
            Button(action: onSwitchToSetup) {
                HStack(spacing: 4) {
                    Text("New here?")
                        .foregroundStyle(Color(hex: "#625478"))
                    Text("Continue setup")
                        .foregroundStyle(Color(hex: "#1A1628"))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 2. Onboarding Welcome Screen

public struct OnboardingWelcomeView: View {
    public var onGetStarted: () -> Void
    public var onSignIn: () -> Void
    public var onSkip: () -> Void
    
    public init(
        onGetStarted: @escaping () -> Void = {},
        onSignIn: @escaping () -> Void = {},
        onSkip: @escaping () -> Void = {}
    ) {
        self.onGetStarted = onGetStarted
        self.onSignIn = onSignIn
        self.onSkip = onSkip
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Center Brand Hero
            VStack(spacing: 16) {
                Image("logo_mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 6) {
                    Text("Aesthelity")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: "#1A1628"))
                    
                    Text("Your routine, clearly explained")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "#6F4E37"))
                }
                
                Text("Understand ingredient interactions, discover safe layering combinations, and optimize your routine with evidence-based skincare guidance.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "#625478"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            // Bottom Action Area
            VStack(spacing: 12) {
                // Primary: Get Started
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "#7C83BC"))
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#7C83BC").opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
                .accessibilityIdentifier("profile-get-started")

                // Secondary: I already have an account
                Button(action: onSignIn) {
                    Text("I already have an account")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1628"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "#D8CFF0"), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                // Tertiary: Skip to app
                Button(action: onSkip) {
                    Text("Explore without an account")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#625478"))
                        .padding(.top, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - 3. Onboarding Concerns Selection Screen

struct OnboardingConcernsView: View {
    @Binding var draft: SkinProfileDraft
    var errors: [SkinProfileDraft.IngredientInputError]
    var saveError: String?
    var normalizer: IngredientNormalizer?
    var onBack: () -> Void
    var onContinue: () -> Void
    var onSkip: () -> Void
    @FocusState private var focusedEntry: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back", systemImage: "chevron.left", action: onBack)
                Spacer()
                Button("Skip", action: onSkip).accessibilityIdentifier("profile-skip")
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your skin profile").font(.title.bold())
                    Text("Choose what you want to share. You can leave any section empty or skip setup.")
                        .font(.subheadline).foregroundStyle(Color(hex: "#625478"))
                    if let saveError {
                        Text(saveError).font(.subheadline).foregroundStyle(.red)
                    }
                    Text("Skin type").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(SkinProfile.SkinType.allCases, id: \.self) { type in
                            choice(type.displayName, selected: draft.skinType == type, id: "skin-type-\(type.rawValue)") {
                                draft.skinType = draft.skinType == type ? nil : type
                            }
                        }
                    }
                    Text("Concerns").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(SkinProfile.Concern.allCases, id: \.self) { concern in
                            choice(concern.displayName, selected: draft.concerns.contains(concern), id: "concern-\(concern.rawValue)") {
                                if draft.concerns.contains(concern) {
                                    draft.concerns.remove(concern)
                                } else {
                                    draft.concerns.insert(concern)
                                }
                            }
                        }
                    }
                    Text("Ingredients you avoid").font(.headline)
                    Text("These are your preferences, not recorded allergies. Add one ingredient per entry.")
                        .font(.caption).foregroundStyle(Color(hex: "#625478"))
                    ForEach(draft.avoidedIngredientInputs.indices, id: \.self) { index in
                        ingredientEntry(index)
                    }
                    Button("Add ingredient", systemImage: "plus") {
                        draft.avoidedIngredientInputs.append("")
                    }
                    .accessibilityIdentifier("add-ingredient")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("profile-setup-scroll")

            Button(action: { focusedEntry = nil; onContinue() }) {
                Text("Continue").font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color(hex: "#7C83BC")).clipShape(Capsule())
            }
            .accessibilityIdentifier("profile-continue")
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .foregroundStyle(Color(hex: "#1A1628"))
        .buttonStyle(.plain)
    }

    private func choice(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color(hex: "#7C83BC") : Color(hex: "#D8CFF0"), lineWidth: selected ? 2 : 1))
        }
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func ingredientEntry(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Ingredient name", text: Binding(
                    get: { draft.avoidedIngredientInputs.indices.contains(index) ? draft.avoidedIngredientInputs[index] : "" },
                    set: { value in
                        guard draft.avoidedIngredientInputs.indices.contains(index) else { return }
                        draft.avoidedIngredientInputs[index] = value
                    }
                ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focusedEntry, equals: index)
                    .onSubmit { focusedEntry = nil }
                    .accessibilityIdentifier("ingredient-input-\(index)")
                Button {
                    focusedEntry = nil
                    guard draft.avoidedIngredientInputs.indices.contains(index) else { return }
                    draft.avoidedIngredientInputs.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Remove ingredient \(index + 1)")
            }
            .padding(.leading, 12)
            .background(.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if let error = errors.first(where: { $0.entryIndex == index }) {
                Text(error.message).font(.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("ingredient-error-\(index)")
            }
            if let ingredient = previewIngredient(index) {
                if let warning = ingredient.warning {
                    Text(warning.message).font(.caption).foregroundStyle(Color(hex: "#625478"))
                        .accessibilityIdentifier("ingredient-warning-\(index)")
                    ForEach(suggestionIDs(ingredient), id: \.self) { id in
                        if let name = normalizer?.ingredient(withID: id)?.name {
                            Button("Use \(name)") { draft.avoidedIngredientInputs[index] = name }
                                .font(.subheadline.weight(.medium))
                                .accessibilityIdentifier("ingredient-suggestion-\(index)-\(id)")
                        }
                    }
                } else if let id = ingredient.ingredientID, let name = normalizer?.ingredient(withID: id)?.name {
                    Text("Recognized as \(name)").font(.caption).foregroundStyle(Color(hex: "#625478"))
                        .accessibilityIdentifier("ingredient-match-\(index)")
                }
            }
        }
    }

    private func previewIngredient(_ index: Int) -> NormalizedIngredient? {
        guard let normalizer else { return nil }
        let entry = SkinProfileDraft(avoidedIngredientInputs: [draft.avoidedIngredientInputs[index]])
        if case .completed(let profile) = entry.submit(using: normalizer) {
            return profile.avoidedIngredients.first
        }
        return nil
    }

    private func suggestionIDs(_ ingredient: NormalizedIngredient) -> [String] {
        switch ingredient.status {
        case .uncertain(let id): return [id]
        case .ambiguous(let ids): return ids
        default: return []
        }
    }
}
