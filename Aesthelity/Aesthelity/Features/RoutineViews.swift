//
//  RoutineViews.swift
//  Aesthelity
//
//  Comprehensive Routine screens and states for Aesthelity Skincare Routine Optimizer.
//

import SwiftUI

// MARK: - RoutineStepItem Conformance

extension RoutineStepItem: Equatable {
    public static func == (lhs: RoutineStepItem, rhs: RoutineStepItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.stepNumber == rhs.stepNumber &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.state == rhs.state &&
        lhs.hasClash == rhs.hasClash
    }
}

// MARK: - Routine Enums & Models

public enum RoutineStatus: String, CaseIterable, Identifiable, Codable {
    case active = "Active"
    case paused = "Paused"
    
    public var id: String { rawValue }
}

public enum RoutineFrequency: String, CaseIterable, Identifiable, Codable {
    case everyDay = "Every day"
    case everyOtherDay = "Every other day"
    case twoTimesAWeek = "2 times a week"
    case onceAWeek = "Once a week"
    case onceAMonth = "Once a month"
    
    public var id: String { rawValue }
}

public enum RoutineWeekday: String, CaseIterable, Identifiable, Codable {
    case sun = "Sun"
    case mon = "Mon"
    case tue = "Tue"
    case wed = "Wed"
    case thu = "Thu"
    case fri = "Fri"
    case sat = "Sat"
    
    public var id: String { rawValue }
}

public enum NotificationLeadTime: String, CaseIterable, Identifiable, Codable {
    case atTime = "At time"
    case min15 = "15 min before"
    case hour1 = "1 hour before"
    
    public var id: String { rawValue }
}

public struct RoutineRecord: Identifiable, Equatable, Codable {
    public let id: UUID
    public var name: String
    public var period: RoutinePeriod
    public var status: RoutineStatus
    public var frequency: RoutineFrequency
    public var reminderTime: String
    public var activeDays: Set<RoutineWeekday>
    public var steps: [RoutineStepItem]
    public var pushRemindersEnabled: Bool
    public var leadTime: NotificationLeadTime
    public var quietHoursEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        period: RoutinePeriod = .am,
        status: RoutineStatus = .active,
        frequency: RoutineFrequency = .everyDay,
        reminderTime: String = "7:00 AM",
        activeDays: Set<RoutineWeekday> = [.tue, .fri],
        steps: [RoutineStepItem] = [],
        pushRemindersEnabled: Bool = true,
        leadTime: NotificationLeadTime = .atTime,
        quietHoursEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.period = period
        self.status = status
        self.frequency = frequency
        self.reminderTime = reminderTime
        self.activeDays = activeDays
        self.steps = steps
        self.pushRemindersEnabled = pushRemindersEnabled
        self.leadTime = leadTime
        self.quietHoursEnabled = quietHoursEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, period, status, frequency, reminderTime, activeDays, steps, pushRemindersEnabled, leadTime, quietHoursEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.period = try container.decodeIfPresent(RoutinePeriod.self, forKey: .period) ?? .am
        self.status = try container.decodeIfPresent(RoutineStatus.self, forKey: .status) ?? .active
        self.frequency = try container.decodeIfPresent(RoutineFrequency.self, forKey: .frequency) ?? .everyDay
        self.reminderTime = try container.decodeIfPresent(String.self, forKey: .reminderTime) ?? "7:00 AM"
        self.activeDays = try container.decodeIfPresent(Set<RoutineWeekday>.self, forKey: .activeDays) ?? [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
        self.steps = try container.decodeIfPresent([RoutineStepItem].self, forKey: .steps) ?? []
        self.pushRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .pushRemindersEnabled) ?? true
        self.leadTime = try container.decodeIfPresent(NotificationLeadTime.self, forKey: .leadTime) ?? .atTime
        self.quietHoursEnabled = try container.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(period, forKey: .period)
        try container.encode(status, forKey: .status)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(activeDays, forKey: .activeDays)
        try container.encode(steps, forKey: .steps)
        try container.encode(pushRemindersEnabled, forKey: .pushRemindersEnabled)
        try container.encode(leadTime, forKey: .leadTime)
        try container.encode(quietHoursEnabled, forKey: .quietHoursEnabled)
    }
    
    public var scheduleSummary: String {
        switch frequency {
        case .everyDay:
            return "Every day · \(reminderTime)"
        case .everyOtherDay:
            return "Every other day · \(reminderTime)"
        case .twoTimesAWeek:
            let days = ["Tue", "Fri"].filter { day in
                activeDays.contains { $0.rawValue == day }
            }.joined(separator: " & ")
            let daysText = days.isEmpty ? "Tue & Fri" : days
            return "2× / week · \(daysText)"
        case .onceAWeek:
            return "Once a week · \(reminderTime)"
        case .onceAMonth:
            return "Once a month · \(reminderTime)"
        }
    }
}

// MARK: - Procedural Empty State Illustration

public struct RoutineEmptyIllustration: View {
    public var size: CGFloat = 80
    
    public init(size: CGFloat = 80) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Sunset / Sky gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#7C83BC"),
                            Color(hex: "#EDA5B7"),
                            Color(hex: "#FECA9B")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
            
            // Open shipping / product box symbol
            Image(systemName: "shippingbox")
                .font(.system(size: size * 0.42, weight: .light))
                .foregroundStyle(Color(hex: "#1A1628").opacity(0.85))
        }
    }
}

// MARK: - 1. Routine Schedule Screen

public struct RoutineScheduleView: View {
    @Binding public var frequency: RoutineFrequency
    @Binding public var reminderTime: String
    @Binding public var activeDays: Set<RoutineWeekday>
    public var onBack: () -> Void
    public var onSave: () -> Void
    
    public init(
        frequency: Binding<RoutineFrequency>,
        reminderTime: Binding<String>,
        activeDays: Binding<Set<RoutineWeekday>>,
        onBack: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self._frequency = frequency
        self._reminderTime = reminderTime
        self._activeDays = activeDays
        self.onBack = onBack
        self.onSave = onSave
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Builder")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#6F4E37"))
                }
                
                Spacer()
                
                Text("Routine schedule")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Spacer()
                
                Color.clear
                    .frame(width: 60, height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Frequency Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HOW OFTEN")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#625478"))
                        
                        VStack(spacing: 8) {
                            ForEach(RoutineFrequency.allCases) { freq in
                                Button(action: {
                                    frequency = freq
                                }) {
                                    HStack {
                                        Text(freq.rawValue)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(Color(hex: "#1A1628"))
                                        
                                        Spacer()
                                        
                                        ZStack {
                                            Circle()
                                                .stroke(frequency == freq ? Color(hex: "#7C83BC") : Color(hex: "#DFD8F5"), lineWidth: 2)
                                                .frame(width: 22, height: 22)
                                            
                                            if frequency == freq {
                                                Circle()
                                                    .fill(Color(hex: "#7C83BC"))
                                                    .frame(width: 12, height: 12)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(frequency == freq ? Color(hex: "#7C83BC") : Color(hex: "#DFD8F5").opacity(0.6), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Days Picker (if applicable)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DAYS OF WEEK")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#625478"))
                        
                        HStack(spacing: 8) {
                            ForEach(RoutineWeekday.allCases) { day in
                                let isSelected = activeDays.contains(day)
                                Button(action: {
                                    if isSelected {
                                        activeDays.remove(day)
                                    } else {
                                        activeDays.insert(day)
                                    }
                                }) {
                                    Text(day.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isSelected ? Color.white : Color(hex: "#1A1628"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(isSelected ? Color(hex: "#7C83BC") : Color.white)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: "#DFD8F5"), lineWidth: isSelected ? 0 : 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Time Setting Row
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TIME OF DAY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#625478"))
                        
                        HStack {
                            Text("Scheduled time")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(hex: "#1A1628"))
                            
                            Spacer()
                            
                            Text(reminderTime)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "#50578F"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#DFD8F5"))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    
                    // Save Button
                    LabeledButton("Save schedule", variant: .primary) {
                        onSave()
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .background(Color(hex: "#F7F3ED"))
    }
}

// MARK: - 2. Routine Notification Settings Screen

public struct RoutineNotificationSettingsView: View {
    @Binding public var pushRemindersEnabled: Bool
    @Binding public var leadTime: NotificationLeadTime
    @Binding public var quietHoursEnabled: Bool
    public var onBack: () -> Void
    public var onPreview: () -> Void
    public var onSave: () -> Void
    
    public init(
        pushRemindersEnabled: Binding<Bool>,
        leadTime: Binding<NotificationLeadTime>,
        quietHoursEnabled: Binding<Bool>,
        onBack: @escaping () -> Void,
        onPreview: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self._pushRemindersEnabled = pushRemindersEnabled
        self._leadTime = leadTime
        self._quietHoursEnabled = quietHoursEnabled
        self.onBack = onBack
        self.onPreview = onPreview
        self.onSave = onSave
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Builder")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#6F4E37"))
                }
                
                Spacer()
                
                Text("Routine notifications")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1628"))
                
                Spacer()
                
                Color.clear
                    .frame(width: 60, height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Push Reminders Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push reminders")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#1A1628"))
                            
                            Text("Get notified when it's time to start")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#625478"))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $pushRemindersEnabled)
                            .labelsHidden()
                            .tint(Color(hex: "#7C83BC"))
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Notification Lead Time Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REMINDER TIMING")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#625478"))
                        
                        VStack(spacing: 8) {
                            ForEach(NotificationLeadTime.allCases) { time in
                                Button(action: { leadTime = time }) {
                                    HStack {
                                        Text(time.rawValue)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color(hex: "#1A1628"))
                                        
                                        Spacer()
                                        
                                        if leadTime == time {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color(hex: "#50578F"))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(leadTime == time ? Color(hex: "#7C83BC") : Color(hex: "#DFD8F5").opacity(0.6), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .opacity(pushRemindersEnabled ? 1 : 0.5)
                    
                    // Quiet hours
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiet hours respect")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "#1A1628"))
                            
                            Text("Never alert between 10 PM and 7 AM")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#625478"))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $quietHoursEnabled)
                            .labelsHidden()
                            .tint(Color(hex: "#7C83BC"))
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Preview Notification button
                    LabeledButton("Preview notification", systemImage: "bell.badge", variant: .secondary) {
                        onPreview()
                    }
                    
                    // Save Button
                    LabeledButton("Save settings", variant: .primary) {
                        onSave()
                    }
                }
                .padding(20)
            }
        }
        .background(Color(hex: "#F7F3ED"))
    }
}

// MARK: - 3. Notification Preview Screen (Lock Screen & In-App)

public struct RoutineNotificationPreviewView: View {
    public var routineName: String = "AM Glow"
    public var reminderTime: String = "7:00 AM"
    @State private var previewMode: Int = 0 // 0: Lock Screen, 1: In-App Banner
    public var onDismiss: () -> Void
    
    public init(
        routineName: String = "AM Glow",
        reminderTime: String = "7:00 AM",
        onDismiss: @escaping () -> Void
    ) {
        self.routineName = routineName
        self.reminderTime = reminderTime
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            if previewMode == 0 {
                lockScreenPreview
            } else {
                inAppBannerPreview
            }
            
            // Bottom control overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(previewMode == 0 ? Color.white.opacity(0.8) : Color(hex: "#1A1628"))
                    }
                    .padding(20)
                }
                
                Spacer()
                
                // Mode Switcher Pill
                Picker("Preview Mode", selection: $previewMode) {
                    Text("Lock screen").tag(0)
                    Text("In-app banner").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }
    
    // Lock Screen Mode
    private var lockScreenPreview: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer().frame(height: 40)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.7))
                
                VStack(spacing: 4) {
                    Text("Wednesday, October 11")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                    
                    Text("9:41")
                        .font(.system(size: 78, weight: .thin))
                        .foregroundStyle(Color.white)
                }
                
                Spacer()
                
                // Stacked Notification Banner
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "#7C83BC"))
                                .frame(width: 20, height: 20)
                            Text("A")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        
                        Text("AESTHELITY")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text("now")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    
                    Text("Time for your \(routineName) ritual")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                    
                    Text("4 gentle steps waiting · Start with Gentle Cleanser to prime your barrier.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(16)
                .background(Color.white.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "flashlight.off.fill").foregroundStyle(Color.white))
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "camera.fill").foregroundStyle(Color.white))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
    
    // In-App Mode
    private var inAppBannerPreview: some View {
        ZStack(alignment: .top) {
            Color(hex: "#F7F3ED").ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Top floating app banner
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#7C83BC"))
                            .frame(width: 38, height: 38)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(routineName) reminder")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1628"))
                        
                        Text("Scheduled for \(reminderTime) · Tap to open your routine steps.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#625478"))
                    }
                    
                    Spacer()
                    
                    Text("Now")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#625478"))
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                // Explanatory hint
                Text("Tap notification to open routine · Swipe up to dismiss")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#625478"))
                    .padding(.top, 16)
            }
        }
    }
}
