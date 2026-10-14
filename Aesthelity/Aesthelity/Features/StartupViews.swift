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
    @State public var selectedConcerns: Set<String> = ["Sensitivity & redness", "Barrier repair"]
    public var onFinish: () -> Void
    
    public init(
        initialScreen: StartupScreen = .welcome,
        onFinish: @escaping () -> Void = {}
    ) {
        self._currentScreen = State(initialValue: initialScreen)
        self.onFinish = onFinish
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Background Sky Wallpaper (Shared across all startup screens)
            startupBackground
            
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
                            onSkip: onFinish
                        )
                        
                    case .concerns:
                        OnboardingConcernsView(
                            selectedConcerns: $selectedConcerns,
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .welcome
                                }
                            },
                            onContinue: onFinish,
                            onSkip: onFinish
                        )
                        
                    case .signInNormal:
                        AuthSignInView(
                            initialMode: .normal,
                            onSuccess: onFinish,
                            onSwitchToSetup: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .welcome
                                }
                            }
                        )
                        
                    case .signInInvalid:
                        AuthSignInView(
                            initialMode: .invalid,
                            onSuccess: onFinish,
                            onSwitchToSetup: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentScreen = .welcome
                                }
                            }
                        )
                        
                    case .signInFailed:
                        AuthSignInView(
                            initialMode: .failed,
                            onSuccess: onFinish,
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
        .ignoresSafeArea(.all, edges: .all)
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
                Button(action: onFinish) {
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
            // Sign in successfully
            onSuccess()
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

public struct OnboardingConcernsView: View {
    @Binding public var selectedConcerns: Set<String>
    public var onBack: () -> Void
    public var onContinue: () -> Void
    public var onSkip: () -> Void
    
    public let availableConcerns: [String] = [
        "Acne prone",
        "Sensitivity & redness",
        "Barrier repair",
        "Anti-aging / fine lines",
        "Dryness & hydration",
        "Hyperpigmentation & dark spots",
        "Oil control & pores",
        "Uneven texture"
    ]
    
    public init(
        selectedConcerns: Binding<Set<String>>,
        onBack: @escaping () -> Void = {},
        onContinue: @escaping () -> Void = {},
        onSkip: @escaping () -> Void = {}
    ) {
        self._selectedConcerns = selectedConcerns
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkip = onSkip
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Back Button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "#1A1628"))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: "#625478"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Step Indicator
                    Text("Step 1 of 2 · Skin Profile")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#6F4E37"))
                        .textCase(.uppercase)
                    
                    // Title & Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What are your skin priorities?")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        Text("Select your primary goals. Aesthelity will use these to flag ingredient clashes and suggest safe layering.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "#625478"))
                            .lineSpacing(3)
                    }
                    
                    // Concerns Selection Wrap
                    concernChipsLayout
                        .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            
            // Bottom Action Area
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "#7C83BC"))
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "#7C83BC").opacity(0.35), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                
                Text("\(selectedConcerns.count) priorities selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#625478"))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }
    
    // Concern Chips Grid Layout
    private var concernChipsLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(availableConcerns, id: \.self) { concern in
                let isSelected = selectedConcerns.contains(concern)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isSelected {
                            selectedConcerns.remove(concern)
                        } else {
                            selectedConcerns.insert(concern)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color(hex: "#7C83BC") : Color(hex: "#A096AF"))
                        
                        Text(concern)
                            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(isSelected ? Color.white : Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected ? Color(hex: "#7C83BC") : Color(hex: "#D8CFF0"),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.03), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
